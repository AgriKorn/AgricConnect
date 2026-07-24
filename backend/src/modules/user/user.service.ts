import { NotFoundError } from '../../utils/errors';
import { IUserRepository } from './user.repository';
import { userRepository } from './user.repository.memory';
import { SafeUser, toSafeUser } from './user.types';
import { UpdateProfileInput } from './user.schema';

export class UserService {
  constructor(private readonly users: IUserRepository) {}

  async getProfile(userId: string): Promise<SafeUser> {
    const user = await this.users.findById(userId);
    if (!user) throw new NotFoundError('User not found');
    return toSafeUser(user);
  }

  async updateProfile(userId: string, data: UpdateProfileInput): Promise<SafeUser> {
    const { name, ...profileFields } = data;
    if (name) await this.users.update(userId, { name });
    const updated = await this.users.updateProfile(userId, profileFields);
    return toSafeUser(updated);
  }

  async registerDeviceToken(userId: string, fcmToken: string): Promise<SafeUser> {
    const updated = await this.users.updateFcmToken(userId, fcmToken);
    return toSafeUser(updated);
  }
}

export const userService = new UserService(userRepository);
