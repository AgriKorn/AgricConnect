import { AdminService } from './admin.service';
import { IUserRepository } from '../user/user.repository';
import { transactionRepository } from '../transaction/transaction.repository.prisma';
import { BadRequestError, NotFoundError } from '../../utils/errors';

describe('AdminService', () => {
  let adminService: AdminService;
  let mockUsers: jest.Mocked<IUserRepository>;

  beforeEach(() => {
    jest.clearAllMocks();
    mockUsers = {
      create: jest.fn(),
      findByPhone: jest.fn(),
      findById: jest.fn(),
      findManyByStatus: jest.fn(),
      findFarmerIdsByRegion: jest.fn(),
      findAvailableDrivers: jest.fn(),
      update: jest.fn(),
      updateProfile: jest.fn(),
      updateFcmToken: jest.fn(),
      registerDeviceToken: jest.fn(),
      removeDeviceToken: jest.fn(),
      findActiveDeviceTokens: jest.fn(),
      deactivateDeviceToken: jest.fn(),
    } as any;

    adminService = new AdminService(mockUsers);
  });

  describe('listPendingUsers', () => {
    it('returns users with PENDING_APPROVAL status, stripped of sensitive fields', async () => {
      mockUsers.findManyByStatus.mockResolvedValue([
        {
          id: 'user-1',
          name: 'Pending Farmer',
          phone: '+233201230000',
          passwordHash: 'secret-hash',
          role: 'farmer',
          status: 'PENDING_APPROVAL',
          otp: '1234',
          otpExpiry: new Date(),
          refreshToken: 'secret-refresh',
          profile: {},
          createdAt: new Date(),
          updatedAt: new Date(),
        } as any,
      ]);

      const result = await adminService.listPendingUsers();

      expect(mockUsers.findManyByStatus).toHaveBeenCalledWith('PENDING_APPROVAL');
      expect(result).toHaveLength(1);
      expect(result[0]).not.toHaveProperty('passwordHash');
      expect(result[0]).not.toHaveProperty('refreshToken');
      expect(result[0]).not.toHaveProperty('otp');
    });
  });

  describe('approveUser', () => {
    it('sets status to ACTIVE for a pending user', async () => {
      mockUsers.findById.mockResolvedValue({ id: 'user-1', status: 'PENDING_APPROVAL' } as any);
      mockUsers.update.mockResolvedValue({ id: 'user-1', status: 'ACTIVE' } as any);

      const result = await adminService.approveUser('user-1');

      expect(mockUsers.update).toHaveBeenCalledWith('user-1', { status: 'ACTIVE' });
      expect(result.status).toBe('ACTIVE');
    });

    it('throws NotFoundError if the user does not exist', async () => {
      mockUsers.findById.mockResolvedValue(null);
      await expect(adminService.approveUser('missing')).rejects.toThrow(NotFoundError);
    });

    it('throws BadRequestError if the user is not pending approval', async () => {
      mockUsers.findById.mockResolvedValue({ id: 'user-1', status: 'ACTIVE' } as any);
      await expect(adminService.approveUser('user-1')).rejects.toThrow(BadRequestError);
    });
  });

  describe('rejectUser', () => {
    it('sets status to REJECTED for a pending user', async () => {
      mockUsers.findById.mockResolvedValue({ id: 'user-1', status: 'PENDING_APPROVAL' } as any);
      mockUsers.update.mockResolvedValue({ id: 'user-1', status: 'REJECTED' } as any);

      const result = await adminService.rejectUser('user-1');

      expect(mockUsers.update).toHaveBeenCalledWith('user-1', { status: 'REJECTED' });
      expect(result.status).toBe('REJECTED');
    });
  });

  describe('listTransactions', () => {
    it('returns all transactions from the real transaction repository', async () => {
      const mockTransactions = [{ id: 'txn-1', status: 'PAYMENT_HELD' }] as any;
      jest.spyOn(transactionRepository, 'findAll').mockResolvedValue(mockTransactions);

      const result = await adminService.listTransactions();

      expect(result).toEqual(mockTransactions);
    });
  });
});
