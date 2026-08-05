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
    it('should return null when no driver is eligible', async () => {
      mockUsers.findAvailableDrivers.mockResolvedValue([]);

      const result = await dispatchService.assignDriver({
        transactionId: 'tx-1',
        listingId: 'listing-1',
        cropType: 'tomato',
        quantityKg: 200,
      });

      expect(mockUsers.findAvailableDrivers).toHaveBeenCalledWith(200, []);
      expect(mockRepo.create).not.toHaveBeenCalled();
      expect(result).toBeNull();
    });

    it('should broadcast the job to every eligible driver, not just one', async () => {
      const candidates = [
        { id: 'driver-100', name: 'Kwame Transport' },
        { id: 'driver-200', name: 'Ama Logistics' },
        { id: 'driver-300', name: 'Kojo Freight' },
      ];
      mockUsers.findAvailableDrivers.mockResolvedValue(candidates as any);
      mockRepo.create.mockImplementation((data: any) => Promise.resolve(createMockJob({ driverId: data.driverId, id: `job-${data.driverId}` })));
      jest.spyOn(auditService, 'log').mockResolvedValue({} as any);
      jest.spyOn(notificationService, 'sendNotification').mockResolvedValue({} as any);

      const result = await dispatchService.assignDriver({
        transactionId: 'tx-1',
        listingId: 'listing-1',
        cropType: 'tomato',
        quantityKg: 200,
      });

      expect(mockRepo.create).toHaveBeenCalledTimes(3);
      expect(notificationService.sendNotification).toHaveBeenCalledTimes(3);
      candidates.forEach((c) => {
        expect(mockRepo.create).toHaveBeenCalledWith(expect.objectContaining({ driverId: c.id }));
      });
      // Returns the first offer created — nothing depends on which
      // specifically, since every candidate got their own live offer.
      expect(result?.driverId).toBe('driver-100');
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
      // Broadcast dispatch means siblings offered to other drivers for the
      // same order have to stop looking acceptable the instant one is claimed.
      expect(mockPrisma.driver_assignments.updateMany).toHaveBeenCalledWith({
        where: { order_id: 'tx-1', status: 'notified', id: { not: 'job-1' } },
        data: { status: 'expired', responded_at: expect.any(Date) },
      });
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
    it('should not trigger the exhaustion flow while other drivers still have a live offer', async () => {
      // Broadcast dispatch: this driver declining doesn't need a "next"
      // candidate found for them — everyone else the job went to already
      // has their own copy.
      const driverId = 'driver-1';
      const jobId = 'job-1';

      mockRepo.findById.mockResolvedValue(createMockJob({ id: jobId, driverId, transactionId: 'tx-1' }));
      const declinedJob = createMockJob({ id: jobId, driverId, status: 'DECLINED' });
      mockRepo.update.mockResolvedValue(declinedJob);
      mockPrisma.driver_assignments.count.mockResolvedValue(2); // two siblings still notified

      const result = await dispatchService.declineJob(jobId, driverId);

      expect(mockPrisma.orders.update).not.toHaveBeenCalled();
      expect(result.job).toEqual(declinedJob);
      expect(result.othersStillPending).toBe(true);
    });

    it('should trigger the manual-dispatch alert once every offer for the order is gone', async () => {
      const driverId = 'driver-1';
      const jobId = 'job-1';

      mockRepo.findById.mockResolvedValue(createMockJob({ id: jobId, driverId, transactionId: 'tx-1' }));
      const declinedJob = createMockJob({ id: jobId, driverId, status: 'DECLINED' });
      mockRepo.update.mockResolvedValue(declinedJob);
      mockPrisma.driver_assignments.count.mockResolvedValue(0); // this was the last one

      mockPrisma.orders.findUnique.mockResolvedValue({ id: 'tx-1', buyer_id: 'buyer-1' } as any);
      mockPrisma.user.findMany.mockResolvedValue([{ id: 'admin-1' }] as any);
      jest.spyOn(notificationService, 'sendNotification').mockResolvedValue({} as any);
      jest.spyOn(auditService, 'log').mockResolvedValue({} as any);

      const result = await dispatchService.declineJob(jobId, driverId);

      expect(mockPrisma.orders.update).toHaveBeenCalledWith({
        where: { id: 'tx-1' },
        data: { order_status: 'awaiting_driver' },
      });
      expect(notificationService.sendNotification).toHaveBeenCalledWith(
        expect.objectContaining({ userId: 'admin-1', type: 'MANUAL_DISPATCH_REQUIRED' }),
      );
      expect(notificationService.sendNotification).toHaveBeenCalledWith(
        expect.objectContaining({ userId: 'buyer-1', type: 'DISPATCH_DELAYED' }),
      );
      expect(result.job).toEqual(declinedJob);
      expect(result.othersStillPending).toBe(false);
    });
  });

  describe('reassignNextDriver (timeout worker path)', () => {
    it('should do nothing when other offers for the order are still live', async () => {
      mockPrisma.driver_assignments.count.mockResolvedValue(3);

      await dispatchService.reassignNextDriver('tx-1');

      expect(mockPrisma.orders.update).not.toHaveBeenCalled();
    });

    it('should run the exhaustion flow when the last offer for the order has expired', async () => {
      mockPrisma.driver_assignments.count.mockResolvedValue(0);
      mockPrisma.orders.findUnique.mockResolvedValue({ id: 'tx-1', buyer_id: 'buyer-1' } as any);
      mockPrisma.user.findMany.mockResolvedValue([{ id: 'admin-1' }] as any);
      jest.spyOn(notificationService, 'sendNotification').mockResolvedValue({} as any);
      jest.spyOn(auditService, 'log').mockResolvedValue({} as any);

      await dispatchService.reassignNextDriver('tx-1');

      expect(mockPrisma.orders.update).toHaveBeenCalledWith({
        where: { id: 'tx-1' },
        data: { order_status: 'awaiting_driver' },
      });
    });
  });
});
