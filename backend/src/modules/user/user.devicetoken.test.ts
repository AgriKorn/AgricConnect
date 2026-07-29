import request from 'supertest';
import jwt from 'jsonwebtoken';
import app from '../../app';
import { userRepository } from './user.repository.prisma';

jest.setTimeout(20000);

describe('Multi-Device Token Registration & Removal Integration Tests', () => {
  let userId: string;
  let userToken: string;

  beforeEach(async () => {
    // Unique phone per run: this suite hits the real database (no test-DB
    // isolation in this project), so a fixed phone collides on rerun.
    const uniquePhone = `+2335${Math.floor(10000000 + Math.random() * 89999999)}`;
    const user = await userRepository.create({
      name: 'Farmer Joe',
      phone: uniquePhone,
      passwordHash: 'hashed_pwd',
      role: 'farmer',
      otp: '123456',
      otpExpiry: new Date(Date.now() + 600000),
    });
    userId = user.id;
    userToken = jwt.sign(
      { userId, phone: user.phone, role: user.role, status: 'ACTIVE' },
      process.env.JWT_SECRET || 'agriconnect_super_secret_jwt_key_2026_min_16',
    );
  });

  it('should register multi-device token (phone + tablet) without overwriting', async () => {
    // 1. Register Phone Token
    const res1 = await request(app)
      .post('/api/users/device-token')
      .set('Authorization', `Bearer ${userToken}`)
      .send({ fcmToken: 'fcm_phone_token_123', platform: 'android', deviceId: 'phone_01' });

    expect(res1.status).toBe(200);

    // 2. Register Tablet Token
    const res2 = await request(app)
      .post('/api/users/device-token')
      .set('Authorization', `Bearer ${userToken}`)
      .send({ fcmToken: 'fcm_tablet_token_456', platform: 'ios', deviceId: 'tablet_02' });

    expect(res2.status).toBe(200);

    // Verify both tokens are active for user
    const activeTokens = await userRepository.findActiveDeviceTokens(userId);
    expect(activeTokens).toContain('fcm_phone_token_123');
    expect(activeTokens).toContain('fcm_tablet_token_456');
  });

  it('should deactivate token when DELETE /api/users/device-token is called', async () => {
    await userRepository.registerDeviceToken(userId, 'fcm_logout_token_789', 'android', 'phone_01');

    const res = await request(app)
      .delete('/api/users/device-token')
      .set('Authorization', `Bearer ${userToken}`)
      .send({ fcmToken: 'fcm_logout_token_789' });

    expect(res.status).toBe(200);

    const activeTokens = await userRepository.findActiveDeviceTokens(userId);
    expect(activeTokens).not.toContain('fcm_logout_token_789');
  });
});
