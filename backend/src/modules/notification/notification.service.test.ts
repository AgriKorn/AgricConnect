import { NotificationService } from './notification.service';
import { NotificationRepository } from './notification.repository.prisma';

describe('NotificationService', () => {
  let notificationService: NotificationService;
  let mockRepo: jest.Mocked<NotificationRepository>;

  beforeEach(() => {
    mockRepo = {
      create: jest.fn(),
      findForUser: jest.fn(),
      markAsRead: jest.fn(),
    } as any;

    notificationService = new NotificationService(mockRepo);
  });

  describe('sendNotification', () => {
    it('should format payload and call repository create', async () => {
      const mockCreated = {
        id: 'notif-1',
        userId: 'user-123',
        type: 'LISTING_PURCHASED',
        message: 'Your item was purchased',
        isRead: false,
        createdAt: new Date(),
      };
      mockRepo.create.mockResolvedValue(mockCreated);

      const result = await notificationService.sendNotification({
        userId: 'user-123',
        type: 'LISTING_PURCHASED',
        message: 'Your item was purchased',
        orderId: 'order-99',
      });

      expect(mockRepo.create).toHaveBeenCalledWith(
        expect.objectContaining({
          userId: 'user-123',
          type: 'LISTING_PURCHASED',
          message: 'Your item was purchased',
        }),
      );
      expect(result).toEqual(mockCreated);
    });
  });

  describe('getUserNotifications', () => {
    it('should return unread notifications for specified user', async () => {
      const notifications = [
        { id: '1', userId: 'user-1', type: 'TEST', message: 'Hello', isRead: false, createdAt: new Date() },
      ];
      mockRepo.findForUser.mockResolvedValue(notifications);

      const result = await notificationService.getUserNotifications('user-1');

      expect(mockRepo.findForUser).toHaveBeenCalledWith('user-1');
      expect(result).toEqual(notifications);
    });
  });

  describe('markAsRead', () => {
    it('should call repo markAsRead and return success status', async () => {
      mockRepo.markAsRead.mockResolvedValue(true);

      const result = await notificationService.markAsRead('notif-1', 'user-1');

      expect(mockRepo.markAsRead).toHaveBeenCalledWith('notif-1', 'user-1');
      expect(result).toBe(true);
    });
  });
});
