import { mockDeep, DeepMockProxy } from 'jest-mock-extended';
import { PrismaClient } from '../generated/prisma/client';

jest.mock('../config/db', () => ({
  prisma: mockDeep<PrismaClient>(),
}));

import { prisma } from '../config/db';
import { OutboxWorker } from './outbox.worker';
import { outboxService } from '../modules/outbox/outbox.service';

describe('OutboxWorker', () => {
  let mockPrisma: DeepMockProxy<PrismaClient>;

  const claimedRow = (id: string, overrides?: Record<string, unknown>) => ({
    id,
    aggregate_type: 'ORDER',
    aggregate_id: `order-${id}`,
    event_type: 'ORDER_PLACED',
    payload: { amountGhs: 3000 },
    published_at: null,
    created_at: new Date('2026-07-28T00:00:00Z'),
    ...overrides,
  });

  beforeEach(() => {
    jest.clearAllMocks();
    mockPrisma = prisma as unknown as DeepMockProxy<PrismaClient>;
    mockPrisma.outbox_events.update.mockImplementation((async (args: any) => ({
      ...claimedRow(args.where.id),
      published_at: args.data.published_at,
    })) as any);
  });

  describe('processBatch — atomic SKIP LOCKED claiming', () => {
    it('should map claimed snake_case rows onto the camelCase event shape', async () => {
      mockPrisma.$queryRaw.mockResolvedValue([claimedRow('outbox-1')] as any);
      const publisher = jest.fn().mockResolvedValue(undefined);

      const count = await new OutboxWorker(publisher).processBatch();

      expect(count).toBe(1);
      expect(publisher).toHaveBeenCalledWith({
        id: 'outbox-1',
        aggregateType: 'ORDER',
        aggregateId: 'order-outbox-1',
        eventType: 'ORDER_PLACED',
        payload: { amountGhs: 3000 },
        publishedAt: null,
        createdAt: new Date('2026-07-28T00:00:00Z'),
      });
    });

    it('should default a null payload to an empty object so publishers never see null', async () => {
      mockPrisma.$queryRaw.mockResolvedValue([claimedRow('outbox-1', { payload: null })] as any);
      const publisher = jest.fn().mockResolvedValue(undefined);

      await new OutboxWorker(publisher).processBatch();

      expect(publisher).toHaveBeenCalledWith(expect.objectContaining({ payload: {} }));
    });

    it('should return 0 and skip the publisher when nothing is claimable', async () => {
      mockPrisma.$queryRaw.mockResolvedValue([] as any);
      const publisher = jest.fn().mockResolvedValue(undefined);

      const count = await new OutboxWorker(publisher).processBatch();

      expect(count).toBe(0);
      expect(publisher).not.toHaveBeenCalled();
      expect(mockPrisma.outbox_events.update).not.toHaveBeenCalled();
    });

    it('should publish a claimed batch in order and stamp each event published', async () => {
      mockPrisma.$queryRaw.mockResolvedValue([claimedRow('outbox-1'), claimedRow('outbox-2'), claimedRow('outbox-3')] as any);
      const publisher = jest.fn().mockResolvedValue(undefined);

      const count = await new OutboxWorker(publisher).processBatch();

      expect(count).toBe(3);
      expect(publisher.mock.calls.map((call) => call[0].id)).toEqual(['outbox-1', 'outbox-2', 'outbox-3']);
      expect(mockPrisma.outbox_events.update).toHaveBeenCalledTimes(3);
    });

    it('should fall back to a plain unpublished query when the raw claim fails (mock/unit environments)', async () => {
      mockPrisma.$queryRaw.mockRejectedValue(new Error('SKIP LOCKED unsupported'));
      const fetchSpy = jest.spyOn(outboxService, 'fetchUnpublished').mockResolvedValue([
        {
          id: 'outbox-9',
          aggregateType: 'ORDER',
          aggregateId: 'order-9',
          eventType: 'ORDER_PLACED',
          payload: {},
          publishedAt: null,
          createdAt: new Date(),
        },
      ]);
      const publisher = jest.fn().mockResolvedValue(undefined);

      const count = await new OutboxWorker(publisher).processBatch();

      expect(fetchSpy).toHaveBeenCalledWith(50);
      expect(count).toBe(1);
      fetchSpy.mockRestore();
    });
  });

  describe('processBatch — at-least-once delivery guarantees', () => {
    it('should halt the batch at the first publish failure, leaving later events unclaimed', async () => {
      mockPrisma.$queryRaw.mockResolvedValue([claimedRow('outbox-1'), claimedRow('outbox-2'), claimedRow('outbox-3')] as any);
      const publisher = jest
        .fn()
        .mockResolvedValueOnce(undefined)
        .mockRejectedValueOnce(new Error('SQS network drop'))
        .mockResolvedValue(undefined);

      const count = await new OutboxWorker(publisher).processBatch();

      // Ordering matters for downstream consumers, so a failure must stop the
      // batch rather than skipping ahead to the next event.
      expect(count).toBe(1);
      expect(publisher).toHaveBeenCalledTimes(2);
      expect(mockPrisma.outbox_events.update).toHaveBeenCalledTimes(1);
      expect(mockPrisma.outbox_events.update).toHaveBeenCalledWith({
        where: { id: 'outbox-1' },
        data: { published_at: expect.any(Date) },
      });
    });

    it('should leave the event unpublished when marking it published fails, accepting a redelivery', async () => {
      mockPrisma.$queryRaw.mockResolvedValue([claimedRow('outbox-1'), claimedRow('outbox-2')] as any);
      mockPrisma.outbox_events.update.mockRejectedValue(new Error('DB connection lost'));
      const publisher = jest.fn().mockResolvedValue(undefined);

      const count = await new OutboxWorker(publisher).processBatch();

      expect(count).toBe(0);
      expect(publisher).toHaveBeenCalledTimes(1);
    });

    it('should not swallow a failure into a false success count', async () => {
      mockPrisma.$queryRaw.mockResolvedValue([claimedRow('outbox-1')] as any);
      const publisher = jest.fn().mockRejectedValue(new Error('SQS network drop'));

      await expect(new OutboxWorker(publisher).processBatch()).resolves.toBe(0);
    });
  });

  describe('default publisher', () => {
    it('should resolve without a queue wired up so local dev never blocks the loop', async () => {
      mockPrisma.$queryRaw.mockResolvedValue([claimedRow('outbox-1')] as any);

      const count = await new OutboxWorker().processBatch();

      expect(count).toBe(1);
      expect(mockPrisma.outbox_events.update).toHaveBeenCalledTimes(1);
    });
  });

  describe('poll loop', () => {
    let worker: OutboxWorker;

    beforeEach(() => {
      jest.useFakeTimers();
      worker = new OutboxWorker(jest.fn().mockResolvedValue(undefined));
    });

    afterEach(() => {
      worker.stop();
      jest.useRealTimers();
    });

    it('should wait a full interval before the first poll', async () => {
      const batchSpy = jest.spyOn(worker, 'processBatch').mockResolvedValue(1);

      worker.start(1000);
      await jest.advanceTimersByTimeAsync(999);
      expect(batchSpy).not.toHaveBeenCalled();

      await jest.advanceTimersByTimeAsync(1);
      expect(batchSpy).toHaveBeenCalledTimes(1);
    });

    it('should keep polling at the base interval while events keep arriving', async () => {
      const batchSpy = jest.spyOn(worker, 'processBatch').mockResolvedValue(5);

      worker.start(1000);
      await jest.advanceTimersByTimeAsync(3000);

      expect(batchSpy).toHaveBeenCalledTimes(3);
    });

    it('should back off to double the interval after an empty poll', async () => {
      const batchSpy = jest.spyOn(worker, 'processBatch').mockResolvedValue(0);

      worker.start(1000);
      await jest.advanceTimersByTimeAsync(1000);
      expect(batchSpy).toHaveBeenCalledTimes(1);

      // Backed off to 2000ms — the base interval alone is no longer enough.
      await jest.advanceTimersByTimeAsync(1000);
      expect(batchSpy).toHaveBeenCalledTimes(1);

      await jest.advanceTimersByTimeAsync(1000);
      expect(batchSpy).toHaveBeenCalledTimes(2);
    });

    it('should cap the backoff at 5 seconds', async () => {
      const batchSpy = jest.spyOn(worker, 'processBatch').mockResolvedValue(0);

      worker.start(4000);
      await jest.advanceTimersByTimeAsync(4000);
      expect(batchSpy).toHaveBeenCalledTimes(1);

      // 4000 * 2 would be 8000, but the cap holds it at 5000.
      await jest.advanceTimersByTimeAsync(5000);
      expect(batchSpy).toHaveBeenCalledTimes(2);
    });

    it('should survive a batch error and retry at the base interval', async () => {
      const batchSpy = jest
        .spyOn(worker, 'processBatch')
        .mockRejectedValueOnce(new Error('DB connection lost'))
        .mockResolvedValue(1);

      worker.start(1000);
      await jest.advanceTimersByTimeAsync(1000);
      expect(batchSpy).toHaveBeenCalledTimes(1);

      await jest.advanceTimersByTimeAsync(1000);
      expect(batchSpy).toHaveBeenCalledTimes(2);
    });

    it('should ignore a second start so one instance never runs two loops', async () => {
      const batchSpy = jest.spyOn(worker, 'processBatch').mockResolvedValue(1);

      worker.start(1000);
      worker.start(1000);
      await jest.advanceTimersByTimeAsync(1000);

      expect(batchSpy).toHaveBeenCalledTimes(1);
    });

    it('should stop polling once stopped', async () => {
      const batchSpy = jest.spyOn(worker, 'processBatch').mockResolvedValue(1);

      worker.start(1000);
      await jest.advanceTimersByTimeAsync(1000);
      expect(batchSpy).toHaveBeenCalledTimes(1);

      worker.stop();
      await jest.advanceTimersByTimeAsync(10000);

      expect(batchSpy).toHaveBeenCalledTimes(1);
    });

    it('should not schedule a follow-up poll when stopped mid-batch', async () => {
      const batchSpy = jest.spyOn(worker, 'processBatch').mockImplementation(async () => {
        worker.stop();
        return 1;
      });

      worker.start(1000);
      await jest.advanceTimersByTimeAsync(1000);
      expect(batchSpy).toHaveBeenCalledTimes(1);

      await jest.advanceTimersByTimeAsync(10000);
      expect(batchSpy).toHaveBeenCalledTimes(1);
    });

    it('should tolerate stop being called before start', () => {
      expect(() => worker.stop()).not.toThrow();
    });

    it('should be restartable after a stop', async () => {
      const batchSpy = jest.spyOn(worker, 'processBatch').mockResolvedValue(1);

      worker.start(1000);
      await jest.advanceTimersByTimeAsync(1000);
      worker.stop();

      worker.start(1000);
      await jest.advanceTimersByTimeAsync(1000);

      expect(batchSpy).toHaveBeenCalledTimes(2);
    });
  });
});
