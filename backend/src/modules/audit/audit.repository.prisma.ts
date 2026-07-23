import { prisma } from '../../config/db';
import { CreateAuditEntryRecord, IAuditRepository } from './audit.repository';
import { computePayloadHash, truncateToSeconds } from './audit.service';
import { AuditEntry, AuditEventType } from './audit.types';

export interface AuditSearchFilters {
  eventType?: string;
  entityType?: string;
  actorId?: string;
  startDate?: Date;
  endDate?: Date;
  page: number;
  limit: number;
}

const isUuid = (str: string): boolean =>
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(str);

const mapPrismaToAuditEntry = (a: any): AuditEntry => ({
  id: a.id.toString(),
  eventType: a.event_type as AuditEventType,
  entityId: a.entity_id,
  data: (a.event_data as Record<string, unknown>) || {},
  userId: a.actor_id || 'SYSTEM',
  hash: a.event_hash.trim(),
  previousHash: a.previous_hash ? a.previous_hash.trim() : 'GENESIS',
  createdAt: a.created_at,
});

export class PrismaAuditRepository implements IAuditRepository {
  async findLatest(): Promise<AuditEntry | null> {
    const found = await prisma.auditTrail.findFirst({
      orderBy: { id: 'desc' },
    });
    return found ? mapPrismaToAuditEntry(found) : null;
  }

  async create(entry: CreateAuditEntryRecord): Promise<AuditEntry> {
    const previousHash = entry.previousHash || 'GENESIS';
    
    // 1. Insert record to capture authoritative PostgreSQL created_at timestamp
    const created = await prisma.auditTrail.create({
      data: {
        event_type: entry.eventType,
        entity_type: 'ENTITY',
        entity_id: entry.entityId,
        actor_id: isUuid(entry.userId) ? entry.userId : null,
        event_data: entry.data as any,
        event_hash: 'PENDING',
        previous_hash: previousHash === 'GENESIS' ? null : previousHash,
      },
    });

    const createdAt = truncateToSeconds(created.created_at);
    const hash = computePayloadHash(previousHash, entry.eventType, entry.entityId, entry.userId, entry.data, createdAt);

    // 2. Persist exact cryptographic hash computed from DB timestamp
    const updated = await prisma.auditTrail.update({
      where: { id: created.id },
      data: { event_hash: hash },
    });

    return mapPrismaToAuditEntry(updated);
  }

  async findByEntityId(entityId: string): Promise<AuditEntry[]> {
    const list = await prisma.auditTrail.findMany({
      where: { entity_id: entityId },
      orderBy: { id: 'asc' },
    });
    return list.map(mapPrismaToAuditEntry);
  }

  async findFiltered(filters: AuditSearchFilters): Promise<{ entries: AuditEntry[]; total: number }> {
    const where: any = {};
    if (filters.eventType) where.event_type = filters.eventType;
    if (filters.entityType) where.entity_type = filters.entityType;
    if (filters.actorId) where.actor_id = filters.actorId;
    if (filters.startDate || filters.endDate) {
      where.created_at = {
        ...(filters.startDate && { gte: filters.startDate }),
        ...(filters.endDate && { lte: filters.endDate }),
      };
    }

    const [list, total] = await Promise.all([
      prisma.auditTrail.findMany({
        where,
        orderBy: { id: 'desc' },
        skip: (filters.page - 1) * filters.limit,
        take: Math.min(filters.limit, 50),
      }),
      prisma.auditTrail.count({ where }),
    ]);

    return { entries: list.map(mapPrismaToAuditEntry), total };
  }
}

export const auditRepository = new PrismaAuditRepository();
