import { Request, Response, NextFunction } from 'express';
import { UnauthorizedError } from '../../utils/errors';
import { sendSuccess } from '../../utils/response';
import { userService } from './user.service';

export const getProfileHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    if (!req.user) throw new UnauthorizedError();
    const profile = await userService.getProfile(req.user.userId);
    sendSuccess(res, profile);
  } catch (err) {
    next(err);
  }
};

export const updateProfileHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    if (!req.user) throw new UnauthorizedError();
    const profile = await userService.updateProfile(req.user.userId, req.body);
    sendSuccess(res, profile);
  } catch (err) {
    next(err);
  }
};
