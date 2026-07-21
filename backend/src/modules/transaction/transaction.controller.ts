import { Request, Response, NextFunction } from 'express';
import { UnauthorizedError } from '../../utils/errors';
import { sendSuccess } from '../../utils/response';
import { transactionService } from './transaction.service';

export const purchaseHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    if (!req.user) throw new UnauthorizedError();
    const { listingId, hasOwnTransport } = req.body;
    const result = await transactionService.purchase(listingId, req.user.userId, hasOwnTransport);
    sendSuccess(res, result, 201);
  } catch (err) {
    next(err);
  }
};

export const getMyTransactionsHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    if (!req.user) throw new UnauthorizedError();
    const transactions = await transactionService.getMyTransactions(req.user.userId);
    sendSuccess(res, { transactions, count: transactions.length });
  } catch (err) {
    next(err);
  }
};

export const getTransactionHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    if (!req.user) throw new UnauthorizedError();
    const transaction = await transactionService.getTransaction(req.params.id, req.user.userId, req.user.role);
    sendSuccess(res, transaction);
  } catch (err) {
    next(err);
  }
};

export const confirmDeliveryHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    if (!req.user) throw new UnauthorizedError();
    const transaction = await transactionService.confirmDelivery(req.params.id, req.body.qrHash, req.user.userId);
    sendSuccess(res, transaction);
  } catch (err) {
    next(err);
  }
};
