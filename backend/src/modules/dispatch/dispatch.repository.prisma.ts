import QRCode from 'qrcode';
import { prisma } from '../../config/db';
import { CreateDriverJobRecord, IDispatchRepository } from './dispatch.repository';
import { DriverJob, DriverJobStatus } from './dispatch.types';
import { assignment_status } from '../../generated/prisma/client';

// assignment_status (the DB enum) has no distinct "completed" value — a
// completed delivery's driver_assignments row stays 'accepted' forever.
// COMPLETED is a real, distinct state at the domain level though, so it has
// to be read off the linked order's order_status instead (set to 'completed'
// by TransactionService.confirmDelivery via the RELEASED transaction status).
// 'expired' assignments (auto-timed-out offers, see DriverTimeoutWorker) have
// no domain equivalent either — closest is DECLINED: a non-actionable,
// already-reassigned-elsewhere terminal state, not something the driver
// should ever see as pending.
const statusToPrisma = (status: DriverJobStatus): assignment_status => {
  switch (status) {
    case 'DECLINED':
      return 'declined';
    case 'ACCEPTED':
    case 'IN_TRANSIT':
    case 'DELIVERED':
    case 'COMPLETED':
      return 'accepted';
    case 'PENDING':
    default:
      return 'notified';
  }
};

const statusFromPrisma = (assignmentStatus: assignment_status, orderStatus?: string | null): DriverJobStatus => {
  switch (assignmentStatus) {
    case 'accepted':
      switch (orderStatus) {
        case 'completed':
          return 'COMPLETED';
        case 'delivered_pending_confirmation':
          return 'DELIVERED';
        case 'in_transit':
          return 'IN_TRANSIT';
        default:
          return 'ACCEPTED';
      }
    case 'declined':
    case 'expired':
      return 'DECLINED';
    case 'notified':
    default:
      return 'PENDING';
  }
};

// Farmer (pickup contact) comes via orders.produce_listings.users; buyer
// (dropoff contact) via orders.users — same "users" relation name, two
// different joins, same shape needed on every query below.
const jobInclude = {
  orders: {
    include: {
      users: true,
      produce_listings: {
        include: { crop_types: true, users: true },
      },
    },
  },
} as const;

const mapPrismaToJob = async (a: any): Promise<DriverJob> => {
  const status = statusFromPrisma(a.status, a.orders?.order_status);
  const deliveryQrImage = status === 'DELIVERED' && a.orders?.delivery_code ? await QRCode.toDataURL(a.orders.delivery_code) : null;

  return {
    id: a.id,
    transactionId: a.order_id,
    listingId: a.orders?.listing_id || 'unknown',
    driverId: a.driver_id,
    cropType: a.orders?.produce_listings?.crop_types?.name || 'crop',
    quantityKg: a.orders?.produce_listings?.quantity_kg ? Number(a.orders.produce_listings.quantity_kg) : 100,
    amountGhs: a.orders?.amount ? Number(a.orders.amount) : 0,
    status,
    createdAt: a.notified_at,
    updatedAt: a.responded_at || a.notified_at,
    farmerName: a.orders?.produce_listings?.users?.full_name || null,
    farmerPhone: a.orders?.produce_listings?.users?.phone_number || null,
    pickupRegion: a.orders?.produce_listings?.region || null,
    buyerName: a.orders?.users?.full_name || null,
    buyerPhone: a.orders?.users?.phone_number || null,
    dropoffRegion: a.orders?.users?.region || null,
    deliveryQrImage,
  };
};

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
      include: jobInclude,
    });

    return mapPrismaToJob(assignment);
  }

  async findById(id: string): Promise<DriverJob | null> {
    const found = await prisma.driver_assignments.findUnique({
      where: { id },
      include: jobInclude,
    });
    return found ? mapPrismaToJob(found) : null;
  }

  async findAllForTransaction(transactionId: string): Promise<DriverJob[]> {
    const list = await prisma.driver_assignments.findMany({
      where: { order_id: transactionId },
      include: jobInclude,
      orderBy: { sequence_number: 'asc' },
    });
    return Promise.all(list.map(mapPrismaToJob));
  }

  async findActiveForTransaction(transactionId: string): Promise<DriverJob | null> {
    const found = await prisma.driver_assignments.findFirst({
      where: {
        order_id: transactionId,
        status: { in: ['notified', 'accepted'] },
      },
      include: jobInclude,
      orderBy: { sequence_number: 'desc' },
    });
    return found ? mapPrismaToJob(found) : null;
  }

  async findJobsForDriver(driverId: string, status?: DriverJobStatus): Promise<DriverJob[]> {
    const where: any = { driver_id: driverId };
    // ACCEPTED/IN_TRANSIT/DELIVERED/COMPLETED all share the same
    // assignment_status ('accepted') — see the note above statusFromPrisma —
    // so telling them apart at the query level requires filtering on the
    // linked order's order_status too, not just statusToPrisma's single enum
    // value.
    if (status === 'ACCEPTED') {
      where.status = 'accepted';
      where.orders = { order_status: 'driver_assigned' };
    } else if (status === 'IN_TRANSIT') {
      where.status = 'accepted';
      where.orders = { order_status: 'in_transit' };
    } else if (status === 'DELIVERED') {
      where.status = 'accepted';
      where.orders = { order_status: 'delivered_pending_confirmation' };
    } else if (status === 'COMPLETED') {
      where.status = 'accepted';
      where.orders = { order_status: 'completed' };
    } else if (status === 'DECLINED') {
      where.status = { in: ['declined', 'expired'] };
    } else if (status) {
      where.status = statusToPrisma(status);
    }

    const list = await prisma.driver_assignments.findMany({
      where,
      include: jobInclude,
      orderBy: { notified_at: 'desc' },
    });
    return Promise.all(list.map(mapPrismaToJob));
  }

  async update(id: string, status: DriverJobStatus): Promise<DriverJob> {
    const updated = await prisma.driver_assignments.update({
      where: { id },
      data: {
        status: statusToPrisma(status),
        responded_at: new Date(),
      },
      include: jobInclude,
    });

    return mapPrismaToJob(updated);
  }
}

export const dispatchRepository = new PrismaDispatchRepository();
