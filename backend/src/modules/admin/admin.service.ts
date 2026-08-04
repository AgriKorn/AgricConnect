import bcrypt from 'bcryptjs';
import { BadRequestError, ConflictError, NotFoundError } from '../../utils/errors';
import { auditService } from '../audit/audit.service';
import { notificationService } from '../notification/notification.service';
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
  async createAdmin(data: CreateAdminInput, createdBy: string): Promise<SafeUser> {
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
    await auditService.log('ADMIN_CREATED' as any, user.id, { name: data.name, email: data.email }, createdBy);
    return toSafeUser(activated);
  }

  /**
   * Revokes admin access rather than deleting the row outright — a hard
   * delete risks foreign-key fallout (audit trail entries this admin wrote,
   * MOFA price references they authored, users they approved via
   * approved_by) and can't be undone if the wrong person is removed.
   * REJECTED already blocks login everywhere else in the codebase, so this
   * reuses that instead of inventing a second "disabled" concept.
   */
  async removeAdmin(adminId: string, requestingAdminId: string): Promise<SafeUser> {
    if (adminId === requestingAdminId) {
      throw new BadRequestError('You cannot remove your own admin access');
    }

    const admin = await this.users.findById(adminId);
    if (!admin) throw new NotFoundError('Admin not found');
    if (admin.role !== 'admin') throw new BadRequestError('That account is not an admin');

    const allAdmins = await this.users.findManyByRole('admin');
    const remainingActive = allAdmins.filter((a) => a.id !== adminId && a.status === 'ACTIVE');
    if (remainingActive.length === 0) {
      throw new BadRequestError('Cannot remove the last remaining admin — it would lock everyone out');
    }

    const updated = await this.users.update(adminId, { status: 'REJECTED', refreshToken: null });
    await auditService.log('ADMIN_REMOVED' as any, adminId, { removedAdminName: admin.name }, requestingAdminId);
    return toSafeUser(updated);
  }

  async listPendingUsers(): Promise<SafeUser[]> {
    const users = await this.users.findManyByStatus('PENDING_APPROVAL');
    return users.map(toSafeUser);
  }

  async approveUser(userId: string, approvedBy: string): Promise<SafeUser> {
    const user = await this.assertPending(userId);
    const updated = await this.users.update(user.id, { status: 'ACTIVE', approvedBy, approvedAt: new Date() });
    await auditService.log('USER_APPROVED' as any, user.id, { role: user.role }, approvedBy);
    await notificationService.sendNotification({
      userId: user.id,
      type: 'ACCOUNT_APPROVED',
      message: 'Your account has been approved. You can now sign in and use AgriConnect.',
    });
    return toSafeUser(updated);
  }

  async rejectUser(userId: string, rejectedBy: string): Promise<SafeUser> {
    const user = await this.assertPending(userId);
    const updated = await this.users.update(user.id, { status: 'REJECTED', approvedBy: rejectedBy, approvedAt: new Date() });
    await auditService.log('USER_REJECTED' as any, user.id, { role: user.role }, rejectedBy);
    await notificationService.sendNotification({
      userId: user.id,
      type: 'ACCOUNT_REJECTED',
      message: 'Your account application was not approved. Contact support if you believe this is a mistake.',
    });
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
