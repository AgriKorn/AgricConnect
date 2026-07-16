import { Request, Response, NextFunction } from 'express';
import { AnyZodObject, ZodError } from 'zod';
import { sendError } from '../utils/response';

export const validate = (schema: AnyZodObject) => (req: Request, res: Response, next: NextFunction) => {
  try {
    schema.parse({ body: req.body, params: req.params, query: req.query });
    return next();
  } catch (err) {
    if (err instanceof ZodError) {
      const message = err.errors.map((e) => e.message).join(', ');
      return sendError(res, 'VALIDATION_ERROR', message, 400);
    }
    next(err);
  }
};
