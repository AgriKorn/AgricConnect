import { Request, Response, NextFunction } from 'express';
import { UnauthorizedError } from '../../utils/errors';
import { sendSuccess } from '../../utils/response';
import { disputeService } from './dispute.service';

export const raiseDisputeHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const user = (req as any).user;
    if (!user) throw new UnauthorizedError();
    const { transactionId, type, description } = req.body;
    const dispute = await disputeService.raise(transactionId, type, description, user.userId);
    sendSuccess(res, dispute, 201);
  } catch (err) {
    next(err);
  }
};
