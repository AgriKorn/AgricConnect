import { Request, Response, NextFunction } from 'express';
import { sendSuccess } from '../../utils/response';
import { disputeService } from '../dispute/dispute.service';
import { adminService } from './admin.service';

import { auditService } from '../audit/audit.service';

export const listAdminsHandler = async (_req: Request, res: Response, next: NextFunction) => {
  try {
    const admins = await adminService.listAdmins();
    sendSuccess(res, { admins, count: admins.length });
  } catch (err) {
    next(err);
  }
};

export const createAdminHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const admin = await adminService.createAdmin(req.body);
    sendSuccess(res, admin, 201);
  } catch (err) {
    next(err);
  }
};

export const removeAdminHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const requestingAdminId = (req as any).user.userId;
    const admin = await adminService.removeAdmin(req.params.id, requestingAdminId);
    sendSuccess(res, admin);
  } catch (err) {
    next(err);
  }
};

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
    const action = req.body.action || 'REFUND_BUYER';
    const dispute = await disputeService.resolve(req.params.id, req.body.resolution, action);
    sendSuccess(res, dispute);
  } catch (err) {
    next(err);
  }
};

export const getAuditLogsHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { eventType, entityType, actorId, startDate, endDate, page, limit } = req.query as any;
    const result = await auditService.searchAuditLogs({
      eventType,
      entityType,
      actorId,
      startDate: startDate ? new Date(startDate) : undefined,
      endDate: endDate ? new Date(endDate) : undefined,
      page: page ? parseInt(page, 10) : 1,
      limit: limit ? Math.min(parseInt(limit, 10), 50) : 20,
    });
    sendSuccess(res, result);
  } catch (err) {
    next(err);
  }
};
