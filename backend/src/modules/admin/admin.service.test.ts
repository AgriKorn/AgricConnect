import { AdminService } from './admin.service';
import { IUserRepository } from '../user/user.repository';
import { User } from '../user/user.types';
import { transactionRepository } from '../transaction/transaction.repository.prisma';
import { Transaction } from '../transaction/transaction.types';
import { BadRequestError, ConflictError, NotFoundError } from '../../utils/errors';

describe('AdminService', () => {
  let mockUsers: jest.Mocked<IUserRepository>;
  let adminService: AdminService;

  const createUser = (overrides?: Partial<User>): User => ({
    id: 'user-1',
    name: 'Kwame Mensah',
    phone: '+233541234567',
    email: null,
    passwordHash: 'hashed-secret',
    role: 'farmer',
    status: 'PENDING_APPROVAL',
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

    adminService = new AdminService(mockUsers);
  });

  describe('listTransactions', () => {
    it('should delegate to the transaction repository', async () => {
      const transactions = [{ id: 'tx-1' }] as Transaction[];
      const findAllSpy = jest.spyOn(transactionRepository, 'findAll').mockResolvedValue(transactions);

      const result = await adminService.listTransactions();

      expect(findAllSpy).toHaveBeenCalled();
      expect(result).toBe(transactions);
    });
  });

  describe('listPendingUsers', () => {
    it('should query only users awaiting approval', async () => {
      mockUsers.findManyByStatus.mockResolvedValue([]);

      await adminService.listPendingUsers();

      expect(mockUsers.findManyByStatus).toHaveBeenCalledWith('PENDING_APPROVAL');
    });

    it('should strip credentials and OTP material from every user returned', async () => {
      mockUsers.findManyByStatus.mockResolvedValue([createUser()]);

      const [user] = await adminService.listPendingUsers();

      expect(user).not.toHaveProperty('passwordHash');
      expect(user).not.toHaveProperty('otp');
      expect(user).not.toHaveProperty('otpExpiry');
      expect(user).not.toHaveProperty('refreshToken');
      expect(user).toMatchObject({ id: 'user-1', name: 'Kwame Mensah', status: 'PENDING_APPROVAL' });
    });

    it('should return an empty list when nothing is pending', async () => {
      mockUsers.findManyByStatus.mockResolvedValue([]);

      expect(await adminService.listPendingUsers()).toEqual([]);
    });
  });

  describe('approveUser', () => {
    it('should move a pending user to ACTIVE', async () => {
      mockUsers.findById.mockResolvedValue(createUser());
      mockUsers.update.mockResolvedValue(createUser({ status: 'ACTIVE' }));

      const result = await adminService.approveUser('user-1');

      expect(mockUsers.update).toHaveBeenCalledWith('user-1', { status: 'ACTIVE' });
      expect(result.status).toBe('ACTIVE');
    });

    it('should strip credentials from the approved user', async () => {
      mockUsers.findById.mockResolvedValue(createUser());
      mockUsers.update.mockResolvedValue(createUser({ status: 'ACTIVE' }));

      const result = await adminService.approveUser('user-1');

      expect(result).not.toHaveProperty('passwordHash');
      expect(result).not.toHaveProperty('refreshToken');
    });

    it('should throw NotFoundError for an unknown user', async () => {
      mockUsers.findById.mockResolvedValue(null);

      await expect(adminService.approveUser('missing')).rejects.toThrow(NotFoundError);
      expect(mockUsers.update).not.toHaveBeenCalled();
    });

    it('should refuse to re-approve an already active user', async () => {
      mockUsers.findById.mockResolvedValue(createUser({ status: 'ACTIVE' }));

      await expect(adminService.approveUser('user-1')).rejects.toThrow(BadRequestError);
      expect(mockUsers.update).not.toHaveBeenCalled();
    });

    it('should refuse to approve a user who has not verified their OTP', async () => {
      mockUsers.findById.mockResolvedValue(createUser({ status: 'PENDING_OTP' }));

      await expect(adminService.approveUser('user-1')).rejects.toThrow(BadRequestError);
      expect(mockUsers.update).not.toHaveBeenCalled();
    });

    it('should name the blocking status in the error message', async () => {
      mockUsers.findById.mockResolvedValue(createUser({ status: 'REJECTED' }));

      await expect(adminService.approveUser('user-1')).rejects.toThrow(/REJECTED/);
    });
  });

  describe('listAdmins', () => {
    it('should query users by the admin role and strip credentials', async () => {
      mockUsers.findManyByRole.mockResolvedValue([createUser({ role: 'admin', status: 'ACTIVE' })]);

      const result = await adminService.listAdmins();

      expect(mockUsers.findManyByRole).toHaveBeenCalledWith('admin');
      expect(result).toHaveLength(1);
      expect(result[0]).not.toHaveProperty('passwordHash');
    });
  });

  describe('createAdmin', () => {
    const adminInput = { name: 'New Admin', email: 'admin@agriconnect.com', phone: '+233551234567', password: 'StrongPass123!' };

    it('should create and immediately activate a new admin account', async () => {
      mockUsers.findByEmail.mockResolvedValue(null);
      mockUsers.findByPhone.mockResolvedValue(null);
      mockUsers.create.mockResolvedValue(createUser({ role: 'admin', status: 'PENDING_APPROVAL', email: adminInput.email }));
      mockUsers.update.mockResolvedValue(createUser({ role: 'admin', status: 'ACTIVE', email: adminInput.email }));

      const result = await adminService.createAdmin(adminInput);

      expect(mockUsers.create).toHaveBeenCalledWith(expect.objectContaining({ role: 'admin', email: adminInput.email }));
      expect(mockUsers.update).toHaveBeenCalledWith('user-1', { status: 'ACTIVE' });
      expect(result.status).toBe('ACTIVE');
      expect(result).not.toHaveProperty('passwordHash');
    });

    it('should reject a duplicate email', async () => {
      mockUsers.findByEmail.mockResolvedValue(createUser());

      await expect(adminService.createAdmin(adminInput)).rejects.toThrow(ConflictError);
      expect(mockUsers.create).not.toHaveBeenCalled();
    });

    it('should reject a duplicate phone number', async () => {
      mockUsers.findByEmail.mockResolvedValue(null);
      mockUsers.findByPhone.mockResolvedValue(createUser());

      await expect(adminService.createAdmin(adminInput)).rejects.toThrow(ConflictError);
      expect(mockUsers.create).not.toHaveBeenCalled();
    });
  });

  describe('removeAdmin', () => {
    it('should refuse to let an admin remove themselves', async () => {
      await expect(adminService.removeAdmin('user-1', 'user-1')).rejects.toThrow(BadRequestError);
      expect(mockUsers.findById).not.toHaveBeenCalled();
    });

    it('should throw NotFoundError for an unknown admin', async () => {
      mockUsers.findById.mockResolvedValue(null);

      await expect(adminService.removeAdmin('missing', 'requester-1')).rejects.toThrow(NotFoundError);
    });

    it('should refuse to remove a non-admin account through this path', async () => {
      mockUsers.findById.mockResolvedValue(createUser({ role: 'farmer' }));

      await expect(adminService.removeAdmin('user-1', 'requester-1')).rejects.toThrow(BadRequestError);
      expect(mockUsers.update).not.toHaveBeenCalled();
    });

    it('should refuse to remove the last remaining active admin', async () => {
      mockUsers.findById.mockResolvedValue(createUser({ role: 'admin', status: 'ACTIVE' }));
      mockUsers.findManyByRole.mockResolvedValue([createUser({ role: 'admin', status: 'ACTIVE' })]);

      await expect(adminService.removeAdmin('user-1', 'requester-1')).rejects.toThrow(BadRequestError);
      expect(mockUsers.update).not.toHaveBeenCalled();
    });

    it('should reject the admin (not hard-delete) when another active admin remains', async () => {
      mockUsers.findById.mockResolvedValue(createUser({ id: 'user-1', role: 'admin', status: 'ACTIVE' }));
      mockUsers.findManyByRole.mockResolvedValue([
        createUser({ id: 'user-1', role: 'admin', status: 'ACTIVE' }),
        createUser({ id: 'requester-1', role: 'admin', status: 'ACTIVE' }),
      ]);
      mockUsers.update.mockResolvedValue(createUser({ id: 'user-1', role: 'admin', status: 'REJECTED' }));

      const result = await adminService.removeAdmin('user-1', 'requester-1');

      expect(mockUsers.update).toHaveBeenCalledWith('user-1', { status: 'REJECTED', refreshToken: null });
      expect(result.status).toBe('REJECTED');
    });
  });

  describe('rejectUser', () => {
    it('should move a pending user to REJECTED', async () => {
      mockUsers.findById.mockResolvedValue(createUser());
      mockUsers.update.mockResolvedValue(createUser({ status: 'REJECTED' }));

      const result = await adminService.rejectUser('user-1');

      expect(mockUsers.update).toHaveBeenCalledWith('user-1', { status: 'REJECTED' });
      expect(result.status).toBe('REJECTED');
    });

    it('should throw NotFoundError for an unknown user', async () => {
      mockUsers.findById.mockResolvedValue(null);

      await expect(adminService.rejectUser('missing')).rejects.toThrow(NotFoundError);
      expect(mockUsers.update).not.toHaveBeenCalled();
    });

    it('should refuse to reject a user who is already active', async () => {
      mockUsers.findById.mockResolvedValue(createUser({ status: 'ACTIVE' }));

      await expect(adminService.rejectUser('user-1')).rejects.toThrow(BadRequestError);
      expect(mockUsers.update).not.toHaveBeenCalled();
    });

    it('should refuse to reject a user twice', async () => {
      mockUsers.findById.mockResolvedValue(createUser({ status: 'REJECTED' }));

      await expect(adminService.rejectUser('user-1')).rejects.toThrow(BadRequestError);
      expect(mockUsers.update).not.toHaveBeenCalled();
    });
  });
});
