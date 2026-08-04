import { User, UserRole, UserStatus } from './user.types';

export type CreateUserRecord = Pick<User, 'name' | 'phone' | 'passwordHash' | 'role'> & {
  otp: string;
  otpExpiry: Date;
  email?: string | null;
  // Collected at registration for the roles that need them — silently
  // dropped before this was wired up (see registerSchema): every farmer
  // and driver defaulted to a hardcoded region regardless of what they
  // picked, and buyer business info had nowhere to be stored at all.
  region?: string;
  businessName?: string;
  businessType?: string;
  operatingRegion?: string;
  vehicleCapacityKg?: number;
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
