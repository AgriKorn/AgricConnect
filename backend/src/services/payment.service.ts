import { randomUUID } from 'crypto';
import logger from '../utils/logger';

/**
 * Stand-in for the real Paystack-backed PaymentService (A5) — no Paystack
 * account exists yet. Swap the body of these methods for real API calls
 * once one does; everything that imports paymentService stays the same.
 */
export interface InitializeTransactionResult {
  reference: string;
  authorizationUrl: string;
}

export interface TransferResult {
  transferCode: string;
  status: 'success';
}

export interface IPaymentService {
  initializeTransaction(amountGhs: number, payerPhone: string, metadata: Record<string, unknown>): Promise<InitializeTransactionResult>;
  initiateTransfer(recipientPhone: string, amountGhs: number, reason: string): Promise<TransferResult>;
}

class StubPaymentService implements IPaymentService {
  async initializeTransaction(amountGhs: number, payerPhone: string): Promise<InitializeTransactionResult> {
    const reference = `stub_${randomUUID()}`;
    logger.info(`[payment-stub] Held GHS ${amountGhs.toFixed(2)} from ${payerPhone} — reference ${reference}`);
    return { reference, authorizationUrl: `https://stub-paystack.local/pay/${reference}` };
  }

  async initiateTransfer(recipientPhone: string, amountGhs: number, reason: string): Promise<TransferResult> {
    const transferCode = `stub_transfer_${randomUUID()}`;
    logger.info(`[payment-stub] Released GHS ${amountGhs.toFixed(2)} to ${recipientPhone} (${reason}) — ${transferCode}`);
    return { transferCode, status: 'success' };
  }
}

export const paymentService: IPaymentService = new StubPaymentService();
