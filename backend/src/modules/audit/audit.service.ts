import crypto from 'crypto';
import { auditRepository, AuditSearchFilters, PrismaAuditRepository } from './audit.repository.prisma';
import { AuditEntry, AuditEventType } from './audit.types';

export interface ChainVerificationResult {
  valid: boolean;
  totalEntries: number;
  brokenEntryId?: string;
  failureReason?: string;
}

const canonicalJson = (obj: any): string => {
  if (obj === null || typeof obj !== 'object') return JSON.stringify(obj);
  if (Array.isArray(obj)) return `[${obj.map(canonicalJson).join(',')}]`;
  const keys = Object.keys(obj).sort();
  return `{${keys.map((k) => `${JSON.stringify(k)}:${canonicalJson(obj[k])}`).join(',')}}`;
};

export const truncateToSeconds = (d: Date): Date => {
  const t = new Date(d);
  t.setMilliseconds(0);
  return t;
};

export const formatTimestamp = (d: Date): string => {
  return truncateToSeconds(d).toISOString();
};

export const computePayloadHash = (previousHash: string, eventType: string, entityId: string, userId: string, data: any, createdAt: Date): string => {
  const payload = `${previousHash}:${eventType}:ENTITY:${entityId}:${userId}:${canonicalJson(data)}:${formatTimestamp(createdAt)}`;
  return crypto.createHash('sha256').update(payload).digest('hex');
};

export class AuditService {
  constructor(private readonly repo: PrismaAuditRepository) {}

  async log(eventType: AuditEventType, entityId: string, data: Record<string, unknown>, userId: string): Promise<AuditEntry> {
    const previous = await this.repo.findLatest();
    const previousHash = previous?.hash ?? 'GENESIS';
    const createdAt = truncateToSeconds(new Date());

    const hash = computePayloadHash(previousHash, eventType, entityId, userId, data, createdAt);

    return this.repo.create({ eventType, entityId, data, userId, hash, previousHash, createdAt });
  }

  async verifyChainForEntity(entityId: string): Promise<ChainVerificationResult> {
    const entries = await this.repo.findByEntityId(entityId);
    if (entries.length === 0) return { valid: true, totalEntries: 0 };

    for (const entry of entries) {
      const recomputedHash = computePayloadHash(
        entry.previousHash,
        entry.eventType,
        entry.entityId,
        entry.userId,
        entry.data,
        entry.createdAt,
      );

      if (entry.hash !== recomputedHash) {
        return {
          valid: false,
          totalEntries: entries.length,
          brokenEntryId: entry.id,
          failureReason: `Hash tampering detected at entry ${entry.id}. Calculated '${recomputedHash}', stored '${entry.hash}'`,
        };
      }
    }

    return { valid: true, totalEntries: entries.length };
  }

  async searchAuditLogs(filters: AuditSearchFilters) {
    return await this.repo.findFiltered(filters);
  }

  async exportAuditLogsCsv(entityId?: string): Promise<string> {
    const entries = entityId
      ? await this.repo.findByEntityId(entityId)
      : (await this.repo.findFiltered({ page: 1, limit: 1000 })).entries;

    const headers = ['ID', 'Event Type', 'Entity ID', 'Actor ID', 'Hash', 'Previous Hash', 'Created At'];
    const rows = entries.map((e) => [
      e.id,
      e.eventType,
      e.entityId,
      e.userId,
      e.hash,
      e.previousHash,
      e.createdAt.toISOString(),
    ]);

    return [headers.join(','), ...rows.map((r) => r.map((cell) => `"${cell}"`).join(','))].join('\n');
  }
}

export const auditService = new AuditService(auditRepository);
