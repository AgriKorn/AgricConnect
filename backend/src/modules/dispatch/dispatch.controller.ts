import { Request, Response, NextFunction } from 'express';
import { UnauthorizedError } from '../../utils/errors';
import { sendSuccess } from '../../utils/response';
import { dispatchService } from './dispatch.service';

export const acceptJobHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    if (!req.user) throw new UnauthorizedError();
    const job = await dispatchService.acceptJob(req.params.jobId, req.user.userId);
    sendSuccess(res, job);
  } catch (err) {
    next(err);
  }
};

export const declineJobHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    if (!req.user) throw new UnauthorizedError();
    const result = await dispatchService.declineJob(req.params.jobId, req.user.userId);
    sendSuccess(res, result);
  } catch (err) {
    next(err);
  }
};
