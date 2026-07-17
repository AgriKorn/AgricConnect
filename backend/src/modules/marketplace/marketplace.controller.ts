import { Request, Response, NextFunction } from 'express';
import { sendSuccess } from '../../utils/response';
import { BrowseMarketplaceQuery } from './marketplace.schema';
import { marketplaceService } from './marketplace.service';

export const browseMarketplaceHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const result = await marketplaceService.browse(req.query as unknown as BrowseMarketplaceQuery);
    sendSuccess(res, result);
  } catch (err) {
    next(err);
  }
};

export const getMarketplaceListingHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const listing = await marketplaceService.getListingDetail(req.params.id);
    sendSuccess(res, listing);
  } catch (err) {
    next(err);
  }
};
