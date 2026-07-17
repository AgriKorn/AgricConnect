import { User, UserStatus } from './user.types';

export type CreateUserRecord = Pick<User, 'name' | 'phone' | 'passwordHash' | 'role'> & {
  otp: string;
  otpExpiry: Date;
};

export interface IUserRepository {
  create(data: CreateUserRecord): Promise<User>;
  findByPhone(phone: string): Promise<User | null>;
  findById(id: string): Promise<User | null>;
  findManyByStatus(status: UserStatus): Promise<User[]>;
  findFarmerIdsByRegion(region: string): Promise<string[]>;
  update(id: string, data: Partial<User>): Promise<User>;
  updateProfile(id: string, profile: Partial<User['profile']>): Promise<User>;
}
