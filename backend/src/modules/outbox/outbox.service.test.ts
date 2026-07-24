import { mockDeep, DeepMockProxy } from 'jest-mock-extended';
import { PrismaClient } from '../../generated/prisma/client';

jest.mock('../../config/db', () => ({
  prisma: mockDeep<PrismaClient>(),
}));

import { prisma } from '../../config/db';
import { OutboxService } from './outbox.service';
import { OutboxWorker } from '../../workers/outbox.worker';

describe('OutboxService & OutboxWorker', () => {
  let outboxService: OutboxService;
  let mockPrisma: DeepMockProxy<PrismaClient>;

  beforeEach(() => {
    jest.clearAllMocks();
    mockPrisma = prisma as unknown as DeepMockProxy<PrismaClient>;
    outboxService = new OutboxService();
  });

  describe('recordEvent', () => {
    it('should create an outbox_event record in database inside transaction context', async () => {
      const mockCreated = {
        id: 'outbox-uuid-1',
        aggregate_type: 'ORDER',
        aggregate_id: 'order-100',
        event_type: 'ORDER_PLACED',
        payload: { amountGhs: 3000 },
        published_at: null,
        created_at: new Date(),
      };

      mockPrisma.outbox_events.create.mockResolvedValue(mockCreated as any);

      const event = await outboxService.recordEvent(mockPrisma, 'ORDER', 'order-100', 'ORDER_PLACED', {
        amountGhs: 3000,
      });

      expect(mockPrisma.outbox_events.create).toHaveBeenCalledWith({
        data: {
          aggregate_type: 'ORDER',
          aggregate_id: 'order-100',
          event_type: 'ORDER_PLACED',
          payload: { amountGhs: 3000 },
        },
      });
      expect(event.id).toBe('outbox-uuid-1');
      expect(event.publishedAt).toBeNull();
    });
  });

  describe('fetchUnpublished & markPublished', () => {
    it('should query unpublished events ordered by created_at asc', async () => {
      const mockEvents = [
        {
          id: 'outbox-1',
          aggregate_type: 'ORDER',
          aggregate_id: 'order-100',
          event_type: 'ORDER_PLACED',
          payload: {},
          published_at: null,
          created_at: new Date(),
        },
      ];

      mockPrisma.outbox_events.findMany.mockResolvedValue(mockEvents as any);

      const result = await outboxService.fetchUnpublished(10);
      expect(mockPrisma.outbox_events.findMany).toHaveBeenCalledWith({
        where: { published_at: null },
        orderBy: { created_at: 'asc' },
        take: 10,
      });
      expect(result).toHaveLength(1);
      expect(result[0].id).toBe('outbox-1');
    });

    it('should update published_at timestamp when markPublished is called', async () => {
      const publishedAt = new Date();
      const mockUpdated = {
        id: 'outbox-1',
        aggregate_type: 'ORDER',
        aggregate_id: 'order-100',
        event_type: 'ORDER_PLACED',
        payload: {},
        published_at: publishedAt,
        created_at: new Date(),
      };

      mockPrisma.outbox_events.update.mockResolvedValue(mockUpdated as any);

      const result = await outboxService.markPublished('outbox-1', publishedAt);
      expect(mockPrisma.outbox_events.update).toHaveBeenCalledWith({
        where: { id: 'outbox-1' },
        data: { published_at: publishedAt },
      });
      expect(result.publishedAt).toBe(publishedAt);
    });
  });

  describe('OutboxWorker poller loop & crash recovery', () => {
    it('should poll unpublished events, execute publisher, and stamp published_at', async () => {
      const mockEvents = [
        {
          id: 'outbox-101',
          aggregate_type: 'ORDER',
          aggregate_id: 'order-101',
          event_type: 'ORDER_PLACED',
          payload: { listingId: 'listing-1' },
          published_at: null,
          created_at: new Date(),
        },
      ];

      mockPrisma.outbox_events.findMany.mockResolvedValue(mockEvents as any);
      mockPrisma.outbox_events.update.mockResolvedValue({
        ...mockEvents[0],
        published_at: new Date(),
      } as any);

      const mockPublisher = jest.fn().mockResolvedValue(undefined);
      const worker = new OutboxWorker(mockPublisher);

      const count = await worker.processBatch();

      expect(count).toBe(1);
      expect(mockPublisher).toHaveBeenCalledWith(
        expect.objectContaining({
          id: 'outbox-101',
          eventType: 'ORDER_PLACED',
        }),
      );
      expect(mockPrisma.outbox_events.update).toHaveBeenCalledWith({
        where: { id: 'outbox-101' },
        data: { published_at: expect.any(Date) },
      });
    });

    it('should stop processing and leave remaining events unpublished if publisher throws error (Crash Recovery)', async () => {
      const mockEvents = [
        {
          id: 'outbox-201',
          aggregate_type: 'ORDER',
          aggregate_id: 'order-201',
          event_type: 'ORDER_PLACED',
          payload: {},
          published_at: null,
          created_at: new Date(),
        },
      ];

      mockPrisma.outbox_events.findMany.mockResolvedValue(mockEvents as any);

      // Injected crash/failure in publisher
      const mockPublisher = jest.fn().mockRejectedValue(new Error('SQS Network Drop'));
      const worker = new OutboxWorker(mockPublisher);

      const count = await worker.processBatch();

      expect(count).toBe(0);
      expect(mockPublisher).toHaveBeenCalledWith(expect.objectContaining({ id: 'outbox-201' }));
      // Assert that published_at was NOT updated so event remains in DB for next poll recovery
      expect(mockPrisma.outbox_events.update).not.toHaveBeenCalled();
    });
  });
});
