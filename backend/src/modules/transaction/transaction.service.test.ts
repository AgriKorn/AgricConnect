import { mockDeep, DeepMockProxy } from 'jest-mock-extended';
import { PrismaClient } from '../../generated/prisma/client';

// Mock DB module before importing transactionService
jest.mock('../../config/db', () => ({
  prisma: mockDeep<PrismaClient>(),
}));

import { prisma } from '../../config/db';
import { TransactionService } from './transaction.service';
import { PrismaTransactionRepository } from './transaction.repository.prisma';
import { listingRepository } from '../listing/listing.repository.prisma';
import { userRepository } from '../user/user.repository.prisma';
import { notificationService } from '../notification/notification.service';
import { dispatchService } from '../dispatch/dispatch.service';
import { paymentService } from '../../services/payment.service';
import { ConflictError, ForbiddenError, NotFoundError } from '../../utils/errors';
import { Transaction } from './transaction.types';

describe('TransactionService', () => {
  let transactionService: TransactionService;
  let mockRepo: jest.Mocked<PrismaTransactionRepository>;
  let mockPrisma: DeepMockProxy<PrismaClient>;

  const createMockTx = (overrides?: Partial<Transaction>): Transaction => ({
    id: 'tx-100',
    listingId: 'listing-123',
    buyerId: 'buyer-456',
    farmerId: 'farmer-789',
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
    ...overrides,
  });

  beforeEach(() => {
    jest.clearAllMocks();
    mockPrisma = prisma as unknown as DeepMockProxy<PrismaClient>;
    mockPrisma.$transaction.mockImplementation(async (cb: any) => cb(mockPrisma));

    const mockAuditRecord = {
      id: 'audit-1',
      event_type: 'PURCHASE_INITIATED',
      entity_id: 'tx-100',
      actor_id: 'buyer-456',
      event_data: {},
      event_hash: 'hash-val',
      previous_hash: 'GENESIS',
      created_at: new Date(),
    };

    mockPrisma.auditTrail.create.mockResolvedValue(mockAuditRecord as any);
    mockPrisma.auditTrail.update.mockResolvedValue(mockAuditRecord as any);

    mockPrisma.outbox_events.create.mockResolvedValue({
      id: 'outbox-1',
      aggregate_type: 'ORDER',
      aggregate_id: 'tx-100',
      event_type: 'ORDER_PLACED',
      payload: {},
      published_at: null,
      created_at: new Date(),
    } as any);

    mockRepo = {
      findRecentOrderByBuyerAndListing: jest.fn(),
      create: jest.fn(),
      findById: jest.fn(),
      update: jest.fn(),
      findManyForUser: jest.fn(),
      findAll: jest.fn(),
    } as any;

    transactionService = new TransactionService(mockRepo);
  });

  describe('purchase', () => {
    it('should throw NotFoundError if listing does not exist', async () => {
      jest.spyOn(listingRepository, 'findById').mockResolvedValue(null);

      await expect(transactionService.purchase('non-existent-listing', 'buyer-1', false)).rejects.toThrow(NotFoundError);
    });

    it('should return existing order idempotently if recent order exists within 60s window', async () => {
      const listingId = 'listing-123';
      const buyerId = 'buyer-456';

      jest.spyOn(listingRepository, 'findById').mockResolvedValue({
        id: listingId,
        farmerId: 'farmer-789',
        cropType: 'tomato',
        cropCategory: 'vegetables',
        quantityKg: 200,
        freshnessScore: 9.5,
        shelfLifeDays: 7,
        farmerLat: 5.6,
        farmerLong: -0.18,
        pricePerKg: 15.0,
        listingHash: 'hash-123',
        qrCodeData: 'hash-123',
        status: 'ACTIVE',
        createdAt: new Date(),
        updatedAt: new Date(),
      });

      const recentTx = createMockTx({ listingId, buyerId });
      mockRepo.findRecentOrderByBuyerAndListing.mockResolvedValue(recentTx);
      jest.spyOn(dispatchService, 'findActiveForTransaction').mockResolvedValue(null);

      const result = await transactionService.purchase(listingId, buyerId, false);
      expect(result.transaction).toEqual(recentTx);
      expect(result.dispatch).toBeNull();
    });

    it('should throw ConflictError if atomic status transition lock returns updatedCount=0 (listing already sold)', async () => {
      const listingId = 'listing-123';
      const buyerId = 'buyer-456';

      jest.spyOn(listingRepository, 'findById').mockResolvedValue({
        id: listingId,
        farmerId: 'farmer-789',
        cropType: 'tomato',
        cropCategory: 'vegetables',
        quantityKg: 200,
        freshnessScore: 9.5,
        shelfLifeDays: 7,
        farmerLat: 5.6,
        farmerLong: -0.18,
        pricePerKg: 15.0,
        listingHash: 'hash-123',
        qrCodeData: 'hash-123',
        status: 'ACTIVE',
        createdAt: new Date(),
        updatedAt: new Date(),
      });

      mockRepo.findRecentOrderByBuyerAndListing.mockResolvedValue(null);
      jest.spyOn(userRepository, 'findById').mockResolvedValue({ phone: '+233541234567' } as any);

      // Atomic lock failure simulation: updatedCount = 0
      mockPrisma.produce_listings.updateMany.mockResolvedValue({ count: 0 });

      await expect(transactionService.purchase(listingId, buyerId, false)).rejects.toThrow(ConflictError);
      expect(mockPrisma.produce_listings.updateMany).toHaveBeenCalledWith({
        where: { id: listingId, status: 'active' },
        data: expect.objectContaining({ status: 'sold' }),
      });
    });

    it('should propagate error, abort transaction, and prevent downstream side-effects if notification fails (Failure Injection)', async () => {
      const listingId = 'listing-123';
      const buyerId = 'buyer-456';

      jest.spyOn(listingRepository, 'findById').mockResolvedValue({
        id: listingId,
        farmerId: 'farmer-789',
        cropType: 'tomato',
        cropCategory: 'vegetables',
        quantityKg: 200,
        freshnessScore: 9.5,
        shelfLifeDays: 7,
        farmerLat: 5.6,
        farmerLong: -0.18,
        pricePerKg: 15.0,
        listingHash: 'hash-123',
        qrCodeData: 'hash-123',
        status: 'ACTIVE',
        createdAt: new Date(),
        updatedAt: new Date(),
      });

      mockRepo.findRecentOrderByBuyerAndListing.mockResolvedValue(null);
      jest.spyOn(userRepository, 'findById').mockResolvedValue({ phone: '+233541234567' } as any);

      mockPrisma.produce_listings.updateMany.mockResolvedValue({ count: 1 });

      mockRepo.create.mockResolvedValue(createMockTx({ id: 'order-uuid-101', listingId, buyerId }));

      // Failure injection: notification write fails mid-transaction
      jest.spyOn(notificationService, 'sendNotification').mockRejectedValue(new Error('Notification DB failure'));
      const assignDriverSpy = jest.spyOn(dispatchService, 'assignDriver');

      // Assert error is cleanly propagated
      await expect(transactionService.purchase(listingId, buyerId, false)).rejects.toThrow('Notification DB failure');

      // Assert downstream side-effect (driver assignment) scheduled AFTER failure point was NEVER invoked
      expect(assignDriverSpy).not.toHaveBeenCalled();
    });
  });

  describe('getTransaction & getMyTransactions & getAllTransactions', () => {
    it('should throw NotFoundError if transaction is missing', async () => {
      mockRepo.findById.mockResolvedValue(null);
      await expect(transactionService.getTransaction('missing-id', 'user-1', 'buyer')).rejects.toThrow(NotFoundError);
    });

    it('should throw ForbiddenError if non-participant non-admin tries to view transaction', async () => {
      mockRepo.findById.mockResolvedValue(createMockTx({ buyerId: 'buyer-1', farmerId: 'farmer-1' }));
      await expect(transactionService.getTransaction('tx-100', 'unrelated-user', 'buyer')).rejects.toThrow(ForbiddenError);
    });

    it('should return transaction record for participant or admin', async () => {
      const mockTx = createMockTx({ buyerId: 'buyer-1' });
      mockRepo.findById.mockResolvedValue(mockTx);
      const result = await transactionService.getTransaction('tx-100', 'buyer-1', 'buyer');
      expect(result).toEqual(mockTx);
    });

    it('should return user transactions on getMyTransactions', async () => {
      const mockList = [createMockTx()];
      mockRepo.findManyForUser.mockResolvedValue(mockList);
      const result = await transactionService.getMyTransactions('buyer-456');
      expect(result).toEqual(mockList);
    });

    it('should return all transactions for admin on getAllTransactions', async () => {
      const mockList = [createMockTx()];
      mockRepo.findAll.mockResolvedValue(mockList);
      const result = await transactionService.getAllTransactions();
      expect(result).toEqual(mockList);
    });
  });

  describe('confirmDelivery', () => {
    it('should throw BadRequestError if QR hash does not match listing hash', async () => {
      const transactionId = 'tx-100';

      mockRepo.findById.mockResolvedValue(createMockTx({ id: transactionId, listingId: 'listing-1', buyerId: 'buyer-1' }));
      jest.spyOn(dispatchService, 'getDriverJobs').mockResolvedValue([]);

      jest.spyOn(listingRepository, 'findById').mockResolvedValue({
        id: 'listing-1',
        listingHash: 'correct-qr-hash-123',
      } as any);

      await expect(transactionService.confirmDelivery(transactionId, 'WRONG-QR-HASH', 'buyer-1')).rejects.toThrow(
        'QR hash does not match this listing',
      );
    });

    it('should propagate failure and prevent downstream markCompleted if QR scan record fails (Failure Injection)', async () => {
      const transactionId = 'tx-100';
      const validHash = 'correct-hash-123';

      mockRepo.findById.mockResolvedValue(createMockTx({ id: transactionId, listingId: 'listing-1', buyerId: 'buyer-1' }));
      jest.spyOn(dispatchService, 'getDriverJobs').mockResolvedValue([]);

      jest.spyOn(listingRepository, 'findById').mockResolvedValue({
        id: 'listing-1',
        listingHash: validHash,
      } as any);

      jest.spyOn(userRepository, 'findById').mockResolvedValue({
        id: 'farmer-789',
        profile: { momoNumber: '+233541234567', momoNetwork: 'MTN' },
      } as any);
      jest.spyOn(paymentService, 'initiateTransfer').mockResolvedValue({ transferCode: 'trf_test123', status: 'success' });

      // Failure injection: qr_scans write fails
      mockPrisma.qr_scans.create.mockRejectedValue(new Error('QR Scan DB insert failure'));
      const markCompletedSpy = jest.spyOn(dispatchService, 'markCompleted');

      await expect(transactionService.confirmDelivery(transactionId, validHash, 'buyer-1')).rejects.toThrow(
        'QR Scan DB insert failure',
      );

      // Assert downstream dispatch markCompleted was NEVER invoked
      expect(markCompletedSpy).not.toHaveBeenCalled();
    });

    it('should successfully confirm delivery and release escrow funds', async () => {
      const transactionId = 'tx-100';
      const validHash = 'correct-hash-123';

      const mockTx = createMockTx({ id: transactionId, listingId: 'listing-1', buyerId: 'buyer-1', status: 'PAYMENT_HELD' });
      mockRepo.findById.mockResolvedValue(mockTx);
      jest.spyOn(dispatchService, 'getDriverJobs').mockResolvedValue([]);
      jest.spyOn(listingRepository, 'findById').mockResolvedValue({ id: 'listing-1', listingHash: validHash } as any);

      jest.spyOn(userRepository, 'findById').mockResolvedValue({
        id: 'farmer-789',
        profile: { momoNumber: '+233541234567', momoNetwork: 'MTN' },
      } as any);
      jest.spyOn(paymentService, 'initiateTransfer').mockResolvedValue({ transferCode: 'trf_test123', status: 'success' });

      mockPrisma.qr_scans.create.mockResolvedValue({} as any);
      const releasedTx = { ...mockTx, status: 'RELEASED' as const, transferCode: 'trf_test123' };
      mockRepo.update.mockResolvedValue(releasedTx);

      jest.spyOn(notificationService, 'sendNotification').mockResolvedValue({} as any);
      jest.spyOn(dispatchService, 'markCompleted').mockResolvedValue({} as any);

      const result = await transactionService.confirmDelivery(transactionId, validHash, 'buyer-1');

      expect(paymentService.initiateTransfer).toHaveBeenCalledWith('+233541234567', mockTx.amountGhs, expect.any(String), 'MTN');
      expect(mockRepo.update).toHaveBeenCalledWith(transactionId, { status: 'RELEASED', transferCode: 'trf_test123' });
      expect(dispatchService.markCompleted).toHaveBeenCalledWith(transactionId);
      expect(result).toEqual(releasedTx);
    });
  });
});
