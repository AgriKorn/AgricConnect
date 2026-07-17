import crypto from 'crypto';
import { IAuditRepository } from './audit.repository';
import { auditRepository } from './audit.repository.memory';
import { AuditEntry, AuditEventType } from './audit.types';

const hashEntry = (input: {
  eventType: AuditEventType;
  entityId: string;
  data: Record<string, unknown>;
  userId: string;
  timestamp: string;
  previousHash: string;
}): string => crypto.createHash('sha256').update(JSON.stringify(input)).digest('hex');

export interface ChainVerification {
  isValid: boolean;
  entries: number;
  brokenAt?: number;
}

export class AuditService {
  constructor(private readonly repo: IAuditRepository) {}

  async log(eventType: AuditEventType, entityId: string, data: Record<string, unknown>, userId: string): Promise<AuditEntry> {
    const previous = await this.repo.findLatest();
    const previousHash = previous?.hash ?? '0';
    const timestamp = new Date().toISOString();
    const hash = hashEntry({ eventType, entityId, data, userId, timestamp, previousHash });

    return this.repo.create({ eventType, entityId, data, userId, hash, previousHash });
  }

  async verifyChain(entityId: string): Promise<ChainVerification> {
    const entries = await this.repo.findByEntityId(entityId);
    if (entries.length === 0) return { isValid: true, entries: 0 };

    for (let i = 0; i < entries.length; i++) {
      const entry = entries[i];
      const expectedHash = hashEntry({
        eventType: entry.eventType,
        entityId: entry.entityId,
        data: entry.data,
        userId: entry.userId,
        timestamp: entry.createdAt.toISOString(),
        previousHash: entry.previousHash,
      });
      if (expectedHash !== entry.hash) {
        return { isValid: false, entries: entries.length, brokenAt: i };
      }
    }

    return { isValid: true, entries: entries.length };
  }
}

export const auditService = new AuditService(auditRepository);
