import { NotFoundError } from '../../utils/errors';
import { projectFreshness } from './freshnessDecay';
import { IMofaPriceRepository } from './pricing.repository';
import { mofaPriceRepository } from './pricing.repository.prisma';
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

export interface MarketTrendResult {
  /** null when there isn't yet a second dated price snapshot to compare against — never fabricated. */
  trendPercent: number | null;
}

export class PricingService {
  constructor(private readonly mofaPrices: IMofaPriceRepository) {}

  /**
   * Real trend from mofa_price_references: latest recorded price vs. the
   * previous recorded price, per crop, averaged across the given crops.
   * Returns null (not 0) when there's no second snapshot yet — the seed
   * script only ever re-stamps a single "today" row, so this will
   * legitimately stay null until reference prices are actually updated
   * over time.
   */
  async getMarketTrend(cropTypes: string[], region: string): Promise<MarketTrendResult> {
    if (cropTypes.length === 0) return { trendPercent: null };

    const history = await this.mofaPrices.findPriceHistory(cropTypes, region);

    const byCrop = new Map<string, typeof history>();
    for (const ref of history) {
      const key = ref.cropType.toLowerCase();
      const list = byCrop.get(key) ?? [];
      list.push(ref);
      byCrop.set(key, list);
    }

    const percentChanges: number[] = [];
    for (const refs of byCrop.values()) {
      // findPriceHistory already orders newest-first per crop.
      if (refs.length < 2 || refs[1].pricePerKg <= 0) continue;
      const [latest, previous] = refs;
      percentChanges.push(((latest.pricePerKg - previous.pricePerKg) / previous.pricePerKg) * 100);
    }

    if (percentChanges.length === 0) return { trendPercent: null };

    const avg = percentChanges.reduce((sum, p) => sum + p, 0) / percentChanges.length;
    return { trendPercent: Number(avg.toFixed(1)) };
  }

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
