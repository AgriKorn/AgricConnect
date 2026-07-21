import { Request, Response, NextFunction } from 'express';
import { UnauthorizedError } from '../../utils/errors';
import { sendSuccess } from '../../utils/response';
import { disputeService } from './dispute.service';

export const raiseDisputeHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    if (!req.user) throw new UnauthorizedError();
    const { transactionId, type, description } = req.body;
    const dispute = await disputeService.raise(transactionId, type, description, req.user.userId);
    sendSuccess(res, dispute, 201);
  } catch (err) {
    next(err);
  }
};
