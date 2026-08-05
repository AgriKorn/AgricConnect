import { prisma } from '../config/db';
import { transactionService } from '../modules/transaction/transaction.service';
import logger from '../utils/logger';

/**
 * Sweeps driver-delivered orders whose confirmation window has passed with
 * no buyer scan and releases escrow anyway — protects the farmer from a
 * buyer who never gets around to confirming (or never can: lost phone,
 * camera issue, etc). Self-collect orders never enter
 * delivered_pending_confirmation so they're naturally excluded.
 */
export class DeliveryAutoReleaseWorker {
  private isRunning = false;
  private timer: NodeJS.Timeout | null = null;

  start(pollIntervalMs = 15 * 60 * 1000) {
    if (this.isRunning) return;
    this.isRunning = true;
    logger.info('[DeliveryAutoReleaseWorker] Background Worker started');

    const tick = async () => {
      if (!this.isRunning) return;
      try {
        await this.processExpiredConfirmations();
      } catch (err) {
        logger.error('[DeliveryAutoReleaseWorker] Error processing expired confirmations:', err);
      } finally {
        if (this.isRunning) {
          this.timer = setTimeout(tick, pollIntervalMs);
        }
      }
    };

    this.timer = setTimeout(tick, pollIntervalMs);
  }

  stop() {
    this.isRunning = false;
    if (this.timer) {
      clearTimeout(this.timer);
      this.timer = null;
    }
    logger.info('[DeliveryAutoReleaseWorker] Background Worker stopped gracefully.');
  }

  async processExpiredConfirmations(): Promise<number> {
    const expiredOrders = await prisma.orders.findMany({
      where: {
        order_status: 'delivered_pending_confirmation',
        delivery_code_expires_at: { lte: new Date() },
      },
      select: { id: true },
      take: 50,
    });

    let processedCount = 0;
    for (const order of expiredOrders) {
      try {
        const released = await transactionService.autoReleaseIfExpired(order.id);
        if (released) {
          logger.info(`[DeliveryAutoReleaseWorker] Order #${order.id} auto-released after no buyer confirmation.`);
          processedCount++;
        }
      } catch (err) {
        logger.error(`[DeliveryAutoReleaseWorker] Failed to auto-release Order #${order.id}:`, err);
      }
    }

    return processedCount;
  }
}

export const deliveryAutoReleaseWorker = new DeliveryAutoReleaseWorker();
