import { randomUUID } from 'crypto';
import { AuditEntry } from './audit.types';
import { CreateAuditEntryRecord, IAuditRepository } from './audit.repository';

/**
 * Temporary in-memory store standing in for the Prisma-backed repository.
 * Swap for a PrismaAuditRepository once schema.prisma exists — AuditService
 * only depends on IAuditRepository.
 */
export class InMemoryAuditRepository implements IAuditRepository {
  private readonly entries: AuditEntry[] = [];

  async findLatest(): Promise<AuditEntry | null> {
    return this.entries.length > 0 ? this.entries[this.entries.length - 1] : null;
  }

  async create(entry: CreateAuditEntryRecord): Promise<AuditEntry> {
    const created: AuditEntry = { id: randomUUID(), ...entry, createdAt: new Date() };
    this.entries.push(created);
    return created;
  }

  async findByEntityId(entityId: string): Promise<AuditEntry[]> {
    return this.entries
      .filter((entry) => entry.entityId === entityId)
      .sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime());
  }
}

export const auditRepository = new InMemoryAuditRepository();
