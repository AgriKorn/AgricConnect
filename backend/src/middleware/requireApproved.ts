import { Request, Response, NextFunction } from 'express';
import { userRepository } from '../modules/user/user.repository.memory';
import { ForbiddenError, UnauthorizedError } from '../utils/errors';

/**
 * Gates transactional actions (creating a listing, purchasing, accepting a job)
 * behind admin approval. Looks up current status rather than trusting the JWT
 * payload, since a short-lived access token can be older than the approval.
 */
export const requireApproved = async (req: Request, _res: Response, next: NextFunction) => {
  if (!req.user) return next(new UnauthorizedError());

  const user = await userRepository.findById(req.user.userId);
  if (!user || user.status !== 'ACTIVE') {
    return next(new ForbiddenError('Your account is pending admin approval'));
  }
  return next();
};
