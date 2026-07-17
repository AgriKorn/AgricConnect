import { randomUUID } from 'crypto';
import { NotFoundError } from '../../utils/errors';
import { User, UserStatus } from './user.types';
import { CreateUserRecord, IUserRepository } from './user.repository';

/**
 * Temporary in-memory store standing in for the Prisma-backed repository.
 * Swap this for a PrismaUserRepository once schema.prisma exists (K3/K4) —
 * every module here only depends on IUserRepository, so nothing else changes.
 */
export class InMemoryUserRepository implements IUserRepository {
  private readonly usersById = new Map<string, User>();
  private readonly idByPhone = new Map<string, string>();

  async create(data: CreateUserRecord): Promise<User> {
    const now = new Date();
    const user: User = {
      id: randomUUID(),
      name: data.name,
      phone: data.phone,
      passwordHash: data.passwordHash,
      role: data.role,
      status: 'PENDING_OTP',
      otp: data.otp,
      otpExpiry: data.otpExpiry,
      refreshToken: null,
      profile: {},
      createdAt: now,
      updatedAt: now,
    };
    this.usersById.set(user.id, user);
    this.idByPhone.set(user.phone, user.id);
    return user;
  }

  async findByPhone(phone: string): Promise<User | null> {
    const id = this.idByPhone.get(phone);
    return id ? this.usersById.get(id) ?? null : null;
  }

  async findById(id: string): Promise<User | null> {
    return this.usersById.get(id) ?? null;
  }

  async findManyByStatus(status: UserStatus): Promise<User[]> {
    return [...this.usersById.values()]
      .filter((user) => user.status === status)
      .sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime());
  }

  async findFarmerIdsByRegion(region: string): Promise<string[]> {
    return [...this.usersById.values()]
      .filter((user) => user.role === 'farmer' && user.profile.farmRegion?.toLowerCase() === region.toLowerCase())
      .map((user) => user.id);
  }

  async update(id: string, data: Partial<User>): Promise<User> {
    const existing = this.usersById.get(id);
    if (!existing) throw new NotFoundError('User not found');
    const updated: User = { ...existing, ...data, updatedAt: new Date() };
    this.usersById.set(id, updated);
    return updated;
  }

  async updateProfile(id: string, profile: Partial<User['profile']>): Promise<User> {
    const existing = this.usersById.get(id);
    if (!existing) throw new NotFoundError('User not found');
    const updated: User = { ...existing, profile: { ...existing.profile, ...profile }, updatedAt: new Date() };
    this.usersById.set(id, updated);
    return updated;
  }
}

// Shared singleton — auth, user profile, and admin modules all read/write the same store.
export const userRepository = new InMemoryUserRepository();
