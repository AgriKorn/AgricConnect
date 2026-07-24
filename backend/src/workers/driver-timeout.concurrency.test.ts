import { mockDeep, DeepMockProxy } from 'jest-mock-extended';
import { PrismaClient } from '../generated/prisma/client';

jest.mock('../config/db', () => ({
  prisma: mockDeep<PrismaClient>(),
}));

import { prisma } from '../config/db';
import { DriverTimeoutWorker } from './driver-timeout.worker';
import { dispatchService } from '../modules/dispatch/dispatch.service';

jest.mock('../modules/dispatch/dispatch.service', () => ({
  dispatchService: {
    reassignNextDriver: jest.fn(),
  },
}));

describe('DriverTimeoutWorker Concurrency & Multi-Instance Safety Tests', () => {
  let workerA: DriverTimeoutWorker;
  let workerB: DriverTimeoutWorker;
  let mockPrisma: DeepMockProxy<PrismaClient>;

  beforeEach(() => {
    jest.clearAllMocks();
    mockPrisma = prisma as unknown as DeepMockProxy<PrismaClient>;
    workerA = new DriverTimeoutWorker(3);
    workerB = new DriverTimeoutWorker(3);
  });

  afterEach(() => {
    workerA.stop();
    workerB.stop();
  });

  it('should prevent duplicate driver reassignments when two workers execute concurrently', async () => {
    const mockExpired = [
      {
        id: 'assignment-100',
        order_id: 'order-999',
        driver_id: 'driver-111',
        sequence_number: 1,
        status: 'notified',
        notified_at: new Date(Date.now() - 5 * 60 * 1000),
      },
    ];

    // Simulate Worker A claiming the row first, and Worker B returning 0 rows because Worker A locked it
    mockPrisma.$queryRaw
      .mockResolvedValueOnce(mockExpired as any) // Worker A gets candidate
      .mockResolvedValueOnce([] as any);          // Worker B gets empty list due to SKIP LOCKED

    (dispatchService.reassignNextDriver as jest.Mock).mockResolvedValue(null);

    // Run both workers simultaneously
    const [countA, countB] = await Promise.all([
      workerA.processExpiredAssignments(),
      workerB.processExpiredAssignments(),
    ]);

    expect(countA + countB).toBe(1);
    expect(dispatchService.reassignNextDriver).toHaveBeenCalledTimes(1);
    expect(dispatchService.reassignNextDriver).toHaveBeenCalledWith('order-999');
  });
});
