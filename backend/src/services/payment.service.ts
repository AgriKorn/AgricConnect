import { randomUUID } from 'crypto';
import logger from '../utils/logger';

/**
 * Flexible payment service abstraction. Paystack integration is currently on hold.
 * Future payment gateways (e.g. Mobile Money direct, custom escrow) can implement
 * IPaymentService without breaking transaction routes.
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
