import { randomUUID } from 'crypto';
import { NotFoundError } from '../../utils/errors';
import { Dispute } from './dispute.types';
import { CreateDisputeRecord, IDisputeRepository } from './dispute.repository';

/**
 * Temporary in-memory store standing in for the Prisma-backed repository.
 * Swap for a PrismaDisputeRepository once schema.prisma exists.
 */
export class InMemoryDisputeRepository implements IDisputeRepository {
  private readonly disputes = new Map<string, Dispute>();

  async create(data: CreateDisputeRecord): Promise<Dispute> {
    const now = new Date();
    const dispute: Dispute = { id: randomUUID(), ...data, status: 'OPEN', resolution: null, createdAt: now, updatedAt: now };
    this.disputes.set(dispute.id, dispute);
    return dispute;
  }

  async findById(id: string): Promise<Dispute | null> {
    return this.disputes.get(id) ?? null;
  }

  async findAll(): Promise<Dispute[]> {
    return [...this.disputes.values()].sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
  }

  async resolve(id: string, resolution: string): Promise<Dispute> {
    const existing = this.disputes.get(id);
    if (!existing) throw new NotFoundError('Dispute not found');
    const updated: Dispute = { ...existing, status: 'RESOLVED', resolution, updatedAt: new Date() };
    this.disputes.set(id, updated);
    return updated;
  }

  async findOpenByTransaction(transactionId: string): Promise<Dispute | null> {
    return (
      [...this.disputes.values()].find((d) => d.transactionId === transactionId && d.status === 'OPEN') ?? null
    );
  }
}

export const disputeRepository = new InMemoryDisputeRepository();
