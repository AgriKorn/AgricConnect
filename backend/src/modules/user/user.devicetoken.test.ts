import { mockDeep, DeepMockProxy } from 'jest-mock-extended';
import { PrismaClient } from '../../generated/prisma/client';

jest.mock('../../config/db', () => ({
  prisma: mockDeep<PrismaClient>(),
}));

import request from 'supertest';
import jwt from 'jsonwebtoken';
import app from '../../app';
import { prisma } from '../../config/db';
import { userRepository } from './user.repository.prisma';

/**
 * Prisma is mocked rather than pointed at a live database: CI runs no Postgres
 * service, and an integration suite that quietly needs one fails for reasons
 * that have nothing to do with the code under test.
 */
describe('Multi-Device Token Registration & Removal Integration Tests', () => {
  const userId = '11111111-1111-1111-1111-111111111111';
  let userToken: string;
  let mockPrisma: DeepMockProxy<PrismaClient>;

  beforeEach(() => {
    jest.clearAllMocks();
    mockPrisma = prisma as unknown as DeepMockProxy<PrismaClient>;

    userToken = jwt.sign(
      { userId, phone: '+233540000111', role: 'farmer', status: 'ACTIVE' },
      process.env.JWT_SECRET || 'agriconnect_super_secret_jwt_key_2026_min_16',
    );

    // The controller re-reads the user after writing the token.
    mockPrisma.user.findUnique.mockResolvedValue({
      id: userId,
      full_name: 'Farmer Joe',
      phone_number: '+233540000111',
      role: 'farmer',
      account_status: 'active',
      created_at: new Date(),
      updated_at: new Date(),
    } as any);
  });

  it('should register multi-device token (phone + tablet) without overwriting', async () => {
    mockPrisma.user_device_tokens.upsert.mockResolvedValue({} as any);

    const res1 = await request(app)
      .post('/api/users/device-token')
      .set('Authorization', `Bearer ${userToken}`)
      .send({ fcmToken: 'fcm_phone_token_123', platform: 'android', deviceId: 'phone_01' });

    expect(res1.status).toBe(200);

    const res2 = await request(app)
      .post('/api/users/device-token')
      .set('Authorization', `Bearer ${userToken}`)
      .send({ fcmToken: 'fcm_tablet_token_456', platform: 'ios', deviceId: 'tablet_02' });

    expect(res2.status).toBe(200);

    // Upserted by token, not by user — that is what keeps a second device from
    // displacing the first rather than sitting alongside it.
    expect(mockPrisma.user_device_tokens.upsert).toHaveBeenCalledTimes(2);
    expect(mockPrisma.user_device_tokens.upsert).toHaveBeenNthCalledWith(
      1,
      expect.objectContaining({
        where: { token: 'fcm_phone_token_123' },
        create: expect.objectContaining({ user_id: userId, token: 'fcm_phone_token_123', platform: 'android', device_id: 'phone_01', is_active: true }),
      }),
    );
    expect(mockPrisma.user_device_tokens.upsert).toHaveBeenNthCalledWith(
      2,
      expect.objectContaining({
        where: { token: 'fcm_tablet_token_456' },
        create: expect.objectContaining({ user_id: userId, token: 'fcm_tablet_token_456', platform: 'ios', device_id: 'tablet_02', is_active: true }),
      }),
    );
  });

  it('should report both tokens as active for the user', async () => {
    mockPrisma.user_device_tokens.findMany.mockResolvedValue([
      { token: 'fcm_phone_token_123' },
      { token: 'fcm_tablet_token_456' },
    ] as any);

    const activeTokens = await userRepository.findActiveDeviceTokens(userId);

    expect(mockPrisma.user_device_tokens.findMany).toHaveBeenCalledWith({
      where: { user_id: userId, is_active: true },
      select: { token: true },
    });
    expect(activeTokens).toContain('fcm_phone_token_123');
    expect(activeTokens).toContain('fcm_tablet_token_456');
  });

  it('should deactivate token when DELETE /api/users/device-token is called', async () => {
    mockPrisma.user_device_tokens.updateMany.mockResolvedValue({ count: 1 } as any);

    const res = await request(app)
      .delete('/api/users/device-token')
      .set('Authorization', `Bearer ${userToken}`)
      .send({ fcmToken: 'fcm_logout_token_789' });

    expect(res.status).toBe(200);

    // Deactivated, not deleted — the row is kept so the token's history survives.
    expect(mockPrisma.user_device_tokens.updateMany).toHaveBeenCalledWith({
      where: { user_id: userId, token: 'fcm_logout_token_789' },
      data: { is_active: false, updated_at: expect.any(Date) },
    });
  });

  it('should scope deactivation to the caller so one user cannot revoke another\'s token', async () => {
    mockPrisma.user_device_tokens.updateMany.mockResolvedValue({ count: 0 } as any);

    await request(app)
      .delete('/api/users/device-token')
      .set('Authorization', `Bearer ${userToken}`)
      .send({ fcmToken: 'someone_elses_token' });

    expect(mockPrisma.user_device_tokens.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: expect.objectContaining({ user_id: userId }) }),
    );
  });
});
