import { NotFoundError } from '../../utils/errors';
import { projectFreshness } from './freshnessDecay';
import { IMofaPriceRepository } from './pricing.repository';
import { mofaPriceRepository } from './pricing.repository.memory';
import { RecommendPriceQuery } from './pricing.schema';

const SOFT_FLOOR_RATIO = 0.6;

export interface DecayProjectionPoint {
  daysElapsed: number;
  projectedFreshness: number;
  projectedCeiling: number;
}

export interface PriceRecommendation {
  crop: string;
  region: string;
  freshness: number;
  mofaPrice: number;
  ceiling: number;
  softFloor: number;
  decayProjection?: DecayProjectionPoint[];
}

export class PricingService {
  constructor(private readonly mofaPrices: IMofaPriceRepository) {}

  async recommend(query: RecommendPriceQuery): Promise<PriceRecommendation> {
    const reference = await this.mofaPrices.findLatest(query.crop, query.region);
    if (!reference) {
      throw new NotFoundError(`No MOFA reference price found for ${query.crop} in ${query.region}`);
    }

    const ceiling = reference.pricePerKg * (query.freshness / 100);
    const softFloor = reference.pricePerKg * SOFT_FLOOR_RATIO;

    const recommendation: PriceRecommendation = {
      crop: query.crop,
      region: query.region,
      freshness: query.freshness,
      mofaPrice: reference.pricePerKg,
      ceiling: Number(ceiling.toFixed(2)),
      softFloor: Number(softFloor.toFixed(2)),
    };

    if (query.shelfLifeDays) {
      const shelfLifeDays = query.shelfLifeDays;
      recommendation.decayProjection = Array.from({ length: shelfLifeDays + 1 }, (_, daysElapsed) => {
        const projectedFreshness = projectFreshness(query.freshness, daysElapsed, shelfLifeDays);
        const projectedCeiling = Number((reference.pricePerKg * (projectedFreshness / 100)).toFixed(2));
        return { daysElapsed, projectedFreshness, projectedCeiling };
      });
    }

    return recommendation;
  }
}

export const pricingService = new PricingService(mofaPriceRepository);
