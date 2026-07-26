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

describe('DriverTimeoutWorker', () => {
  let worker: DriverTimeoutWorker;
  let mockPrisma: DeepMockProxy<PrismaClient>;

  beforeEach(() => {
    jest.clearAllMocks();
    mockPrisma = prisma as unknown as DeepMockProxy<PrismaClient>;
    worker = new DriverTimeoutWorker(3);
  });

  afterEach(() => {
    worker.stop();
  });

  it('should process expired driver assignments and trigger reassignNextDriver', async () => {
    const mockExpired = [
      {
        id: 'assignment-1',
        order_id: 'order-100',
        driver_id: 'driver-555',
        sequence_number: 1,
        status: 'notified',
        notified_at: new Date(Date.now() - 5 * 60 * 1000), // 5 minutes ago
      },
    ];

    mockPrisma.driver_assignments.findMany.mockResolvedValue(mockExpired as any);
    mockPrisma.driver_assignments.update.mockResolvedValue({
      ...mockExpired[0],
      status: 'expired',
    } as any);

    (dispatchService.reassignNextDriver as jest.Mock).mockResolvedValue(null);

    const count = await worker.processExpiredAssignments();

    expect(count).toBe(1);
    expect(mockPrisma.driver_assignments.update).toHaveBeenCalledWith({
      where: { id: 'assignment-1' },
      data: { status: 'expired', responded_at: expect.any(Date) },
    });
    expect(dispatchService.reassignNextDriver).toHaveBeenCalledWith('order-100');
  });

  it('should start and stop timer loop without throwing errors', () => {
    worker.start(500);
    expect(() => worker.stop()).not.toThrow();
  });
});
