import { prisma } from '../config/db';
import { dispatchService } from '../modules/dispatch/dispatch.service';
import logger from '../utils/logger';

export class DriverTimeoutWorker {
  private isRunning = false;
  private timer: NodeJS.Timeout | null = null;
  private timeoutMinutes: number;

  constructor(timeoutMinutes = 3) {
    this.timeoutMinutes = timeoutMinutes;
  }

  start(pollIntervalMs = 10000) {
    if (this.isRunning) return;
    this.isRunning = true;
    logger.info(`[DriverTimeoutWorker] Background Worker started (Timeout Threshold: ${this.timeoutMinutes} mins)`);

    const tick = async () => {
      if (!this.isRunning) return;
      try {
        await this.processExpiredAssignments();
      } catch (err) {
        logger.error('[DriverTimeoutWorker] Error processing expired driver assignments:', err);
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
    logger.info('[DriverTimeoutWorker] Background Worker stopped gracefully.');
  }

  async processExpiredAssignments(): Promise<number> {
    const cutoffTime = new Date(Date.now() - this.timeoutMinutes * 60 * 1000);

    // Find all driver assignments exceeding the 3-minute timeout threshold
    const expiredList = await prisma.driver_assignments.findMany({
      where: {
        status: 'notified',
        notified_at: { lte: cutoffTime },
      },
    });

    if (expiredList.length === 0) return 0;

    let reassignedCount = 0;
    for (const assignment of expiredList) {
      try {
        // Atomic update to mark as EXPIRED
        await prisma.driver_assignments.update({
          where: { id: assignment.id },
          data: { status: 'expired', responded_at: new Date() },
        });

        logger.info(
          `[DriverTimeoutWorker] Driver ${assignment.driver_id} timed out for Order #${assignment.order_id}. Triggering auto-reassignment...`,
        );

        // Auto-assign next candidate driver
        await dispatchService.reassignNextDriver(assignment.order_id);
        reassignedCount++;
      } catch (err) {
        logger.error(`[DriverTimeoutWorker] Failed to reassign driver for Order #${assignment.order_id}:`, err);
      }
    }

    return reassignedCount;
  }
}

export const driverTimeoutWorker = new DriverTimeoutWorker();
