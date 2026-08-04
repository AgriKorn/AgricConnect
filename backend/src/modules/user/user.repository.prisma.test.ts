import { mockDeep, DeepMockProxy } from 'jest-mock-extended';
import { PrismaClient } from '../../generated/prisma/client';

jest.mock('../../config/db', () => ({
  prisma: mockDeep<PrismaClient>(),
}));

import { prisma } from '../../config/db';
import { PrismaUserRepository } from './user.repository.prisma';

/**
 * assignDriver() always takes candidates[0] — with no ordering, an unordered
 * findMany returns the same row first on every call, so the exact same
 * driver got every delivery offer forever and no one else ever received
 * one. This covers the fairness-rotation fix.
 */
describe('PrismaUserRepository.findAvailableDrivers', () => {
  let mockPrisma: DeepMockProxy<PrismaClient>;
  let repo: PrismaUserRepository;

  const driverRow = (id: string, overrides: Record<string, unknown> = {}) => ({
    id,
    phone_number: `+23320000${id}`,
    email: null,
    full_name: `Driver ${id}`,
    role: 'driver',
    region: 'Greater Accra',
    otp_verified: true,
    account_status: 'approved',
    approved_by: null,
    approved_at: null,
    fcm_token: null,
    momo_number: null,
    momo_network: null,
    business_name: null,
    business_type: null,
    photo_url: null,
    notification_prefs: null,
    password_hash: null,
    refresh_token: null,
    created_at: new Date(),
    updated_at: new Date(),
    driver_details: {
      user_id: id,
      truck_capacity_kg: { toString: () => '1000' } as any,
      operating_region: 'Greater Accra',
      availability_status: 'available',
      current_lat: null,
      current_lng: null,
      updated_at: new Date(),
    },
    ...overrides,
  });

  beforeEach(() => {
    jest.clearAllMocks();
    mockPrisma = prisma as unknown as DeepMockProxy<PrismaClient>;
    repo = new PrismaUserRepository();
  });

  it('should not call groupBy or reorder when there are 0 or 1 candidates', async () => {
    mockPrisma.user.findMany.mockResolvedValue([driverRow('a')] as any);

    const result = await repo.findAvailableDrivers(1, []);

    expect(result.map((d) => d.id)).toEqual(['a']);
    expect(mockPrisma.driver_assignments.groupBy).not.toHaveBeenCalled();
  });

  it('should put a driver who has never been offered a job ahead of one who has', async () => {
    mockPrisma.user.findMany.mockResolvedValue([driverRow('always-picked'), driverRow('never-picked')] as any);
    (mockPrisma.driver_assignments.groupBy as jest.Mock).mockResolvedValue([
      { driver_id: 'always-picked', _max: { notified_at: new Date('2026-08-04T10:00:00Z') } },
      // 'never-picked' has no groupBy row at all — no assignment history.
    ] as any);

    const result = await repo.findAvailableDrivers(1, []);

    expect(result.map((d) => d.id)).toEqual(['never-picked', 'always-picked']);
  });

  it('should order multiple previously-offered drivers by longest-idle first', async () => {
    mockPrisma.user.findMany.mockResolvedValue([driverRow('recent'), driverRow('stale')] as any);
    (mockPrisma.driver_assignments.groupBy as jest.Mock).mockResolvedValue([
      { driver_id: 'recent', _max: { notified_at: new Date('2026-08-04T12:00:00Z') } },
      { driver_id: 'stale', _max: { notified_at: new Date('2026-08-01T09:00:00Z') } },
    ] as any);

    const result = await repo.findAvailableDrivers(1, []);

    expect(result.map((d) => d.id)).toEqual(['stale', 'recent']);
  });

  it('should still apply the capacity/availability/exclude filters passed through to the query', async () => {
    mockPrisma.user.findMany.mockResolvedValue([] as any);

    await repo.findAvailableDrivers(500, ['excluded-1']);

    const call = mockPrisma.user.findMany.mock.calls[0][0] as any;
    expect(call.where.driver_details.truck_capacity_kg).toEqual({ gte: 500 });
    expect(call.where.driver_details.availability_status).toBe('available');
    expect(call.where.id).toEqual({ notIn: ['excluded-1'] });
  });
});
