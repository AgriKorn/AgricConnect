import { Request, Response, NextFunction } from 'express';
import { UnauthorizedError } from '../../utils/errors';
import { sendSuccess } from '../../utils/response';
import { transactionService } from './transaction.service';

export const purchaseHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const user = (req as any).user;
    if (!user) throw new UnauthorizedError();
    const { listingId, hasOwnTransport } = req.body;
    const result = await transactionService.purchase(listingId, user.userId, hasOwnTransport);
    sendSuccess(res, result, 201);
  } catch (err) {
    next(err);
  }
};

export const getMyTransactionsHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const user = (req as any).user;
    if (!user) throw new UnauthorizedError();
    const transactions = await transactionService.getMyTransactions(user.userId);
    sendSuccess(res, { transactions, count: transactions.length });
  } catch (err) {
    next(err);
  }
};

export const getTransactionHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const user = (req as any).user;
    if (!user) throw new UnauthorizedError();
    const transaction = await transactionService.getTransaction(req.params.id, user.userId, user.role);
    sendSuccess(res, transaction);
  } catch (err) {
    next(err);
  }
};

export const confirmDeliveryHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const user = (req as any).user;
    if (!user) throw new UnauthorizedError();
    const transaction = await transactionService.confirmDelivery(req.params.id, req.body.qrHash, user.userId);
    sendSuccess(res, transaction);
  } catch (err) {
    next(err);
  }
};
