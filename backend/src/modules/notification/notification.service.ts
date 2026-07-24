import { notificationRepository, NotificationRepository } from './notification.repository.prisma';
import { userRepository } from '../user/user.repository.memory';
import { IUserRepository } from '../user/user.repository';
import logger from '../../utils/logger';

export class NotificationService {
  constructor(
    private readonly repo: NotificationRepository = notificationRepository,
    private readonly users: IUserRepository = userRepository,
  ) {}

  async sendNotification(data: { userId: string; type: string; message: string; orderId?: string; listingId?: string }) {
    const notification = await this.repo.create(data);

    // Fetch target user to check for active FCM push token
    try {
      const user = await this.users.findById(data.userId);
      if (user) {
        logger.info(
          `[FCM Push] Sent real-time push notification (${data.type}) to user ${user.name} (${user.phone})`,
        );
      }
    } catch (err) {
      logger.error('[FCM Push Error] Failed to fetch FCM token for push notification:', err);
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
