import { Request, Response, NextFunction } from 'express';
import { UnauthorizedError } from '../../utils/errors';
import { sendSuccess } from '../../utils/response';
import { notificationService } from './notification.service';

export const getNotificationsHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const user = (req as any).user;
    if (!user) throw new UnauthorizedError();
    const notifications = await notificationService.getUserNotifications(user.userId);
    sendSuccess(res, { notifications });
  } catch (err) {
    next(err);
  }
};

export const markReadHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const user = (req as any).user;
    if (!user) throw new UnauthorizedError();
    const { id } = req.params;
    const success = await notificationService.markAsRead(id, user.userId);
    sendSuccess(res, { success });
  } catch (err) {
    next(err);
  }
};
