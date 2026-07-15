import { Request, Response, NextFunction } from 'express';
import { AppError } from '../utils/errors';
import { sendError } from '../utils/response';
import logger from '../utils/logger';

export const errorHandler = (err: Error, _req: Request, res: Response, _next: NextFunction) => {
  // Log the error
  if (err instanceof AppError) {
    if (!err.isOperational) {
      logger.error('Non-operational error:', { error: err.message, stack: err.stack });
    } else {
      logger.warn('Operational error:', { code: err.code, message: err.message });
    }
    return sendError(res, err.code, err.message, err.statusCode);
  }

  // Unexpected errors
  logger.error('Unexpected error:', { error: err.message, stack: err.stack });
  return sendError(res, 'INTERNAL_SERVER_ERROR', 'An unexpected error occurred', 500);
};
