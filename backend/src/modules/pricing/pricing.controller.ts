import { Request, Response, NextFunction } from 'express';
import { sendSuccess } from '../../utils/response';
import { pricingService } from './pricing.service';
import { RecommendPriceQuery } from './pricing.schema';

export const recommendPriceHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const result = await pricingService.recommend(req.query as unknown as RecommendPriceQuery);
    sendSuccess(res, result);
  } catch (err) {
    next(err);
  }
};
