import { mockDeep, DeepMockProxy } from 'jest-mock-extended';
import { PrismaClient } from '../../generated/prisma/client';

jest.mock('../../config/db', () => ({
  prisma: mockDeep<PrismaClient>(),
}));

import { prisma } from '../../config/db';
import { DispatchService } from './dispatch.service';
import { PrismaDispatchRepository } from './dispatch.repository.prisma';
import { userRepository } from '../user/user.repository.prisma';
import { auditService } from '../audit/audit.service';
import { notificationService } from '../notification/notification.service';
import { ForbiddenError } from '../../utils/errors';
import { DriverJob } from './dispatch.types';

describe('DispatchService', () => {
  let dispatchService: DispatchService;
  let mockRepo: jest.Mocked<PrismaDispatchRepository>;
  let mockUsers: jest.Mocked<typeof userRepository>;
  let mockPrisma: DeepMockProxy<PrismaClient>;

  const createMockJob = (overrides?: Partial<DriverJob>): DriverJob => ({
    id: 'job-1',
    transactionId: 'tx-1',
    listingId: 'listing-1',
    driverId: 'driver-100',
    cropType: 'tomato',
    quantityKg: 200,
    amountGhs: 500,
    status: 'PENDING',
    createdAt: new Date(),
    updatedAt: new Date(),
    ...overrides,
  });

  beforeEach(() => {
    jest.clearAllMocks();
    mockPrisma = prisma as unknown as DeepMockProxy<PrismaClient>;
    mockPrisma.$transaction.mockImplementation(async (cb: any) => cb(mockPrisma));

    mockPrisma.notifications.create.mockResolvedValue({
      id: 'notif-1',
      user_id: 'driver-100',
      type: 'DRIVER_JOB_OFFERED',
      message: 'Job offered',
      order_id: null,
      listing_id: null,
      is_read: false,
      created_at: new Date(),
    } as any);

    mockRepo = {
      create: jest.fn(),
      findById: jest.fn(),
      update: jest.fn(),
      findByDriverAndStatus: jest.fn(),
      findAllForTransaction: jest.fn(),
    } as any;

    mockUsers = {
      findAvailableDrivers: jest.fn(),
      create: jest.fn(),
      findById: jest.fn(),
      findByEmail: jest.fn(),
      findByPhone: jest.fn(),
      updateStatus: jest.fn(),
      updatePassword: jest.fn(),
      updateProfile: jest.fn(),
      findAdmins: jest.fn(),
    } as any;

    dispatchService = new DispatchService(mockRepo, mockUsers);
  });

  describe('assignDriver', () => {
    it('should create driver job assignment when candidate driver is available', async () => {
      const candidateDriver = { id: 'driver-100', name: 'Kwame Transport' };
      mockUsers.findAvailableDrivers.mockResolvedValue([candidateDriver as any]);

      const mockJob = createMockJob();
      mockRepo.create.mockResolvedValue(mockJob);
      jest.spyOn(auditService, 'log').mockResolvedValue({} as any);

      const result = await dispatchService.assignDriver({
        transactionId: 'tx-1',
        listingId: 'listing-1',
        cropType: 'tomato',
        quantityKg: 200,
      });

      expect(mockUsers.findAvailableDrivers).toHaveBeenCalledWith(200, []);
      expect(mockRepo.create).toHaveBeenCalledWith({
        transactionId: 'tx-1',
        listingId: 'listing-1',
        driverId: 'driver-100',
        cropType: 'tomato',
        quantityKg: 200,
      });
      expect(result).toEqual(mockJob);
    });
  });

  describe('acceptJob', () => {
    it('should throw ForbiddenError if job is not offered to requesting driver', async () => {
      mockRepo.findById.mockResolvedValue(createMockJob({ driverId: 'assigned-driver-uuid' }));

      await expect(dispatchService.acceptJob('job-1', 'different-driver-uuid')).rejects.toThrow(ForbiddenError);
    });

    it('should update job status to ACCEPTED when claimed by assigned driver', async () => {
      const driverId = 'assigned-driver-uuid';
      mockRepo.findById.mockResolvedValue(createMockJob({ driverId }));

      const updatedJob = createMockJob({ driverId, status: 'ACCEPTED' });
      mockRepo.update.mockResolvedValue(updatedJob);
      mockPrisma.orders.findUnique.mockResolvedValue({
        id: 'tx-1',
        buyer_id: 'buyer-1',
        produce_listings: { farmer_id: 'farmer-1' },
      } as any);
      jest.spyOn(notificationService, 'sendNotification').mockResolvedValue({} as any);
      jest.spyOn(auditService, 'log').mockResolvedValue({} as any);

      const result = await dispatchService.acceptJob('job-1', driverId);

      expect(mockRepo.update).toHaveBeenCalledWith('job-1', 'ACCEPTED');
      expect(mockUsers.updateProfile).toHaveBeenCalledWith(driverId, { isAvailable: false });
      expect(result).toEqual(updatedJob);
    });
  });

  describe('declineJob', () => {
    it('should decline current job and trigger manual dispatch alert when candidate drivers are exhausted', async () => {
      const driverId = 'driver-1';
      const jobId = 'job-1';

      mockRepo.findById.mockResolvedValue(createMockJob({ id: jobId, driverId }));
      const declinedJob = createMockJob({ id: jobId, driverId, status: 'DECLINED' });
      mockRepo.update.mockResolvedValue(declinedJob);
      mockRepo.findAllForTransaction.mockResolvedValue([declinedJob]);

      // Exhausted candidates: empty list returned
      mockUsers.findAvailableDrivers.mockResolvedValue([]);
      mockPrisma.orders.findUnique.mockResolvedValue({ id: 'tx-1', buyer_id: 'buyer-1' } as any);
      mockPrisma.user.findMany.mockResolvedValue([{ id: 'admin-1' }] as any);
      jest.spyOn(notificationService, 'sendNotification').mockResolvedValue({} as any);
      jest.spyOn(auditService, 'log').mockResolvedValue({} as any);

      const result = await dispatchService.declineJob(jobId, driverId);

      expect(mockPrisma.orders.update).toHaveBeenCalledWith({
        where: { id: 'tx-1' },
        data: { order_status: 'awaiting_driver' },
      });
      expect(result.job).toEqual(declinedJob);
      expect(result.reassigned).toBeNull();
    });
  });
});
