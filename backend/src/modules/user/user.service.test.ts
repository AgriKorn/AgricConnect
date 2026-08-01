import { UserService } from './user.service';
import { IUserRepository } from './user.repository';
import { User } from './user.types';
import { NotFoundError } from '../../utils/errors';

describe('UserService', () => {
  let mockUsers: jest.Mocked<IUserRepository>;
  let userService: UserService;

  const createUser = (overrides?: Partial<User>): User => ({
    id: 'user-1',
    name: 'Kwame Mensah',
    phone: '+233541234567',
    email: null,
    passwordHash: 'hashed-secret',
    role: 'farmer',
    status: 'ACTIVE',
    otp: '123456',
    otpExpiry: new Date('2026-07-28'),
    refreshToken: 'refresh-token',
    profile: { farmRegion: 'Greater Accra' },
    createdAt: new Date('2026-07-01'),
    updatedAt: new Date('2026-07-01'),
    ...overrides,
  });

  beforeEach(() => {
    jest.clearAllMocks();

    mockUsers = {
      create: jest.fn(),
      findByPhone: jest.fn(),
      findByEmail: jest.fn(),
      findById: jest.fn(),
      findManyByStatus: jest.fn(),
      findManyByRole: jest.fn(),
      findFarmerIdsByRegion: jest.fn(),
      findAvailableDrivers: jest.fn(),
      update: jest.fn(),
      updateProfile: jest.fn(),
      updateFcmToken: jest.fn(),
      registerDeviceToken: jest.fn(),
      removeDeviceToken: jest.fn(),
      findActiveDeviceTokens: jest.fn(),
      deactivateDeviceToken: jest.fn(),
    };

    userService = new UserService(mockUsers);
  });

  describe('getProfile', () => {
    it('should return the user without credentials or OTP material', async () => {
      mockUsers.findById.mockResolvedValue(createUser());

      const result = await userService.getProfile('user-1');

      expect(mockUsers.findById).toHaveBeenCalledWith('user-1');
      expect(result).toMatchObject({ id: 'user-1', name: 'Kwame Mensah', role: 'farmer' });
      expect(result).not.toHaveProperty('passwordHash');
      expect(result).not.toHaveProperty('otp');
      expect(result).not.toHaveProperty('otpExpiry');
      expect(result).not.toHaveProperty('refreshToken');
    });

    it('should throw NotFoundError for an unknown user', async () => {
      mockUsers.findById.mockResolvedValue(null);

      await expect(userService.getProfile('missing')).rejects.toThrow(NotFoundError);
    });
  });

  describe('updateProfile', () => {
    it('should split the name onto the user record and the rest onto the profile', async () => {
      mockUsers.update.mockResolvedValue(createUser({ name: 'Ama Serwaa' }));
      mockUsers.updateProfile.mockResolvedValue(createUser({ name: 'Ama Serwaa', profile: { farmRegion: 'Ashanti' } }));

      const result = await userService.updateProfile('user-1', { name: 'Ama Serwaa', farmRegion: 'Ashanti' });

      expect(mockUsers.update).toHaveBeenCalledWith('user-1', { name: 'Ama Serwaa' });
      expect(mockUsers.updateProfile).toHaveBeenCalledWith('user-1', { farmRegion: 'Ashanti' });
      expect(result.name).toBe('Ama Serwaa');
    });

    it('should skip the user-record write when no name is supplied', async () => {
      mockUsers.updateProfile.mockResolvedValue(createUser({ profile: { farmRegion: 'Volta' } }));

      await userService.updateProfile('user-1', { farmRegion: 'Volta' });

      expect(mockUsers.update).not.toHaveBeenCalled();
      expect(mockUsers.updateProfile).toHaveBeenCalledWith('user-1', { farmRegion: 'Volta' });
    });

    it('should still call updateProfile with an empty patch when only the name changes', async () => {
      mockUsers.update.mockResolvedValue(createUser({ name: 'Ama Serwaa' }));
      mockUsers.updateProfile.mockResolvedValue(createUser({ name: 'Ama Serwaa' }));

      await userService.updateProfile('user-1', { name: 'Ama Serwaa' });

      expect(mockUsers.update).toHaveBeenCalledWith('user-1', { name: 'Ama Serwaa' });
      expect(mockUsers.updateProfile).toHaveBeenCalledWith('user-1', {});
    });

    it('should pass driver profile fields through untouched', async () => {
      mockUsers.updateProfile.mockResolvedValue(
        createUser({ role: 'driver', profile: { truckCapacity: 2000, operatingRegion: 'Ashanti', isAvailable: true } }),
      );

      await userService.updateProfile('user-1', { truckCapacity: 2000, operatingRegion: 'Ashanti', isAvailable: true });

      expect(mockUsers.updateProfile).toHaveBeenCalledWith('user-1', {
        truckCapacity: 2000,
        operatingRegion: 'Ashanti',
        isAvailable: true,
      });
    });

    it('should pass buyer profile fields through untouched', async () => {
      mockUsers.updateProfile.mockResolvedValue(
        createUser({ role: 'buyer', profile: { businessName: 'Accra Fresh Ltd', deliveryAddress: 'Osu, Accra' } }),
      );

      await userService.updateProfile('user-1', { businessName: 'Accra Fresh Ltd', deliveryAddress: 'Osu, Accra' });

      expect(mockUsers.updateProfile).toHaveBeenCalledWith('user-1', {
        businessName: 'Accra Fresh Ltd',
        deliveryAddress: 'Osu, Accra',
      });
    });

    it('should strip credentials from the updated user', async () => {
      mockUsers.updateProfile.mockResolvedValue(createUser());

      const result = await userService.updateProfile('user-1', { farmRegion: 'Volta' });

      expect(result).not.toHaveProperty('passwordHash');
      expect(result).not.toHaveProperty('refreshToken');
    });
  });

  describe('registerDeviceToken', () => {
    it('should persist the token and return the refreshed user', async () => {
      mockUsers.registerDeviceToken.mockResolvedValue(undefined);
      mockUsers.findById.mockResolvedValue(createUser());

      const result = await userService.registerDeviceToken('user-1', 'fcm-token-abc', 'android', 'device-9');

      expect(mockUsers.registerDeviceToken).toHaveBeenCalledWith('user-1', 'fcm-token-abc', 'android', 'device-9');
      expect(result.id).toBe('user-1');
      expect(result).not.toHaveProperty('passwordHash');
    });

    it('should accept a token without platform or device metadata', async () => {
      mockUsers.registerDeviceToken.mockResolvedValue(undefined);
      mockUsers.findById.mockResolvedValue(createUser());

      await userService.registerDeviceToken('user-1', 'fcm-token-abc');

      expect(mockUsers.registerDeviceToken).toHaveBeenCalledWith('user-1', 'fcm-token-abc', undefined, undefined);
    });

    it('should throw NotFoundError if the user disappears between write and read-back', async () => {
      mockUsers.registerDeviceToken.mockResolvedValue(undefined);
      mockUsers.findById.mockResolvedValue(null);

      await expect(userService.registerDeviceToken('user-1', 'fcm-token-abc')).rejects.toThrow(NotFoundError);
    });
  });

  describe('removeDeviceToken', () => {
    it('should delegate removal to the repository', async () => {
      mockUsers.removeDeviceToken.mockResolvedValue(undefined);

      await userService.removeDeviceToken('user-1', 'fcm-token-abc');

      expect(mockUsers.removeDeviceToken).toHaveBeenCalledWith('user-1', 'fcm-token-abc');
    });

    it('should resolve quietly when the token was already gone', async () => {
      mockUsers.removeDeviceToken.mockResolvedValue(undefined);

      await expect(userService.removeDeviceToken('user-1', 'unknown-token')).resolves.toBeUndefined();
    });
  });
});
