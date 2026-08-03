import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { AuthService } from './auth.service';
import { PrismaUserRepository } from '../user/user.repository.prisma';
import { ConflictError, InvalidTokenError, UnauthorizedError } from '../../utils/errors';
import { supabase } from '../../config/supabase';
import { User } from '../user/user.types';
import { env } from '../../config/env';

describe('AuthService', () => {
  let authService: AuthService;
  let mockUserRepo: jest.Mocked<PrismaUserRepository>;

  const createMockUser = (overrides?: Partial<User>): User => ({
    id: 'user-uuid-1',
    name: 'Kofi Mensah',
    phone: '+233541234567',
    passwordHash: '$2a$10$hashedpasswordstring',
    role: 'farmer',
    status: 'ACTIVE',
    otp: '1234',
    otpExpiry: new Date(),
    refreshToken: 'valid-refresh-token',
    profile: {} as any,
    createdAt: new Date(),
    updatedAt: new Date(),
    ...overrides,
  });

  beforeEach(() => {
    jest.clearAllMocks();
    mockUserRepo = {
      findByPhone: jest.fn(),
      create: jest.fn(),
      findById: jest.fn(),
      update: jest.fn(),
      updateStatus: jest.fn(),
      updatePassword: jest.fn(),
      findAvailableDrivers: jest.fn(),
      findAdmins: jest.fn(),
    } as any;

    authService = new AuthService(mockUserRepo);
  });

  describe('register', () => {
    it('should throw ConflictError if phone number is already registered', async () => {
      mockUserRepo.findByPhone.mockResolvedValue(createMockUser());

      await expect(
        authService.register({
          name: 'Kofi Mensah',
          phone: '+233541234567',
          password: 'Password123',
          role: 'farmer',
        }),
      ).rejects.toThrow(ConflictError);
    });

    it('should hash password and create user with status PENDING_APPROVAL', async () => {
      mockUserRepo.findByPhone.mockResolvedValue(null);

      const mockCreated = createMockUser({ id: 'new-user-uuid', status: 'PENDING_APPROVAL' });
      mockUserRepo.create.mockResolvedValue(mockCreated);

      const result = await authService.register({
        name: 'Kofi Mensah',
        phone: '+233541234567',
        password: 'Password123',
        role: 'farmer',
      });

      expect(mockUserRepo.create).toHaveBeenCalledWith(
        expect.objectContaining({
          name: 'Kofi Mensah',
          phone: '+233541234567',
          role: 'farmer',
        }),
      );
      expect(result.userId).toBe('new-user-uuid');
      expect(result.message).toContain('Registration successful');
    });
  });

  describe('login', () => {
    it('should throw UnauthorizedError if user does not exist or password invalid', async () => {
      mockUserRepo.findByPhone.mockResolvedValue(null);

      await expect(authService.login({ phone: '+233541234567', password: 'WrongPassword' })).rejects.toThrow(UnauthorizedError);
    });

    it('should return auth payload when credentials are correct and account is ACTIVE', async () => {
      const hashedPassword = await bcrypt.hash('Password123', 10);
      const mockUser = createMockUser({ passwordHash: hashedPassword, status: 'ACTIVE' });
      mockUserRepo.findByPhone.mockResolvedValue(mockUser);
      mockUserRepo.update.mockResolvedValue(mockUser);

      const result = await authService.login({ phone: '+233541234567', password: 'Password123' });

      expect(result.accessToken).toBeDefined();
      expect(result.refreshToken).toBeDefined();
      expect(result.user.id).toBe('user-uuid-1');
    });
  });

  describe('forgotPassword & resetPassword', () => {
    it('should return generic message for non-existent user on forgotPassword', async () => {
      mockUserRepo.findByPhone.mockResolvedValue(null);
      const result = await authService.forgotPassword({ phone: '+233999999999' });
      expect(result.message).toContain('If an account with that phone number exists');
    });

    it('should generate resetToken for existing user on forgotPassword', async () => {
      mockUserRepo.findByPhone.mockResolvedValue(createMockUser());
      const result = await authService.forgotPassword({ phone: '+233541234567' });
      expect(result.message).toBeDefined();
      expect(result.resetToken).toBeDefined();
    });

    it('should throw InvalidTokenError if resetPassword token is invalid', async () => {
      await expect(authService.resetPassword({ token: 'invalid-token', newPassword: 'NewPassword123' })).rejects.toThrow(InvalidTokenError);
    });

    it('should reset password cleanly when valid token is provided', async () => {
      const resetToken = jwt.sign({ userId: 'user-uuid-1', purpose: 'password_reset' }, env.JWT_SECRET, { expiresIn: '15m' });
      const user = createMockUser({ id: 'user-uuid-1' });
      mockUserRepo.findById.mockResolvedValue(user);
      mockUserRepo.update.mockResolvedValue({ ...user, passwordHash: 'newhash' });

      const result = await authService.resetPassword({ token: resetToken, newPassword: 'NewPassword123' });
      expect(result.message).toContain('Password has been reset successfully');
      expect(mockUserRepo.update).toHaveBeenCalledWith('user-uuid-1', expect.objectContaining({ refreshToken: null }));
    });
  });

  describe('refresh & logout', () => {
    it('should throw InvalidTokenError if refresh token is invalid or user mismatch', async () => {
      await expect(authService.refresh('invalid-refresh-token')).rejects.toThrow(InvalidTokenError);
    });

    it('should issue new access token when valid refresh token is supplied', async () => {
      const refreshToken = jwt.sign({ userId: 'user-uuid-1' }, env.JWT_REFRESH_SECRET, { expiresIn: '7d' });
      const user = createMockUser({ id: 'user-uuid-1', refreshToken });
      mockUserRepo.findById.mockResolvedValue(user);

      const result = await authService.refresh(refreshToken);
      expect(result.accessToken).toBeDefined();
    });

    it('should clear refresh token on logout', async () => {
      const refreshToken = jwt.sign({ userId: 'user-uuid-1' }, env.JWT_REFRESH_SECRET, { expiresIn: '7d' });
      const user = createMockUser({ id: 'user-uuid-1', refreshToken });
      mockUserRepo.findById.mockResolvedValue(user);

      const result = await authService.logout(refreshToken);
      expect(result.message).toContain('Logged out successfully');
      expect(mockUserRepo.update).toHaveBeenCalledWith('user-uuid-1', { refreshToken: null });
    });
  });

  describe('googleAuth & getGoogleAuthUrl', () => {
    it('should return OAuth redirect URL', async () => {
      jest.spyOn(supabase.auth, 'signInWithOAuth').mockResolvedValue({
        data: { provider: 'google', url: 'https://accounts.google.com/o/oauth2/auth' },
        error: null,
      });

      const result = await authService.getGoogleAuthUrl();
      expect(result.url).toContain('google.com');
    });

    it('should authenticate existing user via Supabase Google OAuth and return token pair', async () => {
      jest.spyOn(supabase.auth, 'getUser').mockResolvedValue({
        data: {
          user: {
            id: 'supabase-user-id',
            email: 'kofi@gmail.com',
            user_metadata: { full_name: 'Kofi OAuth', phone: '+233550000000' },
          } as any,
        },
        error: null,
      });

      const mockUser = createMockUser({ id: 'user-uuid-oauth', name: 'Kofi OAuth', phone: '+233550000000' });
      mockUserRepo.findByPhone.mockResolvedValue(mockUser);
      mockUserRepo.update.mockResolvedValue(mockUser);

      const result = await authService.googleAuth({ token: 'mock-id-token', role: 'buyer' });

      expect(result.accessToken).toBeDefined();
      expect(result.user.id).toBe('user-uuid-oauth');
    });
  });
});
