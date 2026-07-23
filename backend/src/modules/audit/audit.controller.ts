import { Request, Response, NextFunction } from 'express';
import { sendSuccess } from '../../utils/response';
import { auditService } from './audit.service';

export const verifyEntityChainHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const result = await auditService.verifyChainForEntity(req.params.entityId);
    sendSuccess(res, result);
  } catch (err) {
    next(err);
  }
};
