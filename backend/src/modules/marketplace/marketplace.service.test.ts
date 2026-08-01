import { MarketplaceService } from './marketplace.service';
import { IListingRepository } from '../listing/listing.repository';
import { IUserRepository } from '../user/user.repository';
import { Listing } from '../listing/listing.types';
import { User } from '../user/user.types';
import { BrowseMarketplaceQuery } from './marketplace.schema';
import { NotFoundError } from '../../utils/errors';

describe('MarketplaceService', () => {
  let mockListings: jest.Mocked<IListingRepository>;
  let mockUsers: jest.Mocked<IUserRepository>;
  let marketplaceService: MarketplaceService;

  const createListing = (overrides?: Partial<Listing>): Listing => ({
    id: 'listing-1',
    farmerId: 'farmer-1',
    cropType: 'tomato',
    cropCategory: 'vegetables',
    quantityKg: 500,
    freshnessScore: 90,
    shelfLifeDays: 6,
    farmerLat: 5.6037,
    farmerLong: -0.187,
    pricePerKg: 3.5,
    listingHash: 'hash-1',
    qrCodeData: 'qr-1',
    status: 'ACTIVE',
    createdAt: new Date('2026-07-20'),
    updatedAt: new Date('2026-07-20'),
    ...overrides,
  });

  const createFarmer = (overrides?: Partial<User>): User => ({
    id: 'farmer-1',
    name: 'Kwame Mensah',
    phone: '+233541234567',
    passwordHash: 'hashed',
    role: 'farmer',
    status: 'ACTIVE',
    otp: null,
    otpExpiry: null,
    refreshToken: null,
    profile: { farmRegion: 'Greater Accra' },
    createdAt: new Date('2026-07-01'),
    updatedAt: new Date('2026-07-01'),
    ...overrides,
  });

  const query = (overrides?: Partial<BrowseMarketplaceQuery>): BrowseMarketplaceQuery => ({
    sort: 'date',
    order: 'desc',
    page: 1,
    limit: 20,
    ...overrides,
  });

  beforeEach(() => {
    jest.clearAllMocks();

    mockListings = {
      create: jest.fn(),
      findManyByFarmer: jest.fn(),
      findActive: jest.fn(),
      findById: jest.fn(),
      update: jest.fn(),
      softDelete: jest.fn(),
      markSold: jest.fn(),
    };

    mockUsers = {
      create: jest.fn(),
      findByPhone: jest.fn(),
      findById: jest.fn(),
      findManyByStatus: jest.fn(),
      findFarmerIdsByRegion: jest.fn(),
      findAvailableDrivers: jest.fn(),
      update: jest.fn(),
      updateProfile: jest.fn(),
      updateFcmToken: jest.fn(),
      registerDeviceToken: jest.fn(),
      removeDeviceToken: jest.fn(),
      findActiveDeviceTokens: jest.fn(),
      deactivateDeviceToken: jest.fn(),
    };

    marketplaceService = new MarketplaceService(mockListings, mockUsers);
  });

  describe('browse', () => {
    it('should pass crop, freshness, quantity, sort and paging filters through to the repository', async () => {
      mockListings.findActive.mockResolvedValue({ listings: [], total: 0 });

      await marketplaceService.browse(
        query({
          crop: 'tomato',
          minFreshness: 60,
          maxFreshness: 95,
          minQuantity: 100,
          sort: 'freshness',
          order: 'asc',
          page: 2,
          limit: 10,
        }),
      );

      expect(mockListings.findActive).toHaveBeenCalledWith({
        crop: 'tomato',
        minFreshness: 60,
        maxFreshness: 95,
        minQuantity: 100,
        sort: 'freshness',
        order: 'asc',
        page: 2,
        limit: 10,
      });
    });

    it('should not resolve farmer IDs when no region filter is supplied', async () => {
      mockListings.findActive.mockResolvedValue({ listings: [], total: 0 });

      await marketplaceService.browse(query());

      expect(mockUsers.findFarmerIdsByRegion).not.toHaveBeenCalled();
      expect(mockListings.findActive).toHaveBeenCalledWith(expect.not.objectContaining({ farmerIds: expect.anything() }));
    });

    it('should translate a region filter into the set of farmer IDs in that region', async () => {
      mockUsers.findFarmerIdsByRegion.mockResolvedValue(['farmer-1', 'farmer-2']);
      mockListings.findActive.mockResolvedValue({ listings: [], total: 0 });

      await marketplaceService.browse(query({ region: 'Ashanti' }));

      expect(mockUsers.findFarmerIdsByRegion).toHaveBeenCalledWith('Ashanti');
      expect(mockListings.findActive).toHaveBeenCalledWith(expect.objectContaining({ farmerIds: ['farmer-1', 'farmer-2'] }));
    });

    it('should return an empty page when a region has no farmers, rather than ignoring the filter', async () => {
      mockUsers.findFarmerIdsByRegion.mockResolvedValue([]);
      mockListings.findActive.mockResolvedValue({ listings: [], total: 0 });

      const result = await marketplaceService.browse(query({ region: 'Upper West' }));

      expect(mockListings.findActive).toHaveBeenCalledWith(expect.objectContaining({ farmerIds: [] }));
      expect(result.listings).toEqual([]);
    });

    it('should enrich each listing with its farmer region', async () => {
      mockListings.findActive.mockResolvedValue({ listings: [createListing()], total: 1 });
      mockUsers.findById.mockResolvedValue(createFarmer());

      const result = await marketplaceService.browse(query());

      expect(mockUsers.findById).toHaveBeenCalledWith('farmer-1');
      expect(result.listings[0]).toMatchObject({ id: 'listing-1', farmerRegion: 'Greater Accra' });
    });

    it('should fall back to a null farmer region when the farmer record is missing', async () => {
      mockListings.findActive.mockResolvedValue({ listings: [createListing()], total: 1 });
      mockUsers.findById.mockResolvedValue(null);

      const result = await marketplaceService.browse(query());

      expect(result.listings[0].farmerRegion).toBeNull();
    });

    it('should fall back to a null farmer region when the farmer has no region on their profile', async () => {
      mockListings.findActive.mockResolvedValue({ listings: [createListing()], total: 1 });
      mockUsers.findById.mockResolvedValue(createFarmer({ profile: {} }));

      const result = await marketplaceService.browse(query());

      expect(result.listings[0].farmerRegion).toBeNull();
    });

    it('should enrich every listing in the page, resolving each distinct farmer', async () => {
      mockListings.findActive.mockResolvedValue({
        listings: [
          createListing({ id: 'listing-1', farmerId: 'farmer-1' }),
          createListing({ id: 'listing-2', farmerId: 'farmer-2' }),
        ],
        total: 2,
      });
      mockUsers.findById.mockImplementation(async (id: string) =>
        id === 'farmer-1'
          ? createFarmer({ id: 'farmer-1', profile: { farmRegion: 'Greater Accra' } })
          : createFarmer({ id: 'farmer-2', profile: { farmRegion: 'Ashanti' } }),
      );

      const result = await marketplaceService.browse(query());

      expect(result.listings.map((l) => l.farmerRegion)).toEqual(['Greater Accra', 'Ashanti']);
    });

    it('should preserve repository ordering after enrichment', async () => {
      mockListings.findActive.mockResolvedValue({
        listings: [createListing({ id: 'listing-a' }), createListing({ id: 'listing-b' }), createListing({ id: 'listing-c' })],
        total: 3,
      });
      mockUsers.findById.mockResolvedValue(createFarmer());

      const result = await marketplaceService.browse(query());

      expect(result.listings.map((l) => l.id)).toEqual(['listing-a', 'listing-b', 'listing-c']);
    });

    describe('pagination', () => {
      it('should round the page count up on a partial final page', async () => {
        mockListings.findActive.mockResolvedValue({ listings: [], total: 45 });

        const result = await marketplaceService.browse(query({ page: 1, limit: 20 }));

        expect(result.pagination).toEqual({ page: 1, limit: 20, total: 45, totalPages: 3 });
      });

      it('should report an exact page count when the total divides evenly', async () => {
        mockListings.findActive.mockResolvedValue({ listings: [], total: 40 });

        const result = await marketplaceService.browse(query({ page: 2, limit: 20 }));

        expect(result.pagination.totalPages).toBe(2);
      });

      it('should report zero pages — not one — for an empty result set', async () => {
        mockListings.findActive.mockResolvedValue({ listings: [], total: 0 });

        const result = await marketplaceService.browse(query());

        expect(result.pagination.totalPages).toBe(0);
      });

      it('should echo the requested page and limit back to the caller', async () => {
        mockListings.findActive.mockResolvedValue({ listings: [], total: 100 });

        const result = await marketplaceService.browse(query({ page: 3, limit: 25 }));

        expect(result.pagination).toMatchObject({ page: 3, limit: 25 });
      });
    });
  });

  describe('getListingDetail', () => {
    it('should return the listing enriched with the farmer region', async () => {
      mockListings.findById.mockResolvedValue(createListing());
      mockUsers.findById.mockResolvedValue(createFarmer());

      const result = await marketplaceService.getListingDetail('listing-1');

      expect(result).toMatchObject({ id: 'listing-1', farmerRegion: 'Greater Accra' });
    });

    it('should throw NotFoundError when the listing does not exist', async () => {
      mockListings.findById.mockResolvedValue(null);

      await expect(marketplaceService.getListingDetail('missing')).rejects.toThrow(NotFoundError);
    });

    it('should hide sold listings from the public marketplace', async () => {
      mockListings.findById.mockResolvedValue(createListing({ status: 'SOLD' }));

      await expect(marketplaceService.getListingDetail('listing-1')).rejects.toThrow(NotFoundError);
    });

    it('should hide inactive listings from the public marketplace', async () => {
      mockListings.findById.mockResolvedValue(createListing({ status: 'INACTIVE' }));

      await expect(marketplaceService.getListingDetail('listing-1')).rejects.toThrow(NotFoundError);
    });

    it('should not leak the farmer record beyond the region field', async () => {
      mockListings.findById.mockResolvedValue(createListing());
      mockUsers.findById.mockResolvedValue(createFarmer());

      const result = await marketplaceService.getListingDetail('listing-1');

      expect(result).not.toHaveProperty('passwordHash');
      expect(result).not.toHaveProperty('phone');
    });
  });
});
