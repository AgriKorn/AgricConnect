import { prisma } from '../../config/db';
import { BadRequestError, ConflictError, ForbiddenError, NotFoundError } from '../../utils/errors';
import { auditService } from '../audit/audit.service';
import { dispatchService } from '../dispatch/dispatch.service';
import { DriverJob } from '../dispatch/dispatch.types';
import { listingRepository } from '../listing/listing.repository.prisma';
import { notificationService } from '../notification/notification.service';
import { userRepository } from '../user/user.repository.prisma';
import { PrismaTransactionRepository, transactionRepository } from './transaction.repository.prisma';
import { Transaction } from './transaction.types';
import { paymentService } from '../../services/payment.service';
import { outboxService } from '../outbox/outbox.service';

export interface PurchaseResult {
  transaction: Transaction;
  dispatch: DriverJob | null;
  authorizationUrl: string;
}

export class TransactionService {
  constructor(private readonly repo: PrismaTransactionRepository) {}

  async purchase(listingId: string, buyerId: string, hasOwnTransport: boolean): Promise<PurchaseResult> {
    const listing = await listingRepository.findById(listingId);
    if (!listing || listing.status !== 'ACTIVE') throw new NotFoundError('Listing not found or no longer active');
    if (listing.farmerId === buyerId) throw new BadRequestError('You cannot purchase your own listing');

    // 60-Second Short-Lived Idempotency Check
    const recent = await this.repo.findRecentOrderByBuyerAndListing(buyerId, listingId, 60);
    if (recent) {
      const activeDispatch = await dispatchService.findActiveForTransaction(recent.id);
      // Duplicate request within the idempotency window reuses the original order;
      // the original authorizationUrl was only returned once and isn't persisted.
      return { transaction: recent, dispatch: activeDispatch, authorizationUrl: '' };
    }

    const amountGhs = listing.pricePerKg * listing.quantityKg;
    const buyer = await userRepository.findById(buyerId);
    const { reference, authorizationUrl } = await paymentService.initializeTransaction(amountGhs, buyer?.phone ?? 'unknown', { listingId });

    return await prisma.$transaction(
      async (tx) => {
        // Atomic status transition lock
        const updatedCount = await tx.produce_listings.updateMany({
          where: { id: listingId, status: 'active' },
          data: { status: 'sold', sold_at: new Date() },
        });

        if (updatedCount.count === 0) {
          throw new ConflictError('Listing is no longer active or has already been purchased', 'LISTING_ALREADY_SOLD');
        }

        const transaction = await this.repo.create({
          listingId,
          buyerId,
          farmerId: listing.farmerId,
          amountGhs,
          hasOwnTransport,
          paymentReference: reference,
        });

        await auditService.log('PURCHASE_INITIATED', transaction.id, { listingId, amountGhs }, buyerId);
        await auditService.log('PAYMENT_HELD', transaction.id, { amountGhs, reference }, buyerId);

        // Record transactional outbox event
        await outboxService.recordEvent(tx, 'ORDER', transaction.id, 'ORDER_PLACED', {
          listingId,
          buyerId,
          farmerId: listing.farmerId,
          amountGhs,
          hasOwnTransport,
        });

        await notificationService.sendNotification({
          userId: listing.farmerId,
          type: 'LISTING_PURCHASED',
          message: `Your listing for ${listing.quantityKg}kg of ${listing.cropType} was purchased for GHS ${amountGhs}.`,
          listingId,
          orderId: transaction.id,
        });

        let dispatch: DriverJob | null = null;
        if (!hasOwnTransport) {
          dispatch = await dispatchService.assignDriver({
            transactionId: transaction.id,
            listingId,
            cropType: listing.cropType,
            quantityKg: listing.quantityKg,
          });
        }

        return { transaction, dispatch, authorizationUrl };
      },
      { timeout: 15000 },
    );
  }

  async getTransaction(id: string, userId: string, role: string): Promise<Transaction> {
    const transaction = await this.repo.findById(id);
    if (!transaction) throw new NotFoundError('Transaction not found');
    if (role !== 'admin' && transaction.buyerId !== userId && transaction.farmerId !== userId) {
      throw new ForbiddenError('You are not a participant in this transaction');
    }
    return transaction;
  }

  getMyTransactions(userId: string): Promise<Transaction[]> {
    return this.repo.findManyForUser(userId);
  }

  getAllTransactions(): Promise<Transaction[]> {
    return this.repo.findAll();
  }

  async confirmDelivery(transactionId: string, qrHash: string, confirmedBy: string): Promise<Transaction> {
    const transaction = await this.repo.findById(transactionId);
    if (!transaction) throw new NotFoundError('Transaction not found');
    if (transaction.status !== 'PAYMENT_HELD') {
      throw new BadRequestError(`Transaction is not awaiting delivery (status: ${transaction.status})`);
    }

    const activeDispatch = await dispatchService.getDriverJobs(confirmedBy);
    const isAssignedDriver = activeDispatch.some((j) => j.transactionId === transaction.id && (j.status === 'ACCEPTED' || j.status === 'PENDING'));
    const isBuyer = transaction.buyerId === confirmedBy;

    if (!isBuyer && !isAssignedDriver) {
      throw new ForbiddenError('Only the buyer or assigned driver can confirm delivery');
    }

    const listing = await listingRepository.findById(transaction.listingId);
    if (!listing) throw new NotFoundError('Listing not found');
    if (listing.listingHash !== qrHash) {
      throw new BadRequestError('QR hash does not match this listing — cannot verify delivery');
    }

    return await prisma.$transaction(
      async (tx) => {
        await tx.qr_scans.create({
          data: {
            order_id: transaction.id,
            scanned_by: confirmedBy,
            scanned_hash: qrHash,
            hash_match: true,
          },
        });

        const updated = await this.repo.update(transaction.id, { status: 'RELEASED' });

        await auditService.log('DELIVERY_CONFIRMED', transaction.id, { qrHash, confirmedBy }, confirmedBy);
        await auditService.log('PAYMENT_RELEASED', transaction.id, { amountGhs: transaction.amountGhs }, confirmedBy);

        // Record transactional outbox event
        await outboxService.recordEvent(tx, 'ORDER', transaction.id, 'DELIVERY_CONFIRMED', {
          qrHash,
          confirmedBy,
          farmerId: transaction.farmerId,
          amountGhs: transaction.amountGhs,
        });

        await notificationService.sendNotification({
          userId: transaction.farmerId,
          type: 'DELIVERY_CONFIRMED_FARMER',
          message: `Delivery confirmed for Order #${transaction.id}! GHS ${transaction.amountGhs} has been released to your account.`,
          orderId: transaction.id,
        });

        await notificationService.sendNotification({
          userId: transaction.buyerId,
          type: 'DELIVERY_CONFIRMED_BUYER',
          message: `Delivery confirmed for Order #${transaction.id}. Thank you for using AgriConnect!`,
          orderId: transaction.id,
        });

        await dispatchService.markCompleted(transaction.id);

        return updated;
      },
      { timeout: 15000 },
    );
  }
}

export const transactionService = new TransactionService(transactionRepository);
