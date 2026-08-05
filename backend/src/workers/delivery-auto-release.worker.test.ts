import { mockDeep, DeepMockProxy } from 'jest-mock-extended';
import { PrismaClient } from '../generated/prisma/client';

jest.mock('../config/db', () => ({
  prisma: mockDeep<PrismaClient>(),
}));

import { prisma } from '../config/db';
import { DeliveryAutoReleaseWorker } from './delivery-auto-release.worker';
import { transactionService } from '../modules/transaction/transaction.service';

jest.mock('../modules/transaction/transaction.service', () => ({
  transactionService: {
    autoReleaseIfExpired: jest.fn(),
  },
}));

describe('DeliveryAutoReleaseWorker', () => {
  let worker: DeliveryAutoReleaseWorker;
  let mockPrisma: DeepMockProxy<PrismaClient>;

  beforeEach(() => {
    jest.clearAllMocks();
    mockPrisma = prisma as unknown as DeepMockProxy<PrismaClient>;
    worker = new DeliveryAutoReleaseWorker();
  });

  afterEach(() => {
    worker.stop();
  });

  it('should query for delivered_pending_confirmation orders past their expiry and auto-release each', async () => {
    mockPrisma.orders.findMany.mockResolvedValue([{ id: 'order-1' }, { id: 'order-2' }] as any);
    (transactionService.autoReleaseIfExpired as jest.Mock).mockResolvedValue({ id: 'order-1', status: 'RELEASED' });

    const count = await worker.processExpiredConfirmations();

    expect(mockPrisma.orders.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { order_status: 'delivered_pending_confirmation', delivery_code_expires_at: { lte: expect.any(Date) } },
      }),
    );
    expect(transactionService.autoReleaseIfExpired).toHaveBeenCalledWith('order-1');
    expect(transactionService.autoReleaseIfExpired).toHaveBeenCalledWith('order-2');
    expect(count).toBe(2);
  });

  it('should not count an order the service declined to release (e.g. it was confirmed moments before the sweep)', async () => {
    mockPrisma.orders.findMany.mockResolvedValue([{ id: 'order-1' }] as any);
    (transactionService.autoReleaseIfExpired as jest.Mock).mockResolvedValue(null);

    const count = await worker.processExpiredConfirmations();

    expect(count).toBe(0);
  });

  it('should continue processing remaining orders if one fails', async () => {
    mockPrisma.orders.findMany.mockResolvedValue([{ id: 'order-1' }, { id: 'order-2' }] as any);
    (transactionService.autoReleaseIfExpired as jest.Mock)
      .mockRejectedValueOnce(new Error('Payout failed'))
      .mockResolvedValueOnce({ id: 'order-2', status: 'RELEASED' });

    const count = await worker.processExpiredConfirmations();

    expect(count).toBe(1);
  });

  it('should start and stop timer loop without throwing errors', () => {
    worker.start(500);
    expect(() => worker.stop()).not.toThrow();
  });
});
