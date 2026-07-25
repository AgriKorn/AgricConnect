import { prisma } from '../../config/db';
import { CreateDisputeRecord, IDisputeRepository } from './dispute.repository';
import { Dispute, DisputeStatus, DisputeType } from './dispute.types';
import { dispute_status } from '../../generated/prisma/client';

const statusFromPrisma = (s: dispute_status): DisputeStatus => {
  return s === 'resolved' ? 'RESOLVED' : 'OPEN';
};

const mapPrismaToDispute = (d: any): Dispute => ({
  id: d.id,
  transactionId: d.order_id,
  raisedBy: d.raised_by,
  type: 'OTHER',
  description: d.reason,
  status: statusFromPrisma(d.status),
  resolution: d.resolution_notes || null,
  createdAt: d.created_at,
  updatedAt: d.resolved_at || d.created_at,
});

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

  async resolve(id: string, resolution: string): Promise<Dispute> {
    const updated = await prisma.dispute.update({
      where: { id },
      data: {
        status: 'resolved',
        resolution_notes: resolution,
        resolved_at: new Date(),
      },
    });
    return mapPrismaToDispute(updated);
  }
}

export const disputeRepository = new PrismaDisputeRepository();
