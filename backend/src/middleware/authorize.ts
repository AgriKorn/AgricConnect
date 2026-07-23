import { Request, Response, NextFunction } from 'express';
import { ForbiddenError, UnauthorizedError } from '../utils/errors';

export const authorize = (...allowedRoles: string[]) => {
  return (req: Request, _res: Response, next: NextFunction) => {
    const user = (req as any).user;
    if (!user) return next(new UnauthorizedError('Authentication required'));
    if (!allowedRoles.includes(user.role)) {
      return next(new ForbiddenError('You do not have permission to access this resource'));
    }
    return next();
  };
};
