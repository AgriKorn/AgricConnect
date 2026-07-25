import { Request, Response, NextFunction } from 'express';
import { AnyZodObject, ZodError } from 'zod';
import { sendError } from '../utils/response';

export const validate = (schema: AnyZodObject) => (req: Request, res: Response, next: NextFunction) => {
  try {
    const parsed = schema.parse({ body: req.body, params: req.params, query: req.query }) as {
      body?: Record<string, unknown>;
      params?: Record<string, unknown>;
      query?: Record<string, unknown>;
    };
    // Mutate in place rather than reassign — req.query has a getter-only
    // property in Express, so `req.query = ...` throws under "use strict".
    if (parsed.body) Object.assign(req.body, parsed.body);
    if (parsed.params) Object.assign(req.params, parsed.params);
    if (parsed.query) Object.assign(req.query, parsed.query);
    return next();
  } catch (err) {
    if (err instanceof ZodError) {
      const message = err.errors.map((e) => e.message).join(', ');
      return sendError(res, 'VALIDATION_ERROR', message, 400);
    }
    next(err);
  }
};
