import { notificationRepository, NotificationRepository } from './notification.repository.prisma';
import { userRepository } from '../user/user.repository.prisma';
import { IUserRepository } from '../user/user.repository';
import logger from '../../utils/logger';

export class NotificationService {
  constructor(
    private readonly repo: NotificationRepository = notificationRepository,
    private readonly users: IUserRepository = userRepository,
  ) {}

  // Device tokens are captured (POST /users/device-token) and stored ready for
  // this, but there is no FCM/APNs integration wired up yet — no push SDK is
  // installed on either side. This persists the in-app notification (which
  // the Farmer Alerts screen reads) and stops there. Do not log this as a
  // dispatched push: that previously logged a fabricated "Dispatched
  // real-time push notification" line even though nothing was sent.
  async sendNotification(data: { userId: string; type: string; message: string; orderId?: string; listingId?: string }) {
    const notification = await this.repo.create(data);

    try {
      const activeTokens = await this.users.findActiveDeviceTokens(data.userId);
      if (activeTokens.length > 0) {
        logger.info(
          `[Notification] Persisted (${data.type}) for user ${data.userId}; ${activeTokens.length} device token(s) on file but push delivery is not yet implemented — in-app only.`,
        );
      }
    } catch (err) {
      logger.error('[Notification] Failed to look up active device tokens:', err);
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
