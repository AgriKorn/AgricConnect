import { prisma } from '../../config/db';

export interface CreateOutboxInput {
  aggregateType: string;
  aggregateId: string;
  eventType: string;
  payload: Record<string, unknown>;
}

export interface OutboxEvent {
  id: string;
  aggregateType: string;
  aggregateId: string;
  eventType: string;
  payload: Record<string, unknown>;
  publishedAt: Date | null;
  createdAt: Date;
}

const mapPrismaToOutboxEvent = (row: any): OutboxEvent => ({
  id: row.id,
  aggregateType: row.aggregate_type,
  aggregateId: row.aggregate_id,
  eventType: row.event_type,
  payload: (row.payload as Record<string, unknown>) || {},
  publishedAt: row.published_at,
  createdAt: row.created_at,
});

export class OutboxService {
  /**
   * Writes an event row to `outbox_events` inside a transactional context (Prisma tx client or global prisma client).
   * This guarantees that the event is committed if and only if the surrounding database transaction succeeds.
   */
  async recordEvent(
    txClient: any,
    aggregateType: string,
    aggregateId: string,
    eventType: string,
    payload: Record<string, unknown>,
  ): Promise<OutboxEvent> {
    const db = txClient || prisma;
    const created = await db.outbox_events.create({
      data: {
        aggregate_type: aggregateType,
        aggregate_id: aggregateId,
        event_type: eventType,
        payload: payload as any,
      },
    });
    return mapPrismaToOutboxEvent(created);
  }

  async fetchUnpublished(take = 50): Promise<OutboxEvent[]> {
    const rows = await prisma.outbox_events.findMany({
      where: { published_at: null },
      orderBy: { created_at: 'asc' },
      take,
    });
    return rows.map(mapPrismaToOutboxEvent);
  }

  async markPublished(eventId: string, publishedAt: Date = new Date()): Promise<OutboxEvent> {
    const updated = await prisma.outbox_events.update({
      where: { id: eventId },
      data: { published_at: publishedAt },
    });
    return mapPrismaToOutboxEvent(updated);
  }
}

export const outboxService = new OutboxService();
