import bcrypt from 'bcryptjs';
import { BadRequestError, ConflictError, NotFoundError } from '../../utils/errors';
import { transactionRepository } from '../transaction/transaction.repository.prisma';
import { Transaction } from '../transaction/transaction.types';
import { IUserRepository } from '../user/user.repository';
import { userRepository } from '../user/user.repository.prisma';
import { SafeUser, toSafeUser } from '../user/user.types';
import { CreateAdminInput } from './admin.schema';

export class AdminService {
  constructor(private readonly users: IUserRepository) {}

  listTransactions(): Promise<Transaction[]> {
    return transactionRepository.findAll();
  }

  async listAdmins(): Promise<SafeUser[]> {
    const admins = await this.users.findManyByRole('admin');
    return admins.map(toSafeUser);
  }

  /**
   * Lets an existing admin add a colleague as a fellow admin — the only
   * way an admin account can be created outside the one-time local
   * bootstrap script, since "admin" was deliberately never a
   * self-service registration role.
   */
  async createAdmin(data: CreateAdminInput): Promise<SafeUser> {
    const existingEmail = await this.users.findByEmail(data.email);
    if (existingEmail) throw new ConflictError('Email already registered', 'EMAIL_ALREADY_REGISTERED');

    const existingPhone = await this.users.findByPhone(data.phone);
    if (existingPhone) throw new ConflictError('Phone number already registered', 'PHONE_ALREADY_REGISTERED');

    const passwordHash = await bcrypt.hash(data.password, 10);
    const user = await this.users.create({
      name: data.name,
      phone: data.phone,
      email: data.email,
      passwordHash,
      role: 'admin',
      otp: '',
      otpExpiry: new Date(),
    });
    // Admin-created admins are trusted immediately — no self-approval loop.
    const activated = await this.users.update(user.id, { status: 'ACTIVE' });
    return toSafeUser(activated);
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
