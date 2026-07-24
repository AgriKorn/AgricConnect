import { Request, Response, NextFunction } from 'express';
import { UnauthorizedError } from '../../utils/errors';
import { sendSuccess } from '../../utils/response';
import { userService } from './user.service';

export const getProfileHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const user = (req as any).user;
    if (!user) throw new UnauthorizedError();
    const profile = await userService.getProfile(user.userId);
    sendSuccess(res, profile);
  } catch (err) {
    next(err);
  }
};

export const updateProfileHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const user = (req as any).user;
    if (!user) throw new UnauthorizedError();
    const profile = await userService.updateProfile(user.userId, req.body);
    sendSuccess(res, profile);
  } catch (err) {
    next(err);
  }
};

export const registerDeviceTokenHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const user = (req as any).user;
    if (!user) throw new UnauthorizedError();
    const updated = await userService.registerDeviceToken(user.userId, req.body.fcmToken);
    sendSuccess(res, updated);
  } catch (err) {
    next(err);
  }
};
