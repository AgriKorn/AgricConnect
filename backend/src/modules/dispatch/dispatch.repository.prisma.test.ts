import { mockDeep, DeepMockProxy } from 'jest-mock-extended';
import { PrismaClient } from '../../generated/prisma/client';

jest.mock('../../config/db', () => ({
  prisma: mockDeep<PrismaClient>(),
}));

import { prisma } from '../../config/db';
import { PrismaDispatchRepository } from './dispatch.repository.prisma';

/**
 * assignment_status (the DB enum) has no distinct "completed" value, so
 * ACCEPTED and COMPLETED both persist as 'accepted' — telling them apart (and
 * building the right `where` clause to filter by one or the other) requires
 * the linked order's order_status too. This was previously collapsed into a
 * single enum switch that mapped both to the same Prisma value and had no
 * case for DECLINED at all (it silently fell back to 'notified'/PENDING).
 */
describe('PrismaDispatchRepository', () => {
  let mockPrisma: DeepMockProxy<PrismaClient>;
  let repo: PrismaDispatchRepository;

  const whereClause = () => (mockPrisma.driver_assignments.findMany.mock.calls[0][0] as any).where;

  const baseRow = (overrides: Record<string, unknown> = {}) => ({
    id: 'assignment-1',
    order_id: 'order-1',
    driver_id: 'driver-1',
    status: 'accepted',
    notified_at: new Date(),
    responded_at: null,
    orders: {
      listing_id: 'listing-1',
      amount: 100,
      order_status: 'in_transit',
      users: { full_name: 'Buyer Name', phone_number: '+233200000001', region: 'Greater Accra' },
      produce_listings: {
        quantity_kg: 20,
        region: 'Ashanti',
        crop_types: { name: 'maize' },
        users: { full_name: 'Farmer Name', phone_number: '+233200000002' },
      },
    },
    ...overrides,
  });

  beforeEach(() => {
    jest.clearAllMocks();
    mockPrisma = prisma as unknown as DeepMockProxy<PrismaClient>;
    mockPrisma.driver_assignments.findMany.mockResolvedValue([] as any);
    repo = new PrismaDispatchRepository();
  });

  describe('findJobsForDriver — query construction', () => {
    it('should filter PENDING to notified assignments only', async () => {
      await repo.findJobsForDriver('driver-1', 'PENDING');
      expect(whereClause()).toEqual({ driver_id: 'driver-1', status: 'notified' });
    });

    it('should filter ACCEPTED to accepted assignments whose order is not yet completed', async () => {
      await repo.findJobsForDriver('driver-1', 'ACCEPTED');
      expect(whereClause()).toEqual({
        driver_id: 'driver-1',
        status: 'accepted',
        orders: { order_status: { not: 'completed' } },
      });
    });

    it('should filter COMPLETED to accepted assignments whose order is completed', async () => {
      await repo.findJobsForDriver('driver-1', 'COMPLETED');
      expect(whereClause()).toEqual({
        driver_id: 'driver-1',
        status: 'accepted',
        orders: { order_status: 'completed' },
      });
    });

    it('should fold expired offers into DECLINED, not leave them invisible to filtering', async () => {
      await repo.findJobsForDriver('driver-1', 'DECLINED');
      expect(whereClause()).toEqual({ driver_id: 'driver-1', status: { in: ['declined', 'expired'] } });
    });

    it('should not constrain status when none is requested', async () => {
      await repo.findJobsForDriver('driver-1');
      expect(whereClause()).toEqual({ driver_id: 'driver-1' });
    });
  });

  describe('status mapping on read', () => {
    it('should report an accepted assignment on a not-yet-completed order as ACCEPTED', async () => {
      mockPrisma.driver_assignments.findMany.mockResolvedValue([baseRow()] as any);
      const [job] = await repo.findJobsForDriver('driver-1');
      expect(job.status).toBe('ACCEPTED');
    });

    it('should report an accepted assignment on a completed order as COMPLETED, not ACCEPTED', async () => {
      mockPrisma.driver_assignments.findMany.mockResolvedValue([
        baseRow({ orders: { ...baseRow().orders, order_status: 'completed' } }),
      ] as any);
      const [job] = await repo.findJobsForDriver('driver-1');
      expect(job.status).toBe('COMPLETED');
    });

    it('should report a notified assignment as PENDING', async () => {
      mockPrisma.driver_assignments.findMany.mockResolvedValue([baseRow({ status: 'notified' })] as any);
      const [job] = await repo.findJobsForDriver('driver-1');
      expect(job.status).toBe('PENDING');
    });

    it('should report a declined assignment as DECLINED', async () => {
      mockPrisma.driver_assignments.findMany.mockResolvedValue([baseRow({ status: 'declined' })] as any);
      const [job] = await repo.findJobsForDriver('driver-1');
      expect(job.status).toBe('DECLINED');
    });

    it('should report an expired (timed-out) assignment as DECLINED, not PENDING', async () => {
      mockPrisma.driver_assignments.findMany.mockResolvedValue([baseRow({ status: 'expired' })] as any);
      const [job] = await repo.findJobsForDriver('driver-1');
      expect(job.status).toBe('DECLINED');
    });
  });

  describe('update — writing DECLINED', () => {
    it('should persist a decline as the declined enum value, not silently as notified/PENDING', async () => {
      mockPrisma.driver_assignments.update.mockResolvedValue(baseRow({ status: 'declined' }) as any);
      await repo.update('assignment-1', 'DECLINED');
      const call = mockPrisma.driver_assignments.update.mock.calls[0][0] as any;
      expect(call.data.status).toBe('declined');
    });
  });
});
