import { notificationRepository, NotificationRepository } from './notification.repository.prisma';

export class NotificationService {
  constructor(private readonly repo: NotificationRepository = notificationRepository) {}

  async sendNotification(data: { userId: string; type: string; message: string; orderId?: string; listingId?: string }) {
    return await this.repo.create(data);
  }

  async getUserNotifications(userId: string) {
    return await this.repo.findForUser(userId);
  }

  async markAsRead(id: string, userId: string) {
    return await this.repo.markAsRead(id, userId);
  }
}

export const notificationService = new NotificationService();
