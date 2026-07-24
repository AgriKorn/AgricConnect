import { Request, Response, NextFunction } from 'express';
import { paymentService } from '../../services/payment.service';
import { BadRequestError, UnauthorizedError } from '../../utils/errors';
import { sendSuccess } from '../../utils/response';
import logger from '../../utils/logger';

export const resolveMomoAccountHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { accountNumber, bankCode = 'MTN' } = req.query;
    if (!accountNumber || typeof accountNumber !== 'string') {
      throw new BadRequestError('accountNumber query parameter is required');
    }

    const resolved = await paymentService.resolveMomoAccount(accountNumber, String(bankCode));
    sendSuccess(res, resolved);
  } catch (err) {
    next(err);
  }
};

export const paystackWebhookHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const signature = req.headers['x-paystack-signature'] as string;
    const rawBody = (req as any).rawBody || JSON.stringify(req.body);

    if (!paymentService.verifyWebhookSignature(signature, rawBody)) {
      logger.warn('[Paystack Webhook] Invalid HMAC SHA-512 signature detected');
      throw new UnauthorizedError('Invalid webhook signature');
    }

    const event = req.body;
    logger.info(`[Paystack Webhook Received] Event: ${event.event}, Reference: ${event.data?.reference}`);

    switch (event.event) {
      case 'charge.success':
        logger.info(`[Paystack Webhook] Payment confirmed for reference ${event.data.reference}`);
        break;
      case 'transfer.success':
        logger.info(`[Paystack Webhook] Escrow payout transfer succeeded for code ${event.data.transfer_code}`);
        break;
      case 'transfer.failed':
        logger.error(`[Paystack Webhook] Escrow payout transfer failed for code ${event.data.transfer_code}`);
        break;
      default:
        logger.info(`[Paystack Webhook] Unhandled event type: ${event.event}`);
    }

    // Paystack requires 200 OK response
    res.status(200).json({ status: true, message: 'Webhook event processed' });
  } catch (err) {
    next(err);
  }
};
