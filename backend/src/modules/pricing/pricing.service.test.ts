import { PricingService } from './pricing.service';
import { IMofaPriceRepository } from './pricing.repository';
import { InMemoryMofaPriceRepository } from './pricing.repository.memory';
import { NotFoundError } from '../../utils/errors';

describe('PricingService', () => {
  let mockRepo: jest.Mocked<IMofaPriceRepository>;
  let pricingService: PricingService;

  const mofaReference = (pricePerKg: number) => ({
    cropType: 'tomato',
    region: 'greater accra',
    pricePerKg,
    effectiveDate: new Date('2026-07-14'),
  });

  beforeEach(() => {
    jest.clearAllMocks();
    mockRepo = { findLatest: jest.fn() };
    pricingService = new PricingService(mockRepo);
  });

  describe('recommend', () => {
    it('should throw NotFoundError when no MOFA reference exists for the crop/region pair', async () => {
      mockRepo.findLatest.mockResolvedValue(null);

      await expect(
        pricingService.recommend({ crop: 'tomato', region: 'upper west', freshness: 90 }),
      ).rejects.toThrow(NotFoundError);

      expect(mockRepo.findLatest).toHaveBeenCalledWith('tomato', 'upper west');
    });

    it('should derive the ceiling from the MOFA price scaled by freshness', async () => {
      mockRepo.findLatest.mockResolvedValue(mofaReference(4.0));

      const result = await pricingService.recommend({ crop: 'tomato', region: 'greater accra', freshness: 80 });

      expect(result.mofaPrice).toBe(4.0);
      expect(result.ceiling).toBe(3.2); // 4.00 * 0.80
    });

    it('should hold the soft floor at 60% of the MOFA price regardless of freshness', async () => {
      mockRepo.findLatest.mockResolvedValue(mofaReference(4.0));

      const fresh = await pricingService.recommend({ crop: 'tomato', region: 'greater accra', freshness: 95 });
      const stale = await pricingService.recommend({ crop: 'tomato', region: 'greater accra', freshness: 20 });

      expect(fresh.softFloor).toBe(2.4);
      expect(stale.softFloor).toBe(2.4);
    });

    it('should allow the ceiling to fall below the soft floor for badly degraded produce', async () => {
      // The soft floor is advisory, not a clamp — a farmer with 20%-fresh stock
      // gets a ceiling under it, which is the signal to sell fast or discard.
      mockRepo.findLatest.mockResolvedValue(mofaReference(4.0));

      const result = await pricingService.recommend({ crop: 'tomato', region: 'greater accra', freshness: 20 });

      expect(result.ceiling).toBe(0.8);
      expect(result.ceiling).toBeLessThan(result.softFloor);
    });

    it('should collapse the ceiling to zero at zero freshness', async () => {
      mockRepo.findLatest.mockResolvedValue(mofaReference(4.0));

      const result = await pricingService.recommend({ crop: 'tomato', region: 'greater accra', freshness: 0 });

      expect(result.ceiling).toBe(0);
    });

    it('should round money fields to 2 decimal places', async () => {
      mockRepo.findLatest.mockResolvedValue(mofaReference(3.33));

      const result = await pricingService.recommend({ crop: 'tomato', region: 'greater accra', freshness: 77 });

      expect(result.ceiling).toBe(2.56); // 3.33 * 0.77 = 2.5641
      expect(result.softFloor).toBe(2.0); // 3.33 * 0.6  = 1.998
    });

    it('should echo the query crop, region and freshness back to the caller', async () => {
      mockRepo.findLatest.mockResolvedValue(mofaReference(4.0));

      const result = await pricingService.recommend({ crop: 'tomato', region: 'greater accra', freshness: 88 });

      expect(result).toMatchObject({ crop: 'tomato', region: 'greater accra', freshness: 88 });
    });

    it('should omit the decay projection when no shelf life is supplied', async () => {
      mockRepo.findLatest.mockResolvedValue(mofaReference(4.0));

      const result = await pricingService.recommend({ crop: 'tomato', region: 'greater accra', freshness: 90 });

      expect(result.decayProjection).toBeUndefined();
    });

    describe('decay projection', () => {
      it('should return one point per day inclusive of day 0 and the final day', async () => {
        mockRepo.findLatest.mockResolvedValue(mofaReference(4.0));

        const result = await pricingService.recommend({
          crop: 'tomato',
          region: 'greater accra',
          freshness: 100,
          shelfLifeDays: 5,
        });

        expect(result.decayProjection).toHaveLength(6);
        expect(result.decayProjection!.map((p) => p.daysElapsed)).toEqual([0, 1, 2, 3, 4, 5]);
      });

      it('should start the projection at the live ceiling and end worthless', async () => {
        mockRepo.findLatest.mockResolvedValue(mofaReference(4.0));

        const result = await pricingService.recommend({
          crop: 'tomato',
          region: 'greater accra',
          freshness: 100,
          shelfLifeDays: 4,
        });

        const projection = result.decayProjection!;
        expect(projection[0]).toEqual({ daysElapsed: 0, projectedFreshness: 100, projectedCeiling: 4.0 });
        expect(projection[0].projectedCeiling).toBe(result.ceiling);
        expect(projection[4]).toEqual({ daysElapsed: 4, projectedFreshness: 0, projectedCeiling: 0 });
      });

      it('should decline monotonically in both freshness and price', async () => {
        mockRepo.findLatest.mockResolvedValue(mofaReference(4.0));

        const result = await pricingService.recommend({
          crop: 'tomato',
          region: 'greater accra',
          freshness: 90,
          shelfLifeDays: 6,
        });

        const projection = result.decayProjection!;
        for (let i = 1; i < projection.length; i++) {
          expect(projection[i].projectedFreshness).toBeLessThan(projection[i - 1].projectedFreshness);
          expect(projection[i].projectedCeiling).toBeLessThan(projection[i - 1].projectedCeiling);
        }
      });

      it('should keep the soft floor flat across the projection window', async () => {
        mockRepo.findLatest.mockResolvedValue(mofaReference(4.0));

        const result = await pricingService.recommend({
          crop: 'tomato',
          region: 'greater accra',
          freshness: 100,
          shelfLifeDays: 3,
        });

        // Soft floor is a property of the MOFA reference, so it must not decay
        // with the listing — only the ceiling tracks freshness.
        expect(result.softFloor).toBe(2.4);
      });

      it('should produce a single-day projection for produce expiring tomorrow', async () => {
        mockRepo.findLatest.mockResolvedValue(mofaReference(4.0));

        const result = await pricingService.recommend({
          crop: 'tomato',
          region: 'greater accra',
          freshness: 60,
          shelfLifeDays: 1,
        });

        expect(result.decayProjection).toEqual([
          { daysElapsed: 0, projectedFreshness: 60, projectedCeiling: 2.4 },
          { daysElapsed: 1, projectedFreshness: 0, projectedCeiling: 0 },
        ]);
      });
    });
  });

  describe('with the in-memory MOFA repository', () => {
    beforeEach(() => {
      pricingService = new PricingService(new InMemoryMofaPriceRepository());
    });

    it('should resolve a seeded crop/region pair case-insensitively', async () => {
      const result = await pricingService.recommend({ crop: 'Tomato', region: 'Greater Accra', freshness: 100 });

      expect(result.mofaPrice).toBe(4.0);
      expect(result.ceiling).toBe(4.0);
    });

    it('should price the same crop differently by region', async () => {
      const accra = await pricingService.recommend({ crop: 'tomato', region: 'greater accra', freshness: 100 });
      const ashanti = await pricingService.recommend({ crop: 'tomato', region: 'ashanti', freshness: 100 });

      expect(accra.ceiling).toBe(4.0);
      expect(ashanti.ceiling).toBe(3.5);
    });

    it('should reject a crop/region pair that has no benchmark', async () => {
      await expect(
        pricingService.recommend({ crop: 'maize', region: 'greater accra', freshness: 100 }),
      ).rejects.toThrow(NotFoundError);
    });
  });
});
