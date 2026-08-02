import { prisma } from '../../config/db';
import { CreateTransactionRecord, ITransactionRepository } from './transaction.repository';
import { Transaction, TransactionStatus } from './transaction.types';
import { Prisma } from '../../generated/prisma/client';

/** The driver who accepted this delivery job, if any — most recent acceptance wins. */
const acceptedDriverInclude = {
  where: { status: 'accepted' as const },
  orderBy: { responded_at: 'desc' as const },
  take: 1,
  include: { users: true },
};

const mapPrismaToTransaction = (order: any, farmerId?: string): Transaction => {
  let status: TransactionStatus = 'PAYMENT_HELD';
  if (order.order_status === 'completed' || order.payments?.status === 'released') {
    status = 'RELEASED';
  } else if (order.order_status === 'cancelled' || order.payments?.status === 'refunded') {
    status = 'CANCELLED';
  }

  return {
    id: order.id,
    listingId: order.listing_id,
    buyerId: order.buyer_id,
    farmerId: farmerId || order.produce_listings?.farmer_id || 'unknown',
    farmerName: order.produce_listings?.users?.full_name || null,
    driverName: order.driver_assignments?.[0]?.users?.full_name || null,
    cropType: order.produce_listings?.crop_types?.name || 'crop',
    amountGhs: Number(order.amount),
    status,
    hasOwnTransport: order.transport_mode === 'self_collect',
    paymentReference: order.payments?.provider_reference || `ref-${order.id.slice(0, 8)}`,
    transferCode: order.payments?.payout_reference || null,
    createdAt: order.created_at,
    updatedAt: order.updated_at,
  };
};

export class PrismaTransactionRepository implements ITransactionRepository {
  async create(data: CreateTransactionRecord): Promise<Transaction> {
    const amountDecimal = new Prisma.Decimal(data.amountGhs);

    const order = await prisma.orders.create({
      data: {
        listing_id: data.listingId,
        buyer_id: data.buyerId,
        transport_mode: data.hasOwnTransport ? 'self_collect' : 'driver_assisted',
        order_status: 'awaiting_driver',
        amount: amountDecimal,
        payments: {
          create: {
            amount: amountDecimal,
            status: 'held',
            provider: 'agriconnect_escrow',
            provider_reference: data.paymentReference,
          },
        },
      },
      include: { payments: true, produce_listings: true },
    });

    return mapPrismaToTransaction(order, data.farmerId);
  }

  async findById(id: string): Promise<Transaction | null> {
    const found = await prisma.orders.findUnique({
      where: { id },
      include: { payments: true, produce_listings: true, driver_assignments: acceptedDriverInclude },
    });
    return found ? mapPrismaToTransaction(found) : null;
  }

  async findActiveByListingId(listingId: string): Promise<Transaction | null> {
    const found = await prisma.orders.findFirst({
      where: {
        listing_id: listingId,
        order_status: { notIn: ['cancelled', 'completed'] },
      },
      include: { payments: true, produce_listings: true },
    });
    return found ? mapPrismaToTransaction(found) : null;
  }

  async findRecentOrderByBuyerAndListing(buyerId: string, listingId: string, withinSeconds = 60): Promise<Transaction | null> {
    const cutoff = new Date(Date.now() - withinSeconds * 1000);
    const found = await prisma.orders.findFirst({
      where: {
        buyer_id: buyerId,
        listing_id: listingId,
        created_at: { gte: cutoff },
      },
      include: { payments: true, produce_listings: true },
      orderBy: { created_at: 'desc' },
    });
    return found ? mapPrismaToTransaction(found) : null;
  }

  async findManyForUser(userId: string): Promise<Transaction[]> {
    const list = await prisma.orders.findMany({
      where: {
        OR: [{ buyer_id: userId }, { produce_listings: { farmer_id: userId } }],
      },
      include: {
        payments: true,
        produce_listings: { include: { crop_types: true, users: true } },
        driver_assignments: acceptedDriverInclude,
      },
      orderBy: { created_at: 'desc' },
    });
    return list.map((o) => mapPrismaToTransaction(o));
  }

  async findAll(): Promise<Transaction[]> {
    const list = await prisma.orders.findMany({
      include: { payments: true, produce_listings: true, driver_assignments: acceptedDriverInclude },
      orderBy: { created_at: 'desc' },
    });
    return list.map((o) => mapPrismaToTransaction(o));
  }

  async update(id: string, data: Partial<Pick<Transaction, 'status' | 'transferCode'>>): Promise<Transaction> {
    const updateData: any = { updated_at: new Date() };

    if (data.status === 'RELEASED') {
      updateData.order_status = 'completed';
      updateData.completed_at = new Date();
      await prisma.payments.updateMany({
        where: { order_id: id },
        data: {
          status: 'released',
          released_at: new Date(),
          ...(data.transferCode && { payout_reference: data.transferCode }),
        },
      });
    } else if (data.status === 'CANCELLED') {
      updateData.order_status = 'cancelled';
      await prisma.payments.updateMany({
        where: { order_id: id },
        data: { status: 'refunded', refunded_at: new Date() },
      });
    }

    const updated = await prisma.orders.update({
      where: { id },
      data: updateData,
      include: { payments: true, produce_listings: true },
    });

    return mapPrismaToTransaction(updated);
  }
}

export const transactionRepository = new PrismaTransactionRepository();
