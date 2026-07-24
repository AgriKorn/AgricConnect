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

export const exportAuditLogsCsvHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const entityId = req.query.entityId as string | undefined;
    const csvData = await auditService.exportAuditLogsCsv(entityId);
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', `attachment; filename=audit-logs-${entityId || 'all'}.csv`);
    res.status(200).send(csvData);
  } catch (err) {
    next(err);
  }
};
