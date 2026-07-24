import { notificationRepository, NotificationRepository } from './notification.repository.prisma';
import { userRepository } from '../user/user.repository.prisma';
import { IUserRepository } from '../user/user.repository';
import logger from '../../utils/logger';

export class NotificationService {
  constructor(
    private readonly repo: NotificationRepository = notificationRepository,
    private readonly users: IUserRepository = userRepository,
  ) {}

  async sendNotification(data: { userId: string; type: string; message: string; orderId?: string; listingId?: string }) {
    const notification = await this.repo.create(data);

    // Fetch target user's active device tokens for FCM push dispatch
    try {
      const activeTokens = await this.users.findActiveDeviceTokens(data.userId);
      if (activeTokens.length > 0) {
        logger.info(
          `[FCM Push] Dispatched real-time push notification (${data.type}) to ${activeTokens.length} active device(s) for user ${data.userId}`,
        );
      }
    } catch (err) {
      logger.error('[FCM Push Error] Failed to fetch active device tokens:', err);
    }

    return notification;
  }

  async getUserNotifications(userId: string) {
    return await this.repo.findForUser(userId);
  }

  async markAsRead(id: string, userId: string) {
    return await this.repo.markAsRead(id, userId);
  }
}

export const notificationService = new NotificationService();
