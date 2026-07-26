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
    const { fcmToken, platform, deviceId } = req.body;
    const updated = await userService.registerDeviceToken(user.userId, fcmToken, platform, deviceId);
    sendSuccess(res, updated);
  } catch (err) {
    next(err);
  }
};

export const removeDeviceTokenHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const user = (req as any).user;
    if (!user) throw new UnauthorizedError();
    await userService.removeDeviceToken(user.userId, req.body.fcmToken);
    sendSuccess(res, { message: 'Device token removed successfully' });
  } catch (err) {
    next(err);
  }
};
