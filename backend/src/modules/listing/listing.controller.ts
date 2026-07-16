import { Request, Response, NextFunction } from 'express';
import { NotFoundError, UnauthorizedError } from '../../utils/errors';
import { sendSuccess } from '../../utils/response';
import { listingService } from './listing.service';

const requireUserId = (req: Request): string => {
  if (!req.user) throw new UnauthorizedError('Authentication required');
  return req.user.userId;
};

export const createListingHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const farmerId = requireUserId(req);
    const listing = await listingService.createListing(req.body, farmerId);
    sendSuccess(res, listing, 201);
  } catch (err) {
    next(err);
  }
};

export const getFarmerListingsHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const farmerId = requireUserId(req);
    const listings = await listingService.getFarmerListings(farmerId);
    sendSuccess(res, { listings, count: listings.length });
  } catch (err) {
    next(err);
  }
};

export const getListingByIdHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const listing = await listingService.getListingById(req.params.id);
    if (!listing) throw new NotFoundError('Listing not found');
    sendSuccess(res, listing);
  } catch (err) {
    next(err);
  }
};

export const updateListingHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const farmerId = requireUserId(req);
    const listing = await listingService.updateListing(req.params.id, farmerId, req.body);
    sendSuccess(res, listing);
  } catch (err) {
    next(err);
  }
};

export const deleteListingHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const farmerId = requireUserId(req);
    const listing = await listingService.deleteListing(req.params.id, farmerId);
    sendSuccess(res, listing);
  } catch (err) {
    next(err);
  }
};
