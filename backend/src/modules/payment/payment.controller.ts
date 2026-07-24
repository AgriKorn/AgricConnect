import { Request, Response, NextFunction } from 'express';
import { paymentService } from '../../services/payment.service';
import { BadRequestError, UnauthorizedError } from '../../utils/errors';
import { sendSuccess } from '../../utils/response';
import { prisma } from '../../config/db';
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
    const rawBody = (req as any).rawBody;

    if (!signature || !rawBody) {
      logger.warn('[Paystack Webhook] Missing signature or unparsed raw body buffer');
      throw new UnauthorizedError('Invalid webhook request');
    }

    if (!paymentService.verifyWebhookSignature(signature, rawBody)) {
      logger.warn('[Paystack Webhook] Invalid HMAC SHA-512 signature detected');
      throw new UnauthorizedError('Invalid webhook signature');
    }

    const event = req.body;
    const eventData = event.data || {};
    const eventType = event.event || 'unknown';
    const reference = eventData.reference || eventData.transfer_code || null;

    // Generate deterministic event key for idempotency
    const eventKey = eventData.id ? `paystack_${eventData.id}` : `paystack_${eventType}_${reference || Date.now()}`;

    // 1. Idempotency Check & Processing Reservation
    const existing = await prisma.payment_webhook_events.findUnique({
      where: { event_key: eventKey },
    });

    if (existing && existing.processing_state === 'completed') {
      logger.info(`[Paystack Webhook Idempotency] Skipping already processed event ${eventKey}`);
      return res.status(200).json({ status: true, message: 'Event already processed' });
    }

    const webhookRecord = await prisma.payment_webhook_events.upsert({
      where: { event_key: eventKey },
      update: {
        attempts: { increment: 1 },
        processing_state: 'processing',
        updated_at: new Date(),
      },
      create: {
        provider: 'paystack',
        event_key: eventKey,
        event_type: eventType,
        reference,
        payload: event,
        processing_state: 'processing',
        attempts: 1,
      },
    });

    // 2. Business Event Processing
    try {
      if (eventType === 'charge.success') {
        const amountGhs = (eventData.amount || 0) / 100;
        const currency = eventData.currency || 'GHS';

        if (currency !== 'GHS') {
          throw new Error(`Invalid currency ${currency}. Expected GHS.`);
        }

        // Find payment by reference or order
        const payment = await prisma.payments.findFirst({
          where: {
            OR: [
              { provider_reference: reference },
              { id: reference },
            ],
          },
          include: { orders: true },
        });

        if (payment) {
          const expectedAmount = Number(payment.amount);
          if (Math.abs(expectedAmount - amountGhs) > 0.01) {
            throw new Error(`Amount mismatch: Paystack GHS ${amountGhs} vs Expected GHS ${expectedAmount}`);
          }

          // Atomic status update
          await prisma.$transaction(async (tx) => {
            await tx.payments.update({
              where: { id: payment.id },
              data: {
                status: 'held',
                provider_reference: reference,
                held_at: new Date(),
              },
            });

            await tx.orders.update({
              where: { id: payment.order_id },
              data: { order_status: 'awaiting_driver' },
            });
          });

          logger.info(`[Paystack Webhook] Confirmed held escrow payment for Order #${payment.order_id}`);
        }
      }

      // Mark Webhook Event as Completed
      await prisma.payment_webhook_events.update({
        where: { id: webhookRecord.id },
        data: {
          processing_state: 'completed',
          processed_at: new Date(),
        },
      });

      return res.status(200).json({ status: true, message: 'Webhook event processed' });
    } catch (procError: any) {
      logger.error(`[Paystack Webhook Processing Error] ${eventKey}:`, procError);
      await prisma.payment_webhook_events.update({
        where: { id: webhookRecord.id },
        data: {
          processing_state: 'failed',
          last_error: procError.message || String(procError),
        },
      });
      return res.status(500).json({ status: false, message: 'Webhook processing error' });
    }
  } catch (err) {
    return next(err);
  }
};
