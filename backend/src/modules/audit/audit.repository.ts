import { AuditEntry } from './audit.types';

export type CreateAuditEntryRecord = Omit<AuditEntry, 'id' | 'createdAt'>;

export interface IAuditRepository {
  findLatest(): Promise<AuditEntry | null>;
  create(entry: CreateAuditEntryRecord): Promise<AuditEntry>;
  findByEntityId(entityId: string): Promise<AuditEntry[]>;
}
