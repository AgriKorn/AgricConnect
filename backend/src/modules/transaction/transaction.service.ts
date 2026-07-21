import { BadRequestError, ConflictError, ForbiddenError, NotFoundError } from '../../utils/errors';
import { auditService } from '../audit/audit.service';
import { DriverJob } from '../dispatch/dispatch.types';
import { dispatchService } from '../dispatch/dispatch.service';
import { paymentService } from '../../services/payment.service';
import { listingRepository } from '../listing/listing.repository.memory';
import { userRepository } from '../user/user.repository.memory';
import { ITransactionRepository } from './transaction.repository';
import { transactionRepository } from './transaction.repository.memory';
import { Transaction } from './transaction.types';

export interface PurchaseResult {
  transaction: Transaction;
  dispatch: DriverJob | null;
}

export class TransactionService {
  constructor(private readonly repo: ITransactionRepository) {}

  async purchase(listingId: string, buyerId: string, hasOwnTransport: boolean): Promise<PurchaseResult> {
    const listing = await listingRepository.findById(listingId);
    if (!listing || listing.status !== 'ACTIVE') throw new NotFoundError('Listing not found or no longer active');
    if (listing.farmerId === buyerId) throw new BadRequestError('You cannot purchase your own listing');

    const existingActive = await this.repo.findActiveByListingId(listingId);
    if (existingActive) throw new ConflictError('This listing already has a purchase in progress');

    const amountGhs = listing.pricePerKg * listing.quantityKg;
    const buyer = await userRepository.findById(buyerId);
    const { reference } = await paymentService.initializeTransaction(amountGhs, buyer?.phone ?? 'unknown', { listingId });

    // Take the listing off the market immediately — otherwise a second
    // buyer could purchase the same produce while this one is in escrow.
    await listingRepository.markSold(listingId);

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

    let dispatch: DriverJob | null = null;
    if (!hasOwnTransport) {
      dispatch = await dispatchService.assignDriver({
        transactionId: transaction.id,
        listingId,
        cropType: listing.cropType,
        quantityKg: listing.quantityKg,
      });
    }

    return { transaction, dispatch };
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

    const listing = await listingRepository.findById(transaction.listingId);
    if (!listing) throw new NotFoundError('Listing not found');
    if (listing.listingHash !== qrHash) {
      throw new BadRequestError('QR hash does not match this listing — cannot verify delivery');
    }

    const farmer = await userRepository.findById(transaction.farmerId);
    const { transferCode } = await paymentService.initiateTransfer(
      farmer?.phone ?? 'unknown',
      transaction.amountGhs,
      `AgriConnect delivery ${transaction.id}`,
    );

    const updated = await this.repo.update(transaction.id, { status: 'RELEASED', transferCode });

    await auditService.log('DELIVERY_CONFIRMED', transaction.id, { qrHash, confirmedBy }, confirmedBy);
    await auditService.log('PAYMENT_RELEASED', transaction.id, { amountGhs: transaction.amountGhs, transferCode }, confirmedBy);

    await dispatchService.markCompleted(transaction.id);

    return updated;
  }
}

export const transactionService = new TransactionService(transactionRepository);
