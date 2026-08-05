import { prisma } from '../../config/db';
import { paymentService } from '../../services/payment.service';
import { ConflictError, ForbiddenError, NotFoundError, PayoutNotConfiguredError } from '../../utils/errors';
import { auditService } from '../audit/audit.service';
import { notificationService } from '../notification/notification.service';
import { transactionRepository } from '../transaction/transaction.repository.prisma';
import { isActiveStatus } from '../transaction/transaction.types';
import { userRepository } from '../user/user.repository.prisma';
import { disputeRepository, PrismaDisputeRepository } from './dispute.repository.prisma';
import { Dispute, DisputeType } from './dispute.types';

export class DisputeService {
  constructor(private readonly repo: PrismaDisputeRepository) {}

  async raise(transactionId: string, type: DisputeType, description: string, raisedBy: string): Promise<Dispute> {
    const transaction = await transactionRepository.findById(transactionId);
    if (!transaction) throw new NotFoundError('Transaction not found');
    if (transaction.buyerId !== raisedBy && transaction.farmerId !== raisedBy) {
      throw new ForbiddenError('You are not a participant in this transaction');
    }
    if (!isActiveStatus(transaction.status)) {
      throw new ConflictError(`Cannot raise a dispute on an order that is ${transaction.status.toLowerCase()}`);
    }
    const existingOpen = await this.repo.findOpenByTransaction(transactionId);
    if (existingOpen) {
      throw new ConflictError('This order already has an open dispute');
    }

    const dispute = await this.repo.create({ transactionId, raisedBy, type, description });
    await auditService.log('DISPUTE_RAISED' as any, transactionId, { disputeId: dispute.id, type, description }, raisedBy);

    await notificationService.sendNotification({
      userId: transaction.farmerId === raisedBy ? transaction.buyerId : transaction.farmerId,
      type: 'DISPUTE_RAISED',
      message: `A dispute was raised on Order #${transaction.id}: ${description}`,
      orderId: transaction.id,
    });

    return dispute;
  }

  listAll(): Promise<Dispute[]> {
    return this.repo.findAll();
  }

  async resolve(
    id: string,
    resolution: string,
    action: 'REFUND_BUYER' | 'RELEASE_FARMER' = 'REFUND_BUYER',
    resolvedBy: string,
  ): Promise<Dispute> {
    const dispute = await this.repo.findById(id);
    if (!dispute) throw new NotFoundError('Dispute not found');
    if (dispute.status === 'RESOLVED') throw new ConflictError('Dispute has already been resolved');

    const transaction = await transactionRepository.findById(dispute.transactionId);
    if (!transaction) throw new NotFoundError('Transaction not found for dispute');

    // Escrow money actually has to move here — a dispute resolution is not
    // just a status label. Mirrors confirmDelivery's real-money-first order:
    // call Paystack before touching the DB, so a failed transfer/refund never
    // leaves the order in a state that claims funds moved when they didn't.
    let transferCode: string | undefined;
    if (action === 'REFUND_BUYER') {
      await paymentService.refundTransaction(transaction.paymentReference, transaction.amountGhs);
    } else {
      const farmer = await userRepository.findById(transaction.farmerId);
      if (!farmer?.profile?.momoNumber || !farmer.profile.momoNetwork) {
        throw new PayoutNotConfiguredError('Cannot release payment — the farmer has not set up Mobile Money payout details');
      }
      const transfer = await paymentService.initiateTransfer(
        farmer.profile.momoNumber,
        transaction.amountGhs,
        `Dispute resolution escrow release for order ${transaction.id}`,
        farmer.profile.momoNetwork,
      );
      transferCode = transfer.transferCode;
    }

    return await prisma.$transaction(
      async (tx) => {
        // 1. Resolve dispute record
        const resolved = await this.repo.resolve(id, `${resolution} [Action: ${action}]`, resolvedBy);

        // 2. Reflect the now-real financial outcome on the transaction record
        if (action === 'REFUND_BUYER') {
          await transactionRepository.update(transaction.id, { status: 'CANCELLED' });
          // Re-enable produce listing for sale if refunded
          await tx.produce_listings.update({
            where: { id: transaction.listingId },
            data: { status: 'active' },
          });

          await notificationService.sendNotification({
            userId: transaction.buyerId,
            type: 'DISPUTE_RESOLVED_REFUND',
            message: `Dispute on Order #${transaction.id} resolved: Full refund of GHS ${transaction.amountGhs} issued.`,
            orderId: transaction.id,
          });
        } else {
          await transactionRepository.update(transaction.id, { status: 'RELEASED', transferCode });
          await notificationService.sendNotification({
            userId: transaction.farmerId,
            type: 'DISPUTE_RESOLVED_RELEASE',
            message: `Dispute on Order #${transaction.id} resolved: Escrow funds of GHS ${transaction.amountGhs} released to your account.`,
            orderId: transaction.id,
          });
        }

        await auditService.log('DISPUTE_RESOLVED' as any, transaction.id, { disputeId: id, action, resolution }, resolvedBy);

        return resolved;
      },
      { timeout: 15000 },
    );
  }
}

export const disputeService = new DisputeService(disputeRepository);
