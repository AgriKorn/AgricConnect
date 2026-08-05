import { Request, Response, NextFunction } from 'express';
import { UnauthorizedError } from '../../utils/errors';
import { sendSuccess } from '../../utils/response';
import { dispatchService } from './dispatch.service';

export const getDriverJobsHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const user = (req as any).user;
    if (!user) throw new UnauthorizedError();
    const status = req.query.status as any;
    const jobs = await dispatchService.getDriverJobs(user.userId, status);
    sendSuccess(res, { jobs, count: jobs.length });
  } catch (err) {
    next(err);
  }
};

export const acceptJobHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const user = (req as any).user;
    if (!user) throw new UnauthorizedError();
    const job = await dispatchService.acceptJob(req.params.jobId, user.userId);
    sendSuccess(res, job);
  } catch (err) {
    next(err);
  }
};

export const declineJobHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const user = (req as any).user;
    if (!user) throw new UnauthorizedError();
    const result = await dispatchService.declineJob(req.params.jobId, user.userId);
    sendSuccess(res, result);
  } catch (err) {
    next(err);
  }
};

export const markPickedUpHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const user = (req as any).user;
    if (!user) throw new UnauthorizedError();
    const job = await dispatchService.markPickedUp(req.params.jobId, user.userId);
    sendSuccess(res, job);
  } catch (err) {
    next(err);
  }
};

export const markDeliveredHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const user = (req as any).user;
    if (!user) throw new UnauthorizedError();
    const job = await dispatchService.markDelivered(req.params.jobId, user.userId);
    sendSuccess(res, job);
  } catch (err) {
    next(err);
  }
};
