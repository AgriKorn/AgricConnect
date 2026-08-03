import { AuditService, computePayloadHash, truncateToSeconds } from './audit.service';
import { PrismaAuditRepository } from './audit.repository.prisma';
import { AuditEntry } from './audit.types';

describe('AuditService', () => {
  let auditService: AuditService;
  let mockRepo: jest.Mocked<PrismaAuditRepository>;

  beforeEach(() => {
    mockRepo = {
      findLatest: jest.fn(),
      create: jest.fn(),
      findByEntityId: jest.fn(),
      findFiltered: jest.fn(),
    } as any;

    auditService = new AuditService(mockRepo);
  });

  describe('log', () => {
    it('should create audit entry with GENESIS previousHash when table is empty', async () => {
      mockRepo.findLatest.mockResolvedValue(null);
      mockRepo.create.mockImplementation(async (entry) => ({
        id: '1',
        eventType: entry.eventType,
        entityId: entry.entityId,
        data: entry.data,
        userId: entry.userId,
        hash: 'calculated-hash',
        previousHash: entry.previousHash,
        createdAt: entry.createdAt || new Date(),
      }));

      const result = await auditService.log('PURCHASE_INITIATED', 'order-123', { amountGhs: 3000 }, 'user-456');

      expect(mockRepo.findLatest).toHaveBeenCalled();
      expect(mockRepo.create).toHaveBeenCalledWith(
        expect.objectContaining({
          eventType: 'PURCHASE_INITIATED',
          entityId: 'order-123',
          userId: 'user-456',
          previousHash: 'GENESIS',
        }),
      );
      expect(result.previousHash).toBe('GENESIS');
    });

    it('should chain previous entry hash when table is not empty', async () => {
      const latestEntry: AuditEntry = {
        id: '10',
        eventType: 'LISTING_CREATED',
        entityId: 'listing-99',
        data: {},
        userId: 'farmer-1',
        hash: 'prev-entry-sha256-hash',
        previousHash: 'GENESIS',
        createdAt: new Date(),
      };
      mockRepo.findLatest.mockResolvedValue(latestEntry);
      mockRepo.create.mockImplementation(async (e) => ({
        id: '11',
        eventType: e.eventType,
        entityId: e.entityId,
        data: e.data,
        userId: e.userId,
        hash: e.hash || 'h11',
        previousHash: e.previousHash,
        createdAt: e.createdAt || new Date(),
      }));

      const result = await auditService.log('PAYMENT_HELD', 'order-123', { amountGhs: 3000 }, 'buyer-1');

      expect(mockRepo.create).toHaveBeenCalledWith(
        expect.objectContaining({
          previousHash: 'prev-entry-sha256-hash',
        }),
      );
      expect(result.previousHash).toBe('prev-entry-sha256-hash');
    });
  });

  describe('verifyChainForEntity', () => {
    it('should return valid=true with totalEntries=0 when entity has no logs', async () => {
      mockRepo.findByEntityId.mockResolvedValue([]);
      const result = await auditService.verifyChainForEntity('unknown-entity');
      expect(result).toEqual({ valid: true, totalEntries: 0 });
    });

    it('should detect tampering when event_data on middle entry is modified', async () => {
      const entityId = 'target-order-uuid';
      const d1 = truncateToSeconds(new Date('2026-07-22T20:00:00.000Z'));
      const d2 = truncateToSeconds(new Date('2026-07-22T20:01:00.000Z'));
      const d3 = truncateToSeconds(new Date('2026-07-22T20:02:00.000Z'));

      const h1 = computePayloadHash('GENESIS', 'PURCHASE_INITIATED', entityId, 'buyer-1', { amountGhs: 3000 }, d1);
      const h2 = computePayloadHash(h1, 'PAYMENT_HELD', entityId, 'buyer-1', { amountGhs: 3000 }, d2);
      const h3 = computePayloadHash(h2, 'PAYMENT_RELEASED', entityId, 'buyer-1', { amountGhs: 3000 }, d3);

      const validEntries: AuditEntry[] = [
        { id: '101', eventType: 'PURCHASE_INITIATED', entityId, userId: 'buyer-1', data: { amountGhs: 3000 }, previousHash: 'GENESIS', hash: h1, createdAt: d1 },
        { id: '102', eventType: 'PAYMENT_HELD', entityId, userId: 'buyer-1', data: { amountGhs: 3000 }, previousHash: h1, hash: h2, createdAt: d2 },
        { id: '103', eventType: 'PAYMENT_RELEASED', entityId, userId: 'buyer-1', data: { amountGhs: 3000 }, previousHash: h2, hash: h3, createdAt: d3 },
      ];

      // Mutate entry #2 data (tampering simulation)
      const tamperedEntries = [
        validEntries[0],
        { ...validEntries[1], data: { amountGhs: 9999 } }, // Tampered data!
        validEntries[2],
      ];

      mockRepo.findByEntityId.mockResolvedValue(tamperedEntries);

      const result = await auditService.verifyChainForEntity(entityId);

      expect(result.valid).toBe(false);
      expect(result.totalEntries).toBe(3);
      expect(result.brokenEntryId).toBe('102');
      expect(result.failureReason).toContain('Hash tampering detected at entry 102');
    });

    it('should return valid=true for intact unbroken audit trail', async () => {
      const entityId = 'target-order-uuid';
      const d1 = truncateToSeconds(new Date('2026-07-22T20:00:00.000Z'));
      const d2 = truncateToSeconds(new Date('2026-07-22T20:01:00.000Z'));

      const h1 = computePayloadHash('GENESIS', 'PURCHASE_INITIATED', entityId, 'buyer-1', { amountGhs: 3000 }, d1);
      const h2 = computePayloadHash(h1, 'PAYMENT_HELD', entityId, 'buyer-1', { amountGhs: 3000 }, d2);

      const validEntries: AuditEntry[] = [
        { id: '101', eventType: 'PURCHASE_INITIATED', entityId, userId: 'buyer-1', data: { amountGhs: 3000 }, previousHash: 'GENESIS', hash: h1, createdAt: d1 },
        { id: '102', eventType: 'PAYMENT_HELD', entityId, userId: 'buyer-1', data: { amountGhs: 3000 }, previousHash: h1, hash: h2, createdAt: d2 },
      ];

      mockRepo.findByEntityId.mockResolvedValue(validEntries);

      const result = await auditService.verifyChainForEntity(entityId);
      expect(result).toEqual({ valid: true, totalEntries: 2 });
    });
  });

  describe('searchAuditLogs', () => {
    it('should delegate search to repo', async () => {
      const filters = { page: 1, limit: 10 };
      mockRepo.findFiltered.mockResolvedValue({ entries: [], total: 0 });

      await auditService.searchAuditLogs(filters);

      expect(mockRepo.findFiltered).toHaveBeenCalledWith(filters);
    });
  });

  describe('exportAuditLogsCsv', () => {
    it('should generate valid CSV output for audit logs', async () => {
      const entityId = 'order-100';
      const now = new Date();
      mockRepo.findByEntityId.mockResolvedValue([
        {
          id: '1',
          eventType: 'PURCHASE_INITIATED',
          entityId,
          userId: 'buyer-1',
          data: {},
          hash: 'h1',
          previousHash: 'GENESIS',
          createdAt: now,
        },
      ]);

      const csv = await auditService.exportAuditLogsCsv(entityId);
      expect(csv).toContain('ID,Event Type,Entity ID,Actor ID,Hash,Previous Hash,Created At');
      expect(csv).toContain('"1","PURCHASE_INITIATED","order-100","buyer-1","h1","GENESIS"');
    });
  });
});
