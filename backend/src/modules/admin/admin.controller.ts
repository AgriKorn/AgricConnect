import { Request, Response, NextFunction } from 'express';
import { sendSuccess } from '../../utils/response';
import { disputeService } from '../dispute/dispute.service';
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

export const listTransactionsHandler = async (_req: Request, res: Response, next: NextFunction) => {
  try {
    const transactions = await adminService.listTransactions();
    sendSuccess(res, { transactions, count: transactions.length });
  } catch (err) {
    next(err);
  }
};

export const listDisputesHandler = async (_req: Request, res: Response, next: NextFunction) => {
  try {
    const disputes = await disputeService.listAll();
    sendSuccess(res, { disputes, count: disputes.length });
  } catch (err) {
    next(err);
  }
};

export const resolveDisputeHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const dispute = await disputeService.resolve(req.params.id, req.body.resolution);
    sendSuccess(res, dispute);
  } catch (err) {
    next(err);
  }
};
