import { User, UserRole, UserStatus } from './user.types';

export type CreateUserRecord = Pick<User, 'name' | 'phone' | 'passwordHash' | 'role'> & {
  otp: string;
  otpExpiry: Date;
  email?: string | null;
};

export interface IUserRepository {
  create(data: CreateUserRecord): Promise<User>;
  findByPhone(phone: string): Promise<User | null>;
  findByEmail(email: string): Promise<User | null>;
  findById(id: string): Promise<User | null>;
  findManyByStatus(status: UserStatus): Promise<User[]>;
  findManyByRole(role: UserRole): Promise<User[]>;
  findFarmerIdsByRegion(region: string): Promise<string[]>;
  findAvailableDrivers(minCapacityKg: number, excludeIds: string[]): Promise<User[]>;
  update(id: string, data: Partial<User>): Promise<User>;
  updateProfile(id: string, profile: Partial<User['profile']>): Promise<User>;
  updateFcmToken(id: string, fcmToken: string): Promise<User>;
  registerDeviceToken(userId: string, token: string, platform?: string, deviceId?: string): Promise<void>;
  removeDeviceToken(userId: string, token: string): Promise<void>;
  findActiveDeviceTokens(userId: string): Promise<string[]>;
  deactivateDeviceToken(token: string): Promise<void>;
}
