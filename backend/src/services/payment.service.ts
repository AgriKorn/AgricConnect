import { randomUUID, createHmac, timingSafeEqual } from 'crypto';
import axios from 'axios';
import logger from '../utils/logger';
import { BadRequestError } from '../utils/errors';

export interface InitializeTransactionResult {
  reference: string;
  authorizationUrl: string;
}

export interface TransferResult {
  transferCode: string;
  status: 'success' | 'pending';
}

export interface ResolveMomoResult {
  accountNumber: string;
  accountName: string;
  bankCode: string;
}

export interface IPaymentService {
  initializeTransaction(amountGhs: number, payerPhone: string, metadata: Record<string, unknown>): Promise<InitializeTransactionResult>;
  initiateTransfer(recipientPhone: string, amountGhs: number, reason: string, bankCode: string): Promise<TransferResult>;
  resolveMomoAccount(accountNumber: string, bankCode: string): Promise<ResolveMomoResult>;
  verifyWebhookSignature(signature: string, rawBody: string | Buffer): boolean;
}

export class PaystackPaymentService implements IPaymentService {
  private secretKey: string;
  private baseUrl = 'https://api.paystack.co';

  constructor() {
    this.secretKey = process.env.PAYSTACK_SECRET_KEY || '';
  }

  async initializeTransaction(
    amountGhs: number,
    payerPhone: string,
    metadata: Record<string, unknown> = {},
  ): Promise<InitializeTransactionResult> {
    if (!this.secretKey) {
      const reference = `stub_${randomUUID()}`;
      logger.info(`[Payment Stub] Held GHS ${amountGhs.toFixed(2)} from ${payerPhone} — reference ${reference}`);
      return { reference, authorizationUrl: `https://stub-paystack.local/pay/${reference}` };
    }

    try {
      const response = await axios.post(
        `${this.baseUrl}/transaction/initialize`,
        {
          email: `${payerPhone.replace('+', '')}@agriconnect.org`,
          amount: Math.round(amountGhs * 100), // Convert GHS to Pesewas
          currency: 'GHS',
          channels: ['mobile_money'],
          metadata,
        },
        {
          headers: { Authorization: `Bearer ${this.secretKey}` },
        },
      );

      const { reference, authorization_url } = response.data.data;
      return { reference, authorizationUrl: authorization_url };
    } catch (error: any) {
      logger.error('[Paystack Error] Failed to initialize transaction:', error?.response?.data || error.message);
      throw new Error('Payment initialization failed with Paystack API');
    }
  }

  async initiateTransfer(recipientPhone: string, amountGhs: number, reason: string, bankCode: string): Promise<TransferResult> {
    if (!this.secretKey) {
      const transferCode = `stub_transfer_${randomUUID()}`;
      logger.info(`[Payment Stub] Released GHS ${amountGhs.toFixed(2)} to ${recipientPhone} (${reason}) — ${transferCode}`);
      return { transferCode, status: 'success' };
    }

    try {
      // Step 1: Create Transfer Recipient
      const recipientRes = await axios.post(
        `${this.baseUrl}/transferrecipient`,
        {
          type: 'mobile_money',
          name: `Recipient ${recipientPhone}`,
          account_number: recipientPhone,
          bank_code: bankCode,
          currency: 'GHS',
        },
        { headers: { Authorization: `Bearer ${this.secretKey}` } },
      );

      const recipientCode = recipientRes.data.data.recipient_code;

      // Step 2: Initiate Transfer
      const transferRes = await axios.post(
        `${this.baseUrl}/transfer`,
        {
          source: 'balance',
          amount: Math.round(amountGhs * 100),
          recipient: recipientCode,
          reason,
          currency: 'GHS',
        },
        { headers: { Authorization: `Bearer ${this.secretKey}` } },
      );

      return {
        transferCode: transferRes.data.data.transfer_code,
        status: transferRes.data.data.status === 'success' ? 'success' : 'pending',
      };
    } catch (error: any) {
      logger.error('[Paystack Transfer Error]:', error?.response?.data || error.message);
      throw new Error('Payout transfer failed with Paystack API');
    }
  }

  async resolveMomoAccount(accountNumber: string, bankCode = 'MTN'): Promise<ResolveMomoResult> {
    if (!this.secretKey) {
      return {
        accountNumber,
        accountName: 'Kwame Mensah (Stub MoMo Account)',
        bankCode,
      };
    }

    try {
      const response = await axios.get(
        `${this.baseUrl}/bank/resolve?account_number=${encodeURIComponent(accountNumber)}&bank_code=${encodeURIComponent(bankCode)}`,
        { headers: { Authorization: `Bearer ${this.secretKey}` } },
      );

      const data = response.data.data;
      return {
        accountNumber: data.account_number,
        accountName: data.account_name,
        bankCode,
      };
    } catch (error: any) {
      logger.error('[Paystack Resolve MoMo Error]:', error?.response?.data || error.message);
      // Surface Paystack's own reason (invalid account, wrong bank code, test-mode
      // rate limit, etc.) as a proper 400 instead of an opaque 500 — the caller
      // can act on "wrong bank code" or "try again later" but not on a generic
      // "Internal Server Error".
      const paystackMessage = error?.response?.data?.message;
      throw new BadRequestError(paystackMessage || 'Could not verify Mobile Money account holder with Paystack');
    }
  }

  verifyWebhookSignature(signature: string, rawBody: Buffer | string): boolean {
    const activeSecretKey = process.env.PAYSTACK_SECRET_KEY || this.secretKey;
    if (!signature || !rawBody) return false;
    if (!activeSecretKey) {
      // In dev mode without secret key configured, bypass signature check
      return true;
    }

    const computedHash = createHmac('sha512', activeSecretKey).update(rawBody).digest('hex');
    const sigBuffer = Buffer.from(signature, 'utf8');
    const compBuffer = Buffer.from(computedHash, 'utf8');

    if (sigBuffer.length !== compBuffer.length) {
      return false;
    }

    return timingSafeEqual(sigBuffer, compBuffer);
  }
}

export const paymentService = new PaystackPaymentService();
