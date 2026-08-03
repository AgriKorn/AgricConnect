import { NotFoundError } from '../../utils/errors';
import { s3Service, PresignedUploadUrlResult } from '../../services/s3.service';
import { IUserRepository } from './user.repository';
import { userRepository } from './user.repository.prisma';
import { SafeUser, toSafeUser } from './user.types';
import { UpdateProfileInput } from './user.schema';

export class UserService {
  constructor(private readonly users: IUserRepository) {}

  /** Presigned S3 PUT URL for a profile photo — the client uploads directly to
   * S3, then confirms via PATCH /profile { photoUrl: publicUrl } once the
   * upload succeeds. Nothing is persisted here.
   */
  getPhotoUploadUrl(fileName: string, contentType: string): Promise<PresignedUploadUrlResult> {
    return s3Service.generatePublicUploadUrl(fileName, contentType);
  }

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

  async registerDeviceToken(userId: string, fcmToken: string, platform?: string, deviceId?: string): Promise<SafeUser> {
    await this.users.registerDeviceToken(userId, fcmToken, platform, deviceId);
    const user = await this.users.findById(userId);
    if (!user) throw new NotFoundError('User not found');
    return toSafeUser(user);
  }

  async removeDeviceToken(userId: string, fcmToken: string): Promise<void> {
    await this.users.removeDeviceToken(userId, fcmToken);
  }
}

export const userService = new UserService(userRepository);
