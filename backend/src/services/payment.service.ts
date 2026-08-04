import { randomUUID, createHmac, timingSafeEqual } from 'crypto';
import axios from 'axios';
import logger from '../utils/logger';
import { BadRequestError } from '../utils/errors';

/**
 * Every stored momoNumber is normalized to +233XXXXXXXXX on save (see
 * normalizePhone in auth.schema.ts), but Paystack's Ghana mobile-money
 * transfer-recipient API rejects that format outright with "Account number
 * is invalid" — it wants the local 0XXXXXXXXX form. Without this, every
 * escrow payout to a farmer fails at the final step, every time.
 */
const toLocalGhanaPhone = (phone: string): string => {
  if (phone.startsWith('+233')) return `0${phone.slice(4)}`;
  if (phone.startsWith('233')) return `0${phone.slice(3)}`;
  return phone;
};

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

export interface RefundResult {
  refundReference: string;
  status: 'pending' | 'processed';
}

export interface IPaymentService {
  initializeTransaction(amountGhs: number, payerPhone: string, metadata: Record<string, unknown>): Promise<InitializeTransactionResult>;
  initiateTransfer(recipientPhone: string, amountGhs: number, reason: string, bankCode: string): Promise<TransferResult>;
  resolveMomoAccount(accountNumber: string, bankCode: string): Promise<ResolveMomoResult>;
  /** Reverses a held/captured charge via Paystack's refund API — used when a dispute is resolved in the buyer's favor. */
  refundTransaction(paymentReference: string, amountGhs: number): Promise<RefundResult>;
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
          account_number: toLocalGhanaPhone(recipientPhone),
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
      // Unlike refundTransaction/resolveMomoAccount below, this threw a bare
      // Error — which the global handler reports as an opaque 500 "unexpected
      // error occurred", hiding the real reason (bad bank code, farmer's momo
      // number rejected, insufficient platform balance, ...) from both the
      // buyer confirming delivery and whoever has to debug it afterward.
      const paystackMessage = error?.response?.data?.message;
      throw new BadRequestError(paystackMessage || 'Payout transfer failed with Paystack API');
    }
  }

  async refundTransaction(paymentReference: string, amountGhs: number): Promise<RefundResult> {
    if (!this.secretKey) {
      const refundReference = `stub_refund_${randomUUID()}`;
      logger.info(`[Payment Stub] Refunded GHS ${amountGhs.toFixed(2)} for ${paymentReference} — reference ${refundReference}`);
      return { refundReference, status: 'processed' };
    }

    try {
      const response = await axios.post(
        `${this.baseUrl}/refund`,
        {
          transaction: paymentReference,
          amount: Math.round(amountGhs * 100), // Convert GHS to Pesewas
        },
        { headers: { Authorization: `Bearer ${this.secretKey}` } },
      );

      const data = response.data.data;
      return {
        refundReference: data.id?.toString() ?? paymentReference,
        status: data.status === 'processed' ? 'processed' : 'pending',
      };
    } catch (error: any) {
      logger.error('[Paystack Refund Error]:', error?.response?.data || error.message);
      const paystackMessage = error?.response?.data?.message;
      throw new BadRequestError(paystackMessage || 'Could not process refund with Paystack');
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
