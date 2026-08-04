import { listingRepository } from '../modules/listing/listing.repository.prisma';
import { IListingRepository } from '../modules/listing/listing.repository';
import { willDropBelowThresholdWithin } from '../modules/listing/freshnessMonitor';
import { notificationService } from '../modules/notification/notification.service';
import { notificationRepository, NotificationRepository } from '../modules/notification/notification.repository.prisma';
import logger from '../utils/logger';

const FRESHNESS_ALERT_TYPE = 'FRESHNESS_WARNING';

/**
 * SRS 3.1, "System Notification": notify farmers when a listing's freshness is
 * projected to fall below a threshold within a set window (48 hours by default).
 *
 * Sweeps active listings on an interval, projects each one forward through the
 * shared freshness-decay curve, and alerts the owning farmer as the crossing
 * approaches — once per listing, deduped against the notifications already sent.
 *
 * Dependencies are injectable so the sweep can be unit-tested without a database
 * or timers, matching OutboxWorker/DriverTimeoutWorker.
 */
export class FreshnessMonitorWorker {
  private isRunning = false;
  private timer: NodeJS.Timeout | null = null;

  constructor(
    private readonly thresholdPercent = Number(process.env.FRESHNESS_ALERT_THRESHOLD ?? 40),
    private readonly withinHours = Number(process.env.FRESHNESS_ALERT_WINDOW_HOURS ?? 48),
    private readonly listings: Pick<IListingRepository, 'findAllActive'> = listingRepository,
    private readonly notifications: Pick<NotificationRepository, 'existsForListingAndType'> = notificationRepository,
    private readonly notifier: Pick<typeof notificationService, 'sendNotification'> = notificationService,
  ) {}

  start(pollIntervalMs = 60 * 60 * 1000) {
    if (this.isRunning) return;
    this.isRunning = true;
    logger.info(
      `[FreshnessMonitorWorker] Started (threshold: ${this.thresholdPercent}%, window: ${this.withinHours}h, interval: ${pollIntervalMs}ms)`,
    );

    const tick = async () => {
      if (!this.isRunning) return;
      try {
        await this.sweep();
      } catch (err) {
        logger.error('[FreshnessMonitorWorker] Error during freshness sweep:', err);
      } finally {
        if (this.isRunning) {
          this.timer = setTimeout(tick, pollIntervalMs);
        }
      }
    };

    // Run one sweep immediately rather than waiting a full interval, so a
    // listing already near the threshold is caught on the next boot, not an
    // hour later.
    void tick();
  }

  stop() {
    this.isRunning = false;
    if (this.timer) {
      clearTimeout(this.timer);
      this.timer = null;
    }
    logger.info('[FreshnessMonitorWorker] Stopped gracefully.');
  }

  /** Runs one pass over active listings; returns how many farmers were alerted. */
  async sweep(now: Date = new Date()): Promise<number> {
    const active = await this.listings.findAllActive();
    let alerted = 0;

    for (const listing of active) {
      const crossing = willDropBelowThresholdWithin(
        { freshnessScore: listing.freshnessScore, shelfLifeDays: listing.shelfLifeDays, createdAt: listing.createdAt },
        now,
        this.thresholdPercent,
        this.withinHours,
      );
      if (!crossing) continue;

      const alreadyAlerted = await this.notifications.existsForListingAndType(listing.id, FRESHNESS_ALERT_TYPE);
      if (alreadyAlerted) continue;

      await this.notifier.sendNotification({
        userId: listing.farmerId,
        type: FRESHNESS_ALERT_TYPE,
        message:
          `Your ${listing.cropType} listing is projected to drop below ${this.thresholdPercent}% freshness ` +
          `within ${this.withinHours} hours. Consider selling or discounting it soon to avoid post-harvest loss.`,
        listingId: listing.id,
      });
      alerted++;
    }

    if (alerted > 0) {
      logger.info(`[FreshnessMonitorWorker] Sent ${alerted} freshness warning(s).`);
    }
    return alerted;
  }
}

export const freshnessMonitorWorker = new FreshnessMonitorWorker();
