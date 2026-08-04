import { prisma } from '../../config/db';
import { CreateDisputeRecord, IDisputeRepository } from './dispute.repository';
import { Dispute, DisputeStatus, DisputeType } from './dispute.types';
import { dispute_status } from '../../generated/prisma/client';

const statusFromPrisma = (s: dispute_status): DisputeStatus => {
  return s === 'resolved' ? 'RESOLVED' : 'OPEN';
};

// The Dispute model has no dedicated type column, so create() encodes it as a
// "[TYPE] description" prefix on the free-text reason field. Without parsing
// it back out here, every dispute read back as type 'OTHER' regardless of
// what was actually filed, and the raw "[TYPE] " prefix leaked into the
// description shown to admins.
const DISPUTE_TYPES: DisputeType[] = ['WRONG_PRODUCE', 'NON_DELIVERY', 'PAYMENT_ISSUE', 'OTHER'];
const parseReason = (reason: string): { type: DisputeType; description: string } => {
  const match = reason.match(/^\[([A-Z_]+)\]\s?(.*)$/s);
  const candidate = match?.[1] as DisputeType | undefined;
  if (candidate && DISPUTE_TYPES.includes(candidate)) {
    return { type: candidate, description: match![2] };
  }
  return { type: 'OTHER', description: reason };
};

const mapPrismaToDispute = (d: any): Dispute => {
  const { type, description } = parseReason(d.reason);
  return {
    id: d.id,
    transactionId: d.order_id,
    raisedBy: d.raised_by,
    type,
    description,
    status: statusFromPrisma(d.status),
    resolution: d.resolution_notes || null,
    createdAt: d.created_at,
    updatedAt: d.resolved_at || d.created_at,
  };
};

export class PrismaDisputeRepository implements IDisputeRepository {
  async create(data: CreateDisputeRecord): Promise<Dispute> {
    const created = await prisma.dispute.create({
      data: {
        order_id: data.transactionId,
        raised_by: data.raisedBy,
        reason: `[${data.type}] ${data.description}`,
        status: 'open',
      },
    });
    return mapPrismaToDispute(created);
  }

  async findById(id: string): Promise<Dispute | null> {
    const found = await prisma.dispute.findUnique({
      where: { id },
    });
    return found ? mapPrismaToDispute(found) : null;
  }

  async findAll(): Promise<Dispute[]> {
    const list = await prisma.dispute.findMany({
      orderBy: { created_at: 'desc' },
    });
    return list.map(mapPrismaToDispute);
  }

  async resolve(id: string, resolution: string, resolvedBy: string): Promise<Dispute> {
    const updated = await prisma.dispute.update({
      where: { id },
      data: {
        status: 'resolved',
        resolution_notes: resolution,
        resolved_at: new Date(),
        resolved_by: resolvedBy,
      },
    });
    return mapPrismaToDispute(updated);
  }

  /** Guards against opening a second dispute on a transaction that already has one pending. */
  async findOpenByTransaction(transactionId: string): Promise<Dispute | null> {
    const found = await prisma.dispute.findFirst({
      where: { order_id: transactionId, status: 'open' },
    });
    return found ? mapPrismaToDispute(found) : null;
  }
}

export const disputeRepository = new PrismaDisputeRepository();
