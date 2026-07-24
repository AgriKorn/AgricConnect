import { outboxService, OutboxEvent } from '../modules/outbox/outbox.service';
import logger from '../utils/logger';

export type EventPublisher = (event: OutboxEvent) => Promise<void>;

export class OutboxWorker {
  private isRunning = false;
  private timer: NodeJS.Timeout | null = null;
  private publisher: EventPublisher;

  constructor(publisher?: EventPublisher) {
    // Default publisher logs event payload (will dispatch to SQS Queue in AWS environment)
    this.publisher =
      publisher ||
      (async (event: OutboxEvent) => {
        logger.info(
          `[OutboxWorker] Published ${event.eventType} for ${event.aggregateType}#${event.aggregateId} to Queue`,
        );
      });
  }

  start(pollIntervalMs = 1000) {
    if (this.isRunning) return;
    this.isRunning = true;
    logger.info(`[OutboxWorker] Outbox Poller Worker started (Interval: ${pollIntervalMs}ms)`);

    const tick = async () => {
      if (!this.isRunning) return;
      try {
        await this.processBatch();
      } catch (err) {
        logger.error('[OutboxWorker] Error processing outbox batch:', err);
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
    logger.info('[OutboxWorker] Outbox Poller Worker stopped gracefully.');
  }

  async processBatch(): Promise<number> {
    const unpublished = await outboxService.fetchUnpublished(50);
    if (unpublished.length === 0) return 0;

    let processedCount = 0;
    for (const event of unpublished) {
      try {
        await this.publisher(event);
        await outboxService.markPublished(event.id);
        processedCount++;
      } catch (error) {
        logger.error(`[OutboxWorker] Failed to publish outbox event ${event.id} (type: ${event.eventType}):`, error);
        // Do not update published_at so the event remains for recovery in the next poll loop
        break;
      }
    }
    return processedCount;
  }
}

export const outboxWorker = new OutboxWorker();
