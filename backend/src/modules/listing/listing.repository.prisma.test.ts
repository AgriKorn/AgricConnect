import { mockDeep, DeepMockProxy } from 'jest-mock-extended';
import { PrismaClient } from '../../generated/prisma/client';

jest.mock('../../config/db', () => ({
  prisma: mockDeep<PrismaClient>(),
}));

import { prisma } from '../../config/db';
import { PrismaListingRepository } from './listing.repository.prisma';
import { ListingFilters } from './listing.repository';

/**
 * Covers the query the marketplace browse endpoint builds.
 *
 * Every other suite mocks the repository, so the `where` clause itself was never
 * exercised — which is how two filters shipped broken: `maxFreshness` was never
 * read, and an empty `farmerIds` silently dropped the region filter instead of
 * matching nothing.
 */
describe('PrismaListingRepository.findActive', () => {
  let mockPrisma: DeepMockProxy<PrismaClient>;
  let repo: PrismaListingRepository;

  const filters = (overrides?: Partial<ListingFilters>): ListingFilters => ({
    sort: 'date',
    order: 'desc',
    page: 1,
    limit: 20,
    ...overrides,
  });

  /** The `where` the repository handed to findMany. */
  const whereClause = () => (mockPrisma.produce_listings.findMany.mock.calls[0][0] as any).where;

  beforeEach(() => {
    jest.clearAllMocks();
    mockPrisma = prisma as unknown as DeepMockProxy<PrismaClient>;
    mockPrisma.produce_listings.findMany.mockResolvedValue([] as any);
    mockPrisma.produce_listings.count.mockResolvedValue(0 as any);
    repo = new PrismaListingRepository();
  });

  describe('freshness bounds', () => {
    it('should apply maxFreshness as an upper bound', async () => {
      await repo.findActive(filters({ maxFreshness: 60 }));

      expect(whereClause().freshness_score).toEqual({ lte: 60 });
    });

    it('should apply minFreshness as a lower bound', async () => {
      await repo.findActive(filters({ minFreshness: 90 }));

      expect(whereClause().freshness_score).toEqual({ gte: 90 });
    });

    it('should apply both bounds together rather than letting one overwrite the other', async () => {
      await repo.findActive(filters({ minFreshness: 60, maxFreshness: 90 }));

      expect(whereClause().freshness_score).toEqual({ gte: 60, lte: 90 });
    });

    it('should not constrain freshness when neither bound is given', async () => {
      await repo.findActive(filters());

      expect(whereClause()).not.toHaveProperty('freshness_score');
    });
  });

  describe('region filtering via farmerIds', () => {
    it('should match nothing when the region resolved to no farmers', async () => {
      // The empty array is meaningful: it says "this region has no farmers".
      // Treating it as "no filter" returned every listing in the country.
      await repo.findActive(filters({ farmerIds: [] }));

      expect(whereClause().farmer_id).toEqual({ in: [] });
    });

    it('should restrict to the farmers in the region', async () => {
      await repo.findActive(filters({ farmerIds: ['farmer-1', 'farmer-2'] }));

      expect(whereClause().farmer_id).toEqual({ in: ['farmer-1', 'farmer-2'] });
    });

    it('should not constrain the farmer when no region filter was supplied', async () => {
      await repo.findActive(filters());

      expect(whereClause()).not.toHaveProperty('farmer_id');
    });
  });

  describe('remaining filters', () => {
    it('should only ever return active listings', async () => {
      await repo.findActive(filters());

      expect(whereClause().status).toBe('active');
    });

    it('should match the crop name case-insensitively', async () => {
      await repo.findActive(filters({ crop: 'Tomato' }));

      expect(whereClause().crop_types).toEqual({ name: { equals: 'Tomato', mode: 'insensitive' } });
    });

    it('should apply minQuantity as a lower bound', async () => {
      await repo.findActive(filters({ minQuantity: 500 }));

      expect(whereClause().quantity_kg).toEqual({ gte: 500 });
    });

    it('should combine every filter into a single query', async () => {
      await repo.findActive(
        filters({ crop: 'tomato', minFreshness: 50, maxFreshness: 95, minQuantity: 100, farmerIds: ['farmer-1'] }),
      );

      expect(whereClause()).toEqual({
        status: 'active',
        crop_types: { name: { equals: 'tomato', mode: 'insensitive' } },
        freshness_score: { gte: 50, lte: 95 },
        quantity_kg: { gte: 100 },
        farmer_id: { in: ['farmer-1'] },
      });
    });

    it('should count against the same filters as the page query', async () => {
      await repo.findActive(filters({ maxFreshness: 60, farmerIds: [] }));

      const countWhere = (mockPrisma.produce_listings.count.mock.calls[0][0] as any).where;
      expect(countWhere).toEqual(whereClause());
    });
  });

  describe('sorting and paging', () => {
    it.each([
      ['date', 'created_at'],
      ['freshness', 'freshness_score'],
      ['price', 'listed_price'],
    ])('should sort by %s using the %s column', async (sort, column) => {
      await repo.findActive(filters({ sort: sort as ListingFilters['sort'], order: 'asc' }));

      const call = mockPrisma.produce_listings.findMany.mock.calls[0][0] as any;
      expect(call.orderBy).toEqual({ [column]: 'asc' });
    });

    it('should translate page and limit into skip and take', async () => {
      await repo.findActive(filters({ page: 3, limit: 10 }));

      const call = mockPrisma.produce_listings.findMany.mock.calls[0][0] as any;
      expect(call.skip).toBe(20);
      expect(call.take).toBe(10);
    });
  });

  describe('mapping', () => {
    it('should expose the crop category the marketplace filters on', async () => {
      mockPrisma.produce_listings.findMany.mockResolvedValue([
        {
          id: 'listing-1',
          farmer_id: 'farmer-1',
          crop_types: { name: 'maize', category: 'grains' },
          quantity_kg: 800,
          freshness_score: 95,
          estimated_viable_days: 30,
          gps_lat: 5.6037,
          gps_lng: -0.187,
          listed_price: 2.1,
          listing_hash: 'hash',
          qr_code_data: 'qr',
          status: 'active',
          created_at: new Date(),
          updated_at: new Date(),
        },
      ] as any);
      mockPrisma.produce_listings.count.mockResolvedValue(1 as any);

      const { listings } = await repo.findActive(filters());

      expect(listings[0].cropType).toBe('maize');
      expect(listings[0].cropCategory).toBe('grains');
    });

    it('should fall back to a null category when the crop row has none', async () => {
      mockPrisma.produce_listings.findMany.mockResolvedValue([
        {
          id: 'listing-1',
          farmer_id: 'farmer-1',
          crop_types: { name: 'tomato', category: null },
          quantity_kg: 500,
          freshness_score: 85,
          estimated_viable_days: 6,
          gps_lat: 5.6,
          gps_lng: -0.18,
          listed_price: 3.2,
          listing_hash: 'hash',
          qr_code_data: 'qr',
          status: 'active',
          created_at: new Date(),
          updated_at: new Date(),
        },
      ] as any);
      mockPrisma.produce_listings.count.mockResolvedValue(1 as any);

      const { listings } = await repo.findActive(filters());

      expect(listings[0].cropCategory).toBeNull();
    });

    it('should expose the full image gallery, falling back to the single photo for legacy rows', async () => {
      mockPrisma.produce_listings.findMany.mockResolvedValue([
        // A gallery row.
        { id: 'a', farmer_id: 'f', crop_types: { name: 'tomato', category: 'vegetables' }, quantity_kg: 1, freshness_score: 90, estimated_viable_days: 6, gps_lat: 5, gps_lng: 0, listed_price: 3, listing_hash: 'h', qr_code_data: 'q', photo_url: 'https://s3/cover.jpg', image_urls: ['https://s3/cover.jpg', 'https://s3/2.jpg'], status: 'active', created_at: new Date(), updated_at: new Date() },
        // A legacy single-photo row with no gallery array.
        { id: 'b', farmer_id: 'f', crop_types: { name: 'maize', category: 'grains' }, quantity_kg: 1, freshness_score: 90, estimated_viable_days: 6, gps_lat: 5, gps_lng: 0, listed_price: 3, listing_hash: 'h2', qr_code_data: 'q', photo_url: 'https://s3/legacy.jpg', image_urls: [], status: 'active', created_at: new Date(), updated_at: new Date() },
      ] as any);
      mockPrisma.produce_listings.count.mockResolvedValue(2 as any);

      const { listings } = await repo.findActive(filters());

      expect(listings[0].imageUrls).toEqual(['https://s3/cover.jpg', 'https://s3/2.jpg']);
      expect(listings[0].imageUrl).toBe('https://s3/cover.jpg'); // cover is the first
      expect(listings[1].imageUrls).toEqual(['https://s3/legacy.jpg']); // legacy single photo becomes a one-image gallery
    });
  });

  describe('create — image gallery (SRS "Produce Upload")', () => {
    beforeEach(() => {
      mockPrisma.crop_types.findFirst.mockResolvedValue({ id: 'crop-1', name: 'tomato', category: 'vegetables' } as any);
      mockPrisma.produce_listings.create.mockResolvedValue({
        id: 'new', farmer_id: 'f', crop_types: { name: 'tomato', category: 'vegetables' }, quantity_kg: 1,
        freshness_score: 90, estimated_viable_days: 6, gps_lat: 5, gps_lng: 0, listed_price: 3,
        listing_hash: 'h', qr_code_data: 'q', status: 'active', created_at: new Date(), updated_at: new Date(),
      } as any);
    });

    const baseCreate = { farmerId: 'f', cropType: 'tomato', quantityKg: 1, freshnessScore: 90, shelfLifeDays: 6, farmerLat: 5, farmerLong: 0, pricePerKg: 3, listingHash: 'h', qrCodeData: 'q', status: 'ACTIVE' as const };

    const dataWritten = () => (mockPrisma.produce_listings.create.mock.calls[0][0] as any).data;

    it('should store the whole gallery and set the cover to the first image', async () => {
      await repo.create({ ...baseCreate, imageUrls: ['https://s3/1.jpg', 'https://s3/2.jpg', 'https://s3/3.jpg'] });

      expect(dataWritten().image_urls).toEqual(['https://s3/1.jpg', 'https://s3/2.jpg', 'https://s3/3.jpg']);
      expect(dataWritten().photo_url).toBe('https://s3/1.jpg');
    });

    it('should promote a single imageUrl into a one-image gallery', async () => {
      await repo.create({ ...baseCreate, imageUrl: 'https://s3/only.jpg' });

      expect(dataWritten().image_urls).toEqual(['https://s3/only.jpg']);
      expect(dataWritten().photo_url).toBe('https://s3/only.jpg');
    });

    it('should store an empty gallery and no cover when no images are supplied', async () => {
      await repo.create(baseCreate);

      expect(dataWritten().image_urls).toEqual([]);
      expect(dataWritten().photo_url).toBeUndefined();
    });
  });
});
