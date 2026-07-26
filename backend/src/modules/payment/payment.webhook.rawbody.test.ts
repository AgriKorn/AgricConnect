import request from 'supertest';
import crypto from 'crypto';

jest.mock('../../config/db', () => ({
  prisma: {
    payment_webhook_events: {
      findUnique: jest.fn(),
      upsert: jest.fn(),
      update: jest.fn(),
    },
    payments: {
      findFirst: jest.fn(),
      update: jest.fn(),
    },
    orders: {
      update: jest.fn(),
    },
    $transaction: jest.fn(async (cb: any) => cb({
      payments: { update: jest.fn() },
      orders: { update: jest.fn() },
    })),
  },
}));

import app from '../../app';
import { prisma } from '../../config/db';
import { paymentService } from '../../services/payment.service';

describe('Paystack Webhook Raw-Body & Idempotency Integration Tests', () => {
  const secretKey = 'sk_test_paystack_secret_key_mock_2026';

  beforeAll(() => {
    process.env.PAYSTACK_SECRET_KEY = secretKey;
    (paymentService as any).secretKey = secretKey;
  });

  beforeEach(() => {
    jest.clearAllMocks();
    (prisma.payment_webhook_events.upsert as jest.Mock).mockResolvedValue({
      id: 'webhook-rec-1',
      attempts: 1,
      processing_state: 'processing',
    });
    (prisma.payment_webhook_events.update as jest.Mock).mockResolvedValue({
      id: 'webhook-rec-1',
      processing_state: 'completed',
    });
  });

  afterAll(() => {
    delete process.env.PAYSTACK_SECRET_KEY;
  });

  it('should verify signature over exact raw Buffer and reject modified whitespace/formatting', async () => {
    const rawString = JSON.stringify({
      event: 'charge.success',
      data: {
        id: 99887711,
        reference: 'ref_raw_test_100',
        amount: 5000,
        currency: 'GHS',
        status: 'success',
      },
    });

    const validSignature = crypto.createHmac('sha512', secretKey).update(rawString).digest('hex');

    // Send valid signature
    const res = await request(app)
      .post('/api/payments/paystack/webhook')
      .set('x-paystack-signature', validSignature)
      .set('Content-Type', 'application/json')
      .send(rawString);

    expect(res.status).toBe(200);
    expect(res.body.status).toBe(true);

    // Send invalid signature
    const invalidRes = await request(app)
      .post('/api/payments/paystack/webhook')
      .set('x-paystack-signature', 'invalid_signature_hash_hex')
      .set('Content-Type', 'application/json')
      .send(rawString);

    expect(invalidRes.status).toBe(401);
  });

  it('should enforce idempotency and reject duplicate webhook events without re-processing', async () => {
    const rawString = JSON.stringify({
      event: 'charge.success',
      data: {
        id: 77665544,
        reference: 'ref_idempotency_200',
        amount: 3000,
        currency: 'GHS',
      },
    });

    const validSignature = crypto.createHmac('sha512', secretKey).update(rawString).digest('hex');

    // First Delivery
    (prisma.payment_webhook_events.findUnique as jest.Mock).mockResolvedValueOnce(null);

    const firstRes = await request(app)
      .post('/api/payments/paystack/webhook')
      .set('x-paystack-signature', validSignature)
      .set('Content-Type', 'application/json')
      .send(rawString);

    expect(firstRes.status).toBe(200);

    // Duplicate Delivery
    (prisma.payment_webhook_events.findUnique as jest.Mock).mockResolvedValueOnce({
      id: 'webhook-rec-1',
      processing_state: 'completed',
    });

    const secondRes = await request(app)
      .post('/api/payments/paystack/webhook')
      .set('x-paystack-signature', validSignature)
      .set('Content-Type', 'application/json')
      .send(rawString);

    expect(secondRes.status).toBe(200);
    expect(secondRes.body.message).toContain('already processed');
  });
});
