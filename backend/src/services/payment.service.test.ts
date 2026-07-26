import axios from 'axios';
import { PaystackPaymentService } from './payment.service';

jest.mock('axios');
const mockedAxios = axios as jest.Mocked<typeof axios>;

describe('PaystackPaymentService', () => {
  let paymentService: PaystackPaymentService;

  beforeEach(() => {
    jest.clearAllMocks();
    paymentService = new PaystackPaymentService();
  });

  describe('Stub Fallback Operations (Local Dev)', () => {
    it('should initialize transaction returning stub reference and authorizationUrl', async () => {
      const result = await paymentService.initializeTransaction(150, '+233541234567', { listingId: 'l-1' });
      expect(result.reference).toContain('stub_');
      expect(result.authorizationUrl).toContain('stub-paystack.local');
    });

    it('should initiate transfer returning stub transferCode and success status', async () => {
      const result = await paymentService.initiateTransfer('+233541234567', 150, 'Escrow Payout');
      expect(result.transferCode).toContain('stub_transfer_');
      expect(result.status).toBe('success');
    });

    it('should resolve MoMo account returning stub holder name', async () => {
      const result = await paymentService.resolveMomoAccount('0541234567', 'MTN');
      expect(result.accountNumber).toBe('0541234567');
      expect(result.accountName).toContain('Kwame Mensah');
      expect(result.bankCode).toBe('MTN');
    });

    it('should verify webhook signature returning true in stub mode', () => {
      const valid = paymentService.verifyWebhookSignature('sig', 'body');
      expect(valid).toBe(true);
    });
  });

  describe('Live Paystack API Calls (Configured Key)', () => {
    let liveService: PaystackPaymentService;

    beforeEach(() => {
      process.env.PAYSTACK_SECRET_KEY = 'sk_test_mock_key';
      liveService = new PaystackPaymentService();
    });

    afterEach(() => {
      delete process.env.PAYSTACK_SECRET_KEY;
    });

    it('should initialize transaction via Paystack REST API', async () => {
      mockedAxios.post.mockResolvedValueOnce({
        data: {
          data: {
            reference: 'ps_ref_100',
            authorization_url: 'https://checkout.paystack.com/ps_ref_100',
          },
        },
      } as any);

      const res = await liveService.initializeTransaction(200, '+233541234567');
      expect(res.reference).toBe('ps_ref_100');
      expect(res.authorizationUrl).toBe('https://checkout.paystack.com/ps_ref_100');
      expect(mockedAxios.post).toHaveBeenCalledWith(
        'https://api.paystack.co/transaction/initialize',
        expect.objectContaining({ amount: 20000, currency: 'GHS' }),
        expect.any(Object),
      );
    });

    it('should initiate transfer via Paystack REST API', async () => {
      mockedAxios.post
        .mockResolvedValueOnce({ data: { data: { recipient_code: 'RCP_123' } } } as any)
        .mockResolvedValueOnce({ data: { data: { transfer_code: 'TRF_456', status: 'success' } } } as any);

      const res = await liveService.initiateTransfer('+233541234567', 100, 'Escrow payout');
      expect(res.transferCode).toBe('TRF_456');
      expect(res.status).toBe('success');
    });

    it('should resolve MoMo account via Paystack REST API', async () => {
      mockedAxios.get.mockResolvedValueOnce({
        data: {
          data: {
            account_number: '0541234567',
            account_name: 'Ama Kofi',
          },
        },
      } as any);

      const res = await liveService.resolveMomoAccount('0541234567', 'MTN');
      expect(res.accountName).toBe('Ama Kofi');
      expect(res.accountNumber).toBe('0541234567');
    });

    it('should verify valid HMAC SHA-512 webhook signature', () => {
      const secret = 'sk_test_mock_key';
      const body = '{"event":"charge.success"}';
      const crypto = require('crypto');
      const validSig = crypto.createHmac('sha512', secret).update(body).digest('hex');

      const isValid = liveService.verifyWebhookSignature(validSig, body);
      expect(isValid).toBe(true);
    });

    it('should handle API errors cleanly', async () => {
      mockedAxios.post.mockRejectedValueOnce(new Error('Network error'));
      await expect(liveService.initializeTransaction(100, 'phone')).rejects.toThrow('Payment initialization failed with Paystack API');
    });
  });
});
