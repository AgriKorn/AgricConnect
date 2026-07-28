import { Request, Response, NextFunction } from 'express';
import { userRepository } from '../modules/user/user.repository.prisma';
import { ForbiddenError, UnauthorizedError } from '../utils/errors';

/**
 * Gates transactional actions (creating a listing, purchasing, accepting a job)
 * behind admin approval. Looks up current status rather than trusting the JWT
 * payload, since a short-lived access token can be older than the approval.
 */
export const requireApproved = async (req: Request, _res: Response, next: NextFunction) => {
  const reqUser = (req as any).user;
  if (!reqUser) return next(new UnauthorizedError());

  const user = await userRepository.findById(reqUser.userId);
  if (!user || user.status !== 'ACTIVE') {
    return next(new ForbiddenError('Your account is pending admin approval'));
  }
  return next();
};
