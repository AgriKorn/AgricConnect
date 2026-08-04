import { mockDeep, DeepMockProxy } from 'jest-mock-extended';
import { PrismaClient } from '../../generated/prisma/client';

jest.mock('../../config/db', () => ({
  prisma: mockDeep<PrismaClient>(),
}));

import { prisma } from '../../config/db';
import { DisputeService } from './dispute.service';
import { PrismaDisputeRepository } from './dispute.repository.prisma';
import { transactionRepository } from '../transaction/transaction.repository.prisma';
import { notificationService } from '../notification/notification.service';
import { auditService } from '../audit/audit.service';
import { paymentService } from '../../services/payment.service';
import { userRepository } from '../user/user.repository.prisma';
import { ConflictError, ForbiddenError, NotFoundError, PayoutNotConfiguredError } from '../../utils/errors';
import { Dispute } from './dispute.types';

describe('DisputeService', () => {
  let disputeService: DisputeService;
  let mockRepo: jest.Mocked<PrismaDisputeRepository>;
  let mockPrisma: DeepMockProxy<PrismaClient>;

  const createMockDispute = (overrides?: Partial<Dispute>): Dispute => ({
    id: 'dispute-100',
    transactionId: 'tx-500',
    raisedBy: 'buyer-1',
    type: 'NON_DELIVERY',
    description: 'Spoiled produce',
    status: 'OPEN',
    resolution: null,
    createdAt: new Date(),
    updatedAt: new Date(),
    ...overrides,
  });

  beforeEach(() => {
    jest.clearAllMocks();
    mockPrisma = prisma as unknown as DeepMockProxy<PrismaClient>;
    mockPrisma.$transaction.mockImplementation(async (cb: any) => cb(mockPrisma));

    mockRepo = {
      create: jest.fn(),
      findById: jest.fn(),
      resolve: jest.fn(),
      findAll: jest.fn(),
      findOpenByTransaction: jest.fn().mockResolvedValue(null),
    } as any;

    disputeService = new DisputeService(mockRepo);
  });

  describe('raise', () => {
    it('should throw NotFoundError if transaction is missing', async () => {
      jest.spyOn(transactionRepository, 'findById').mockResolvedValue(null);
      await expect(disputeService.raise('missing-tx', 'NON_DELIVERY', 'Damaged', 'buyer-1')).rejects.toThrow(NotFoundError);
    });

    it('should throw ForbiddenError if non-participant tries to raise dispute', async () => {
      jest.spyOn(transactionRepository, 'findById').mockResolvedValue({
        id: 'tx-500',
        buyerId: 'buyer-1',
        farmerId: 'farmer-1',
      } as any);

      await expect(disputeService.raise('tx-500', 'NON_DELIVERY', 'Damaged', 'third-party')).rejects.toThrow(ForbiddenError);
    });

    it('should successfully raise dispute and send notification', async () => {
      jest.spyOn(transactionRepository, 'findById').mockResolvedValue({
        id: 'tx-500',
        buyerId: 'buyer-1',
        farmerId: 'farmer-1',
        status: 'PAYMENT_HELD',
      } as any);

      const mockDispute = createMockDispute();
      mockRepo.create.mockResolvedValue(mockDispute);
      jest.spyOn(auditService, 'log').mockResolvedValue({} as any);
      jest.spyOn(notificationService, 'sendNotification').mockResolvedValue({} as any);

      const result = await disputeService.raise('tx-500', 'NON_DELIVERY', 'Spoiled produce', 'buyer-1');

      expect(mockRepo.create).toHaveBeenCalledWith({
        transactionId: 'tx-500',
        raisedBy: 'buyer-1',
        type: 'NON_DELIVERY',
        description: 'Spoiled produce',
      });
      expect(result).toEqual(mockDispute);
    });

    it('should throw ConflictError if the order is not in PAYMENT_HELD (e.g. already delivered/cancelled)', async () => {
      jest.spyOn(transactionRepository, 'findById').mockResolvedValue({
        id: 'tx-500',
        buyerId: 'buyer-1',
        farmerId: 'farmer-1',
        status: 'RELEASED',
      } as any);

      await expect(disputeService.raise('tx-500', 'NON_DELIVERY', 'Damaged', 'buyer-1')).rejects.toThrow(ConflictError);
      expect(mockRepo.create).not.toHaveBeenCalled();
    });

    it('should throw ConflictError if the order already has an open dispute', async () => {
      jest.spyOn(transactionRepository, 'findById').mockResolvedValue({
        id: 'tx-500',
        buyerId: 'buyer-1',
        farmerId: 'farmer-1',
        status: 'PAYMENT_HELD',
      } as any);
      mockRepo.findOpenByTransaction.mockResolvedValue(createMockDispute());

      await expect(disputeService.raise('tx-500', 'NON_DELIVERY', 'Damaged', 'buyer-1')).rejects.toThrow(ConflictError);
      expect(mockRepo.create).not.toHaveBeenCalled();
    });
  });

  describe('listAll', () => {
    it('should delegate listAll to repository', async () => {
      const mockList = [createMockDispute()];
      mockRepo.findAll.mockResolvedValue(mockList);

      const result = await disputeService.listAll();

      expect(mockRepo.findAll).toHaveBeenCalled();
      expect(result).toEqual(mockList);
    });
  });

  describe('resolve', () => {
    it('should throw NotFoundError if dispute or transaction does not exist', async () => {
      mockRepo.findById.mockResolvedValue(null);
      await expect(disputeService.resolve('dispute-1', 'Refund granted', 'REFUND_BUYER', 'admin-1')).rejects.toThrow(NotFoundError);
    });

    it('should throw ConflictError if dispute is already resolved', async () => {
      mockRepo.findById.mockResolvedValue(createMockDispute({ status: 'RESOLVED', resolution: 'Previous resolution' }));
      jest.spyOn(transactionRepository, 'findById').mockResolvedValue({ id: 'tx-500' } as any);

      await expect(disputeService.resolve('dispute-100', 'Refund granted', 'REFUND_BUYER', 'admin-1')).rejects.toThrow(ConflictError);
    });

    it('should propagate error, abort transaction, and prevent downstream audit logging if notification fails (Failure Injection)', async () => {
      const disputeId = 'dispute-100';
      const transactionId = 'tx-500';

      mockRepo.findById.mockResolvedValue(createMockDispute({ id: disputeId, transactionId }));

      jest.spyOn(transactionRepository, 'findById').mockResolvedValue({
        id: transactionId,
        listingId: 'listing-99',
        buyerId: 'buyer-1',
        farmerId: 'farmer-1',
        farmerName: 'Test Farmer',
        buyerName: 'Test Buyer',
        driverName: null,
        driverPhone: null,
        driverId: null,
        cropType: 'tomato',
        amountGhs: 3000,
        status: 'PAYMENT_HELD',
        hasOwnTransport: false,
        paymentReference: 'stub_ref',
        transferCode: null,
        createdAt: new Date(),
        updatedAt: new Date(),
      });

      mockRepo.resolve.mockResolvedValue(createMockDispute({ id: disputeId, transactionId, status: 'RESOLVED', resolution: 'Refund granted [Action: REFUND_BUYER]' }));

      jest.spyOn(transactionRepository, 'update').mockResolvedValue({} as any);
      jest.spyOn(paymentService, 'refundTransaction').mockResolvedValue({ refundReference: 'refund-1', status: 'processed' });

      // Failure injection: notification write fails mid-transaction
      jest.spyOn(notificationService, 'sendNotification').mockRejectedValue(new Error('Notification gateway error'));
      const auditLogSpy = jest.spyOn(auditService, 'log');

      // Assert error is cleanly propagated
      await expect(disputeService.resolve(disputeId, 'Refund granted', 'REFUND_BUYER', 'admin-1')).rejects.toThrow('Notification gateway error');

      // Assert downstream audit log scheduled AFTER failure point was NEVER invoked
      expect(auditLogSpy).not.toHaveBeenCalled();
    });

    it('should successfully execute REFUND_BUYER escrow side-effects', async () => {
      const disputeId = 'dispute-100';
      const transactionId = 'tx-500';

      mockRepo.findById.mockResolvedValue(createMockDispute({ id: disputeId, transactionId }));

      jest.spyOn(transactionRepository, 'findById').mockResolvedValue({
        id: transactionId,
        listingId: 'listing-99',
        buyerId: 'buyer-1',
        farmerId: 'farmer-1',
        farmerName: 'Test Farmer',
        buyerName: 'Test Buyer',
        driverName: null,
        driverPhone: null,
        driverId: null,
        cropType: 'tomato',
        amountGhs: 3000,
        status: 'PAYMENT_HELD',
        hasOwnTransport: false,
        paymentReference: 'stub_ref',
        transferCode: null,
        createdAt: new Date(),
        updatedAt: new Date(),
      });

      const resolvedRecord = createMockDispute({ id: disputeId, transactionId, status: 'RESOLVED', resolution: 'Refund granted [Action: REFUND_BUYER]' });
      mockRepo.resolve.mockResolvedValue(resolvedRecord);

      jest.spyOn(transactionRepository, 'update').mockResolvedValue({} as any);
      jest.spyOn(notificationService, 'sendNotification').mockResolvedValue({} as any);
      jest.spyOn(auditService, 'log').mockResolvedValue({} as any);
      const refundSpy = jest.spyOn(paymentService, 'refundTransaction').mockResolvedValue({ refundReference: 'refund-1', status: 'processed' });

      const result = await disputeService.resolve(disputeId, 'Refund granted', 'REFUND_BUYER', 'admin-1');

      expect(refundSpy).toHaveBeenCalledWith('stub_ref', 3000);
      expect(transactionRepository.update).toHaveBeenCalledWith(transactionId, { status: 'CANCELLED' });
      expect(mockPrisma.produce_listings.update).toHaveBeenCalledWith({
        where: { id: 'listing-99' },
        data: { status: 'active' },
      });
      expect(auditService.log).toHaveBeenCalledWith('DISPUTE_RESOLVED', transactionId, expect.any(Object), 'admin-1');
      expect(result).toEqual(resolvedRecord);
    });

    it('should successfully execute RELEASE_FARMER escrow side-effects', async () => {
      const disputeId = 'dispute-100';
      const transactionId = 'tx-500';

      mockRepo.findById.mockResolvedValue(createMockDispute({ id: disputeId, transactionId }));

      jest.spyOn(transactionRepository, 'findById').mockResolvedValue({
        id: transactionId,
        listingId: 'listing-99',
        buyerId: 'buyer-1',
        farmerId: 'farmer-1',
        farmerName: 'Test Farmer',
        buyerName: 'Test Buyer',
        driverName: null,
        driverPhone: null,
        driverId: null,
        cropType: 'tomato',
        amountGhs: 3000,
        status: 'PAYMENT_HELD',
        hasOwnTransport: false,
        paymentReference: 'stub_ref',
        transferCode: null,
        createdAt: new Date(),
        updatedAt: new Date(),
      });

      const resolvedRecord = createMockDispute({ id: disputeId, transactionId, status: 'RESOLVED', resolution: 'Funds released [Action: RELEASE_FARMER]' });
      mockRepo.resolve.mockResolvedValue(resolvedRecord);

      jest.spyOn(transactionRepository, 'update').mockResolvedValue({} as any);
      jest.spyOn(notificationService, 'sendNotification').mockResolvedValue({} as any);
      jest.spyOn(auditService, 'log').mockResolvedValue({} as any);
      jest.spyOn(userRepository, 'findById').mockResolvedValue({
        id: 'farmer-1',
        profile: { momoNumber: '+233541234567', momoNetwork: 'MTN' },
      } as any);
      const transferSpy = jest
        .spyOn(paymentService, 'initiateTransfer')
        .mockResolvedValue({ transferCode: 'transfer-1', status: 'success' });

      const result = await disputeService.resolve(disputeId, 'Funds released', 'RELEASE_FARMER', 'admin-1');

      expect(transferSpy).toHaveBeenCalledWith('+233541234567', 3000, expect.any(String), 'MTN');
      expect(transactionRepository.update).toHaveBeenCalledWith(transactionId, { status: 'RELEASED', transferCode: 'transfer-1' });
      expect(auditService.log).toHaveBeenCalledWith('DISPUTE_RESOLVED', transactionId, expect.any(Object), 'admin-1');
      expect(result).toEqual(resolvedRecord);
    });

    it('should throw PayoutNotConfiguredError for RELEASE_FARMER if the farmer has no Mobile Money details on file', async () => {
      const disputeId = 'dispute-100';
      const transactionId = 'tx-500';

      mockRepo.findById.mockResolvedValue(createMockDispute({ id: disputeId, transactionId }));

      jest.spyOn(transactionRepository, 'findById').mockResolvedValue({
        id: transactionId,
        listingId: 'listing-99',
        buyerId: 'buyer-1',
        farmerId: 'farmer-1',
        amountGhs: 3000,
        status: 'PAYMENT_HELD',
        paymentReference: 'stub_ref',
        transferCode: null,
        createdAt: new Date(),
        updatedAt: new Date(),
      } as any);
      jest.spyOn(userRepository, 'findById').mockResolvedValue({ id: 'farmer-1', profile: {} } as any);
      const transferSpy = jest.spyOn(paymentService, 'initiateTransfer');

      await expect(disputeService.resolve(disputeId, 'Funds released', 'RELEASE_FARMER', 'admin-1')).rejects.toThrow(
        PayoutNotConfiguredError,
      );
      expect(transferSpy).not.toHaveBeenCalled();
      expect(mockRepo.resolve).not.toHaveBeenCalled();
    });
  });
});
