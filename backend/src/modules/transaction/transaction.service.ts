import { prisma } from '../../config/db';
import { BadRequestError, ConflictError, ForbiddenError, NotFoundError, PayoutNotConfiguredError } from '../../utils/errors';
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

    const { transaction } = await prisma.$transaction(
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

        // The buyer otherwise gets no confirmation their payment went
        // through at all until delivery is confirmed, which can be days
        // later — confirmDelivery() already notifies both sides, this makes
        // purchase() do the same instead of leaving the buyer half of it out.
        await notificationService.sendNotification({
          userId: buyerId,
          type: 'PURCHASE_CONFIRMED',
          message: `Your order for ${listing.quantityKg}kg of ${listing.cropType} is confirmed. GHS ${amountGhs} is held in escrow until delivery.`,
          listingId,
          orderId: transaction.id,
        });

        return { transaction };
      },
      { timeout: 15000 },
    );

    // Broadcasting to every eligible driver means writing and notifying
    // dozens of rows, not one — reproduced live taking 90+ seconds for ~22
    // candidates, which blew straight past this transaction's own 15s
    // timeout and rolled back the entire purchase. The order itself is
    // already durably committed by this point, so dispatch runs as a
    // best-effort step afterward instead of inside the same atomic block —
    // if it doesn't fully succeed, the driver-exhaustion admin-notify path
    // is the existing recovery route, same as it already was for the
    // single-driver case.
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

  /**
   * Only the buyer ever calls this — for a self-collect order they scan the
   * farmer's (static, per-listing) QR at pickup; for a driver-delivered
   * order they scan the (one-time, per-delivery) QR the driver generates by
   * tapping "Mark Delivered". Either way the code being checked only ever
   * reaches the buyer by being physically shown to them at the moment of
   * hand-off, so there's no path for the party handing the produce over to
   * confirm their own delivery.
   */
  async confirmDelivery(transactionId: string, code: string, confirmedBy: string): Promise<Transaction> {
    const transaction = await this.repo.findById(transactionId);
    if (!transaction) throw new NotFoundError('Transaction not found');
    if (transaction.buyerId !== confirmedBy) {
      throw new ForbiddenError('Only the buyer can confirm delivery');
    }

    if (transaction.hasOwnTransport) {
      if (transaction.status !== 'AWAITING_DRIVER') {
        throw new BadRequestError(`Order is not awaiting pickup confirmation (status: ${transaction.status})`);
      }
      const listing = await listingRepository.findById(transaction.listingId);
      if (!listing) throw new NotFoundError('Listing not found');
      if (listing.listingHash !== code) {
        throw new BadRequestError('QR code does not match this listing — cannot verify pickup');
      }
    } else {
      if (transaction.status !== 'DELIVERED_PENDING_CONFIRMATION') {
        throw new BadRequestError(`Order is not awaiting delivery confirmation yet (status: ${transaction.status})`);
      }
      const order = await prisma.orders.findUnique({ where: { id: transactionId } });
      const expired = !order?.delivery_code_expires_at || order.delivery_code_expires_at < new Date();
      if (!order?.delivery_code || order.delivery_code !== code || expired) {
        throw new BadRequestError('Delivery code is missing, incorrect, or expired — ask the driver to show their QR again');
      }
    }

    return this.releaseEscrow(transaction, confirmedBy, { scannedBy: confirmedBy, scannedHash: code });
  }

  /**
   * Called by DeliveryAutoReleaseWorker once a driver-delivered order's
   * confirmation window has passed with no buyer scan — protects the farmer
   * from a buyer who never gets around to confirming. Self-collect orders
   * are exempt: there's no driver leg to time out, and the buyer is already
   * standing at the farm gate when that QR gets scanned or it doesn't.
   */
  async autoReleaseIfExpired(transactionId: string): Promise<Transaction | null> {
    const transaction = await this.repo.findById(transactionId);
    if (!transaction || transaction.status !== 'DELIVERED_PENDING_CONFIRMATION') return null;

    const order = await prisma.orders.findUnique({ where: { id: transactionId } });
    if (!order?.delivery_code_expires_at || order.delivery_code_expires_at > new Date()) return null;

    return this.releaseEscrow(transaction, 'system-auto-release', null);
  }

  private async releaseEscrow(
    transaction: Transaction,
    confirmedBy: string,
    qrScan: { scannedBy: string; scannedHash: string } | null,
  ): Promise<Transaction> {
    const farmer = await userRepository.findById(transaction.farmerId);
    if (!farmer?.profile?.momoNumber || !farmer.profile.momoNetwork) {
      throw new PayoutNotConfiguredError('Cannot release payment — the farmer has not set up Mobile Money payout details');
    }

    const { transferCode } = await paymentService.initiateTransfer(
      farmer.profile.momoNumber,
      transaction.amountGhs,
      `Escrow release for order ${transaction.id}`,
      farmer.profile.momoNetwork,
    );

    return await prisma.$transaction(
      async (tx) => {
        if (qrScan) {
          await tx.qr_scans.create({
            data: {
              order_id: transaction.id,
              scanned_by: qrScan.scannedBy,
              scanned_hash: qrScan.scannedHash,
              hash_match: true,
            },
          });
        }

        const updated = await this.repo.update(transaction.id, { status: 'RELEASED', transferCode });

        await auditService.log('DELIVERY_CONFIRMED', transaction.id, { confirmedBy }, confirmedBy);
        await auditService.log('PAYMENT_RELEASED', transaction.id, { amountGhs: transaction.amountGhs }, confirmedBy);

        // Record transactional outbox event
        await outboxService.recordEvent(tx, 'ORDER', transaction.id, 'DELIVERY_CONFIRMED', {
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
