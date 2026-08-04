import { PricingService } from './pricing.service';
import { IMofaPriceRepository } from './pricing.repository';
import { NotFoundError } from '../../utils/errors';

describe('PricingService', () => {
  let pricingService: PricingService;
  let mockMofaPrices: jest.Mocked<IMofaPriceRepository>;

  beforeEach(() => {
    jest.clearAllMocks();
    mockMofaPrices = {
      findLatest: jest.fn(),
      findPriceHistory: jest.fn(),
    } as any;

    pricingService = new PricingService(mockMofaPrices);
  });

  describe('recommend', () => {
    it('throws NotFoundError when no MOFA reference price exists for the crop/region', async () => {
      mockMofaPrices.findLatest.mockResolvedValue(null);

      await expect(
        pricingService.recommend({ crop: 'tomato', region: 'Ashanti', freshness: 90 } as any),
      ).rejects.toThrow(NotFoundError);
    });

    it('computes ceiling proportional to freshness and a fixed soft floor', async () => {
      mockMofaPrices.findLatest.mockResolvedValue({
        cropType: 'tomato',
        region: 'Ashanti',
        pricePerKg: 10,
        effectiveDate: new Date(),
      });

      const result = await pricingService.recommend({ crop: 'tomato', region: 'Ashanti', freshness: 80 } as any);

      expect(result.mofaPrice).toBe(10);
      expect(result.ceiling).toBe(8); // 10 * (80 / 100)
      expect(result.softFloor).toBe(6); // 10 * 0.6
    });

    it('omits decayProjection when shelfLifeDays is not provided', async () => {
      mockMofaPrices.findLatest.mockResolvedValue({
        cropType: 'tomato',
        region: 'Ashanti',
        pricePerKg: 10,
        effectiveDate: new Date(),
      });

      const result = await pricingService.recommend({ crop: 'tomato', region: 'Ashanti', freshness: 90 } as any);

      expect(result.decayProjection).toBeUndefined();
    });

    it('builds one decay projection point per day when shelfLifeDays is provided', async () => {
      mockMofaPrices.findLatest.mockResolvedValue({
        cropType: 'tomato',
        region: 'Ashanti',
        pricePerKg: 10,
        effectiveDate: new Date(),
      });

      const result = await pricingService.recommend({
        crop: 'tomato',
        region: 'Ashanti',
        freshness: 90,
        shelfLifeDays: 5,
      } as any);

      expect(result.decayProjection).toHaveLength(6); // days 0..5 inclusive
      expect(result.decayProjection![0].daysElapsed).toBe(0);
      expect(result.decayProjection![0].projectedFreshness).toBe(90);
    });
  });

  describe('getMarketTrend', () => {
    it('returns null with no crop types given', async () => {
      const result = await pricingService.getMarketTrend([], 'Ashanti');
      expect(result.trendPercent).toBeNull();
    });

    it('returns null when there is only one recorded price snapshot per crop (no history to compare against)', async () => {
      mockMofaPrices.findPriceHistory.mockResolvedValue([
        { cropType: 'tomato', region: 'Ashanti', pricePerKg: 10, effectiveDate: new Date('2026-07-30') },
      ]);

      const result = await pricingService.getMarketTrend(['tomato'], 'Ashanti');

      expect(result.trendPercent).toBeNull();
    });

    it('computes real percent change between the two latest snapshots for a crop', async () => {
      mockMofaPrices.findPriceHistory.mockResolvedValue([
        { cropType: 'tomato', region: 'Ashanti', pricePerKg: 11, effectiveDate: new Date('2026-07-30') },
        { cropType: 'tomato', region: 'Ashanti', pricePerKg: 10, effectiveDate: new Date('2026-07-23') },
      ]);

      const result = await pricingService.getMarketTrend(['tomato'], 'Ashanti');

      expect(result.trendPercent).toBe(10); // (11 - 10) / 10 * 100
    });

    it('averages percent change across multiple crops, ignoring crops with no history', async () => {
      mockMofaPrices.findPriceHistory.mockResolvedValue([
        { cropType: 'tomato', region: 'Ashanti', pricePerKg: 12, effectiveDate: new Date('2026-07-30') },
        { cropType: 'tomato', region: 'Ashanti', pricePerKg: 10, effectiveDate: new Date('2026-07-23') },
        { cropType: 'maize', region: 'Ashanti', pricePerKg: 5, effectiveDate: new Date('2026-07-30') }, // no prior snapshot
      ]);

      const result = await pricingService.getMarketTrend(['tomato', 'maize'], 'Ashanti');

      expect(result.trendPercent).toBe(20); // only tomato had history: (12-10)/10 * 100
    });
  });
});
