import { prisma } from '../../config/db';
import { CreateDriverJobRecord, IDispatchRepository } from './dispatch.repository';
import { DriverJob, DriverJobStatus } from './dispatch.types';
import { assignment_status } from '../../generated/prisma/client';

const statusToPrisma = (status: DriverJobStatus): assignment_status => {
  switch (status) {
    case 'ACCEPTED':
    case 'COMPLETED':
      return 'accepted';
    case 'PENDING':
    default:
      return 'notified';
  }
};

const statusFromPrisma = (status: assignment_status): DriverJobStatus => {
  switch (status) {
    case 'accepted':
      return 'ACCEPTED';
    case 'declined':
      return 'DECLINED';
    case 'completed' as any:
      return 'COMPLETED';
    case 'notified':
    default:
      return 'PENDING';
  }
};

const mapPrismaToJob = (a: any): DriverJob => ({
  id: a.id,
  transactionId: a.order_id,
  listingId: a.orders?.listing_id || 'unknown',
  driverId: a.driver_id,
  cropType: a.orders?.produce_listings?.crop_types?.name || 'crop',
  quantityKg: a.orders?.produce_listings?.quantity_kg ? Number(a.orders.produce_listings.quantity_kg) : 100,
  status: statusFromPrisma(a.status),
  createdAt: a.notified_at,
  updatedAt: a.responded_at || a.notified_at,
});

export class PrismaDispatchRepository implements IDispatchRepository {
  async create(data: CreateDriverJobRecord): Promise<DriverJob> {
    const existing = await prisma.driver_assignments.count({
      where: { order_id: data.transactionId },
    });

    const assignment = await prisma.driver_assignments.create({
      data: {
        order_id: data.transactionId,
        driver_id: data.driverId,
        sequence_number: existing + 1,
        status: 'notified',
      },
      include: {
        orders: {
          include: {
            produce_listings: {
              include: { crop_types: true },
            },
          },
        },
      },
    });

    return mapPrismaToJob(assignment);
  }

  async findById(id: string): Promise<DriverJob | null> {
    const found = await prisma.driver_assignments.findUnique({
      where: { id },
      include: {
        orders: {
          include: {
            produce_listings: {
              include: { crop_types: true },
            },
          },
        },
      },
    });
    return found ? mapPrismaToJob(found) : null;
  }

  async findAllForTransaction(transactionId: string): Promise<DriverJob[]> {
    const list = await prisma.driver_assignments.findMany({
      where: { order_id: transactionId },
      include: {
        orders: {
          include: {
            produce_listings: {
              include: { crop_types: true },
            },
          },
        },
      },
      orderBy: { sequence_number: 'asc' },
    });
    return list.map(mapPrismaToJob);
  }

  async findActiveForTransaction(transactionId: string): Promise<DriverJob | null> {
    const found = await prisma.driver_assignments.findFirst({
      where: {
        order_id: transactionId,
        status: { in: ['notified', 'accepted'] },
      },
      include: {
        orders: {
          include: {
            produce_listings: {
              include: { crop_types: true },
            },
          },
        },
      },
      orderBy: { sequence_number: 'desc' },
    });
    return found ? mapPrismaToJob(found) : null;
  }

  async findJobsForDriver(driverId: string, status?: DriverJobStatus): Promise<DriverJob[]> {
    const where: any = { driver_id: driverId };
    if (status) {
      where.status = statusToPrisma(status);
    }

    const list = await prisma.driver_assignments.findMany({
      where,
      include: {
        orders: {
          include: {
            produce_listings: {
              include: { crop_types: true },
            },
          },
        },
      },
      orderBy: { notified_at: 'desc' },
    });
    return list.map(mapPrismaToJob);
  }

  async update(id: string, status: DriverJobStatus): Promise<DriverJob> {
    const updated = await prisma.driver_assignments.update({
      where: { id },
      data: {
        status: statusToPrisma(status),
        responded_at: new Date(),
      },
      include: {
        orders: {
          include: {
            produce_listings: {
              include: { crop_types: true },
            },
          },
        },
      },
    });

    return mapPrismaToJob(updated);
  }
}

export const dispatchRepository = new PrismaDispatchRepository();
