import { ForbiddenError, NotFoundError } from '../../utils/errors';
import { transactionRepository } from '../transaction/transaction.repository.memory';
import { IDisputeRepository } from './dispute.repository';
import { disputeRepository } from './dispute.repository.memory';
import { Dispute, DisputeType } from './dispute.types';

export class DisputeService {
  constructor(private readonly repo: IDisputeRepository) {}

  async raise(transactionId: string, type: DisputeType, description: string, raisedBy: string): Promise<Dispute> {
    const transaction = await transactionRepository.findById(transactionId);
    if (!transaction) throw new NotFoundError('Transaction not found');
    if (transaction.buyerId !== raisedBy && transaction.farmerId !== raisedBy) {
      throw new ForbiddenError('You are not a participant in this transaction');
    }
    return this.repo.create({ transactionId, raisedBy, type, description });
  }

  listAll(): Promise<Dispute[]> {
    return this.repo.findAll();
  }

  resolve(id: string, resolution: string): Promise<Dispute> {
    return this.repo.resolve(id, resolution);
  }
}

export const disputeService = new DisputeService(disputeRepository);
