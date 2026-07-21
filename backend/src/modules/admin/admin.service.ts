import { BadRequestError, NotFoundError } from '../../utils/errors';
import { transactionRepository } from '../transaction/transaction.repository.memory';
import { Transaction } from '../transaction/transaction.types';
import { IUserRepository } from '../user/user.repository';
import { userRepository } from '../user/user.repository.memory';
import { SafeUser, toSafeUser } from '../user/user.types';

export class AdminService {
  constructor(private readonly users: IUserRepository) {}

  listTransactions(): Promise<Transaction[]> {
    return transactionRepository.findAll();
  }

  async listPendingUsers(): Promise<SafeUser[]> {
    const users = await this.users.findManyByStatus('PENDING_APPROVAL');
    return users.map(toSafeUser);
  }

  async approveUser(userId: string): Promise<SafeUser> {
    const user = await this.assertPending(userId);
    const updated = await this.users.update(user.id, { status: 'ACTIVE' });
    return toSafeUser(updated);
  }

  async rejectUser(userId: string): Promise<SafeUser> {
    const user = await this.assertPending(userId);
    const updated = await this.users.update(user.id, { status: 'REJECTED' });
    return toSafeUser(updated);
  }

  private async assertPending(userId: string) {
    const user = await this.users.findById(userId);
    if (!user) throw new NotFoundError('User not found');
    if (user.status !== 'PENDING_APPROVAL') {
      throw new BadRequestError(`User is not pending approval (current status: ${user.status})`);
    }
    return user;
  }
}

export const adminService = new AdminService(userRepository);
