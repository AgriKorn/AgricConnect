import { prisma } from '../../config/db';
import { ConflictError, ForbiddenError, NotFoundError } from '../../utils/errors';
import { auditService } from '../audit/audit.service';
import { notificationService } from '../notification/notification.service';
import { transactionRepository } from '../transaction/transaction.repository.prisma';
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

  async resolve(id: string, resolution: string, action: 'REFUND_BUYER' | 'RELEASE_FARMER' = 'REFUND_BUYER'): Promise<Dispute> {
    const dispute = await this.repo.findById(id);
    if (!dispute) throw new NotFoundError('Dispute not found');
    if (dispute.status === 'RESOLVED') throw new ConflictError('Dispute has already been resolved');

    const transaction = await transactionRepository.findById(dispute.transactionId);
    if (!transaction) throw new NotFoundError('Transaction not found for dispute');

    return await prisma.$transaction(
      async (tx) => {
        // 1. Resolve dispute record
        const resolved = await this.repo.resolve(id, `${resolution} [Action: ${action}]`);

        // 2. Perform financial escrow resolution
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
          await transactionRepository.update(transaction.id, { status: 'RELEASED' });
          await notificationService.sendNotification({
            userId: transaction.farmerId,
            type: 'DISPUTE_RESOLVED_RELEASE',
            message: `Dispute on Order #${transaction.id} resolved: Escrow funds of GHS ${transaction.amountGhs} released to your account.`,
            orderId: transaction.id,
          });
        }

        await auditService.log('DISPUTE_RESOLVED' as any, transaction.id, { disputeId: id, action, resolution }, 'ADMIN');

        return resolved;
      },
      { timeout: 15000 },
    );
  }
}

export const disputeService = new DisputeService(disputeRepository);
