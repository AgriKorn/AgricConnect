import { Request, Response, NextFunction } from 'express';
import { UnauthorizedError } from '../../utils/errors';
import { sendSuccess } from '../../utils/response';
import { addressService } from './address.service';

const requireUserId = (req: Request): string => {
  const user = (req as any).user;
  if (!user) throw new UnauthorizedError('Authentication required');
  return user.userId;
};

export const listAddressesHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = requireUserId(req);
    const addresses = await addressService.listAddresses(userId);
    sendSuccess(res, { addresses });
  } catch (err) {
    next(err);
  }
};

export const createAddressHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = requireUserId(req);
    const address = await addressService.createAddress(userId, req.body);
    sendSuccess(res, address, 201);
  } catch (err) {
    next(err);
  }
};

export const updateAddressHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = requireUserId(req);
    const address = await addressService.updateAddress(userId, req.params.id, req.body);
    sendSuccess(res, address);
  } catch (err) {
    next(err);
  }
};

export const deleteAddressHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = requireUserId(req);
    await addressService.deleteAddress(userId, req.params.id);
    sendSuccess(res, { message: 'Address deleted' });
  } catch (err) {
    next(err);
  }
};
