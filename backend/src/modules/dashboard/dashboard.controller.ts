import { Request, Response, NextFunction } from 'express';
import { UnauthorizedError } from '../../utils/errors';
import { sendSuccess } from '../../utils/response';
import { dashboardService } from './dashboard.service';

export const getFarmerSummaryHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const user = (req as any).user;
    if (!user) throw new UnauthorizedError();
    const summary = await dashboardService.getFarmerSummary(user.userId);
    sendSuccess(res, summary);
  } catch (err) {
    next(err);
  }
};
