import { prisma } from '../../config/db';

export interface NotificationRecord {
  id: string;
  userId: string;
  orderId?: string | null;
  listingId?: string | null;
  type: string;
  message: string;
  isRead: boolean;
  createdAt: Date;
}

export class NotificationRepository {
  async create(data: { userId: string; type: string; message: string; orderId?: string; listingId?: string }): Promise<NotificationRecord> {
    const created = await prisma.notifications.create({
      data: {
        user_id: data.userId,
        type: data.type,
        message: data.message,
        order_id: data.orderId || null,
        listing_id: data.listingId || null,
      },
    });
    return {
      id: created.id,
      userId: created.user_id,
      orderId: created.order_id,
      listingId: created.listing_id,
      type: created.type,
      message: created.message,
      isRead: created.is_read,
      createdAt: created.created_at,
    };
  }

  async findForUser(userId: string): Promise<NotificationRecord[]> {
    const list = await prisma.notifications.findMany({
      where: { user_id: userId },
      orderBy: { created_at: 'desc' },
      take: 50,
    });
    return list.map((n) => ({
      id: n.id,
      userId: n.user_id,
      orderId: n.order_id,
      listingId: n.listing_id,
      type: n.type,
      message: n.message,
      isRead: n.is_read,
      createdAt: n.created_at,
    }));
  }

  /**
   * Whether a notification of this type already exists for a listing. The
   * freshness monitor uses it to alert a farmer only once per listing, rather
   * than on every poll once the crossing condition holds.
   */
  async existsForListingAndType(listingId: string, type: string): Promise<boolean> {
    const found = await prisma.notifications.findFirst({
      where: { listing_id: listingId, type },
      select: { id: true },
    });
    return found !== null;
  }

  async markAsRead(id: string, userId: string): Promise<boolean> {
    const result = await prisma.notifications.updateMany({
      where: { id, user_id: userId },
      data: { is_read: true },
    });
    return result.count > 0;
  }
}

export const notificationRepository = new NotificationRepository();
