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
    farmerName: 'Test Farmer',
    farmerPhone: '+233541111111',
    pickupRegion: 'Greater Accra',
    buyerName: 'Test Buyer',
    buyerPhone: '+233542222222',
    dropoffRegion: 'Ashanti',
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
      mockPrisma.$queryRaw.mockResolvedValue([{ id: 'job-1' }] as any);

      const updatedJob = createMockJob({ driverId, status: 'ACCEPTED' });
      mockRepo.findById.mockResolvedValueOnce(createMockJob({ driverId })).mockResolvedValueOnce(updatedJob);
      mockPrisma.orders.findUnique.mockResolvedValue({
        id: 'tx-1',
        buyer_id: 'buyer-1',
        produce_listings: { farmer_id: 'farmer-1' },
      } as any);
      jest.spyOn(notificationService, 'sendNotification').mockResolvedValue({} as any);
      jest.spyOn(auditService, 'log').mockResolvedValue({} as any);

      const result = await dispatchService.acceptJob('job-1', driverId);

      expect(mockUsers.updateProfile).toHaveBeenCalledWith(driverId, { isAvailable: false });
      expect(result).toEqual(updatedJob);
    });

    it('should reject acceptance when the order already has a different driver accepted', async () => {
      // Two live driver_assignments rows can exist for the same order (a
      // manual admin assignment overlapping an automatic offer, or a race in
      // decline-and-reassign) — the atomic claim query's NOT EXISTS guard
      // must refuse the second acceptance rather than letting both succeed.
      const driverId = 'second-driver-uuid';
      mockRepo.findById.mockResolvedValue(createMockJob({ driverId, id: 'job-2' }));
      mockPrisma.$queryRaw.mockResolvedValue([] as any);
      mockPrisma.driver_assignments.findFirst.mockResolvedValue({
        id: 'job-1',
        status: 'accepted',
      } as any);

      await expect(dispatchService.acceptJob('job-2', driverId)).rejects.toThrow(
        'This order has already been assigned to another driver',
      );
      expect(mockUsers.updateProfile).not.toHaveBeenCalled();
    });

    it('should reject acceptance when the assignment is no longer pending and no rival exists', async () => {
      const driverId = 'assigned-driver-uuid';
      mockRepo.findById.mockResolvedValue(createMockJob({ driverId }));
      mockPrisma.$queryRaw.mockResolvedValue([] as any);
      mockPrisma.driver_assignments.findFirst.mockResolvedValue(null);

      await expect(dispatchService.acceptJob('job-1', driverId)).rejects.toThrow('Job is no longer pending');
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
