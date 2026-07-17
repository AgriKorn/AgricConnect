import { Request, Response, NextFunction } from 'express';
import { sendSuccess } from '../../utils/response';
import { adminService } from './admin.service';

export const listPendingUsersHandler = async (_req: Request, res: Response, next: NextFunction) => {
  try {
    const users = await adminService.listPendingUsers();
    sendSuccess(res, { users, count: users.length });
  } catch (err) {
    next(err);
  }
};

export const approveUserHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const user = await adminService.approveUser(req.params.id);
    sendSuccess(res, user);
  } catch (err) {
    next(err);
  }
};

export const rejectUserHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const user = await adminService.rejectUser(req.params.id);
    sendSuccess(res, user);
  } catch (err) {
    next(err);
  }
};
