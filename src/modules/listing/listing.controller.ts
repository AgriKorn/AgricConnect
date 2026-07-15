import { Request, Response } from 'express';
import * as listingService from './listing.service';

// Extend Express Request to include our authenticated user payload (expected from auth middleware)
export interface AuthenticatedRequest extends Request {
  user?: {
    id: string;
    role?: string;
  };
}

export const createListingHandler = async (req: AuthenticatedRequest, res: Response) => {
  try {
    const farmerUserId = req.user?.id;
    if (!farmerUserId) {
      return res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'User is not authenticated' }
      });
    }

    const listing = await listingService.createListing(req.body, farmerUserId);
    return res.status(201).json({ success: true, data: listing });
  } catch (error: any) {
    return res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_SERVER_ERROR', message: error.message || 'Failed to create listing' }
    });
  }
};

export const getFarmerListingsHandler = async (req: AuthenticatedRequest, res: Response) => {
  try {
    const farmerUserId = req.user?.id;
    if (!farmerUserId) {
      return res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'User is not authenticated' }
      });
    }

    const listings = await listingService.getFarmerListings(farmerUserId);
    return res.status(200).json({ success: true, data: listings });
  } catch (error: any) {
    return res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_SERVER_ERROR', message: error.message || 'Failed to fetch listings' }
    });
  }
};

export const getListingByIdHandler = async (req: Request, res: Response) => {
  try {
    const listingId = req.params.id;
    const listing = await listingService.getListingById(listingId);

    if (!listing) {
      return res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: 'Listing not found' }
      });
    }

    return res.status(200).json({ success: true, data: listing });
  } catch (error: any) {
    return res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_SERVER_ERROR', message: error.message || 'Failed to fetch listing' }
    });
  }
};

export const updateListingHandler = async (req: Request, res: Response) => {
  try {
    const listingId = req.params.id;
    const updatedListing = await listingService.updateListing(listingId, req.body);
    return res.status(200).json({ success: true, data: updatedListing });
  } catch (error: any) {
    // Note: If Prisma throws a 'Record to update not found' error, it will be caught here.
    return res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_SERVER_ERROR', message: error.message || 'Failed to update listing' }
    });
  }
};

export const deleteListingHandler = async (req: Request, res: Response) => {
  try {
    const listingId = req.params.id;
    const deletedListing = await listingService.softDeleteListing(listingId);
    return res.status(200).json({ success: true, data: deletedListing });
  } catch (error: any) {
    return res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_SERVER_ERROR', message: error.message || 'Failed to delete listing' }
    });
  }
};
