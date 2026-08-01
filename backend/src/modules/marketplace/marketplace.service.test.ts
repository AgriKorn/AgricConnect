import { MarketplaceService } from './marketplace.service';
import { IListingRepository } from '../listing/listing.repository';
import { IUserRepository } from '../user/user.repository';
import { NotFoundError } from '../../utils/errors';

describe('MarketplaceService', () => {
  let marketplaceService: MarketplaceService;
  let mockListings: jest.Mocked<IListingRepository>;
  let mockUsers: jest.Mocked<IUserRepository>;

  const baseListing = {
    id: 'listing-1',
    farmerId: 'farmer-1',
    cropType: 'tomato',
    cropCategory: 'vegetables',
    quantityKg: 100,
    freshnessScore: 90,
    shelfLifeDays: 7,
    farmerLat: 5.6,
    farmerLong: -0.2,
    pricePerKg: 15,
    listingHash: 'hash-1',
    qrCodeData: 'qr-1',
    status: 'ACTIVE' as const,
    createdAt: new Date(),
    updatedAt: new Date(),
  };

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
    } as any;
    mockUsers = {
      create: jest.fn(),
      findByPhone: jest.fn(),
      findById: jest.fn(),
      findManyByStatus: jest.fn(),
      findManyByRole: jest.fn(),
      findFarmerIdsByRegion: jest.fn(),
      findAvailableDrivers: jest.fn(),
      update: jest.fn(),
      updateProfile: jest.fn(),
      updateFcmToken: jest.fn(),
      registerDeviceToken: jest.fn(),
      removeDeviceToken: jest.fn(),
      findActiveDeviceTokens: jest.fn(),
      deactivateDeviceToken: jest.fn(),
    } as any;

    marketplaceService = new MarketplaceService(mockListings, mockUsers);
  });

  describe('browse', () => {
    it('enriches each listing with the farmer name and region', async () => {
      mockListings.findActive.mockResolvedValue({ listings: [baseListing], total: 1 });
      mockUsers.findById.mockResolvedValue({
        id: 'farmer-1',
        name: 'Ama Boateng',
        profile: { farmRegion: 'Ashanti' },
      } as any);

      const result = await marketplaceService.browse({
        sort: 'date',
        order: 'desc',
        page: 1,
        limit: 20,
      } as any);

      expect(result.listings[0]).toMatchObject({ farmerName: 'Ama Boateng', farmerRegion: 'Ashanti' });
      expect(result.pagination).toEqual({ page: 1, limit: 20, total: 1, totalPages: 1 });
    });

    it('resolves a region filter to farmer IDs before querying listings', async () => {
      mockUsers.findFarmerIdsByRegion.mockResolvedValue(['farmer-1', 'farmer-2']);
      mockListings.findActive.mockResolvedValue({ listings: [], total: 0 });

      await marketplaceService.browse({
        region: 'Ashanti',
        sort: 'date',
        order: 'desc',
        page: 1,
        limit: 20,
      } as any);

      expect(mockUsers.findFarmerIdsByRegion).toHaveBeenCalledWith('Ashanti');
      expect(mockListings.findActive).toHaveBeenCalledWith(
        expect.objectContaining({ farmerIds: ['farmer-1', 'farmer-2'] }),
      );
    });

    it('reports zero total pages when there are no matching listings', async () => {
      mockListings.findActive.mockResolvedValue({ listings: [], total: 0 });

      const result = await marketplaceService.browse({ sort: 'date', order: 'desc', page: 1, limit: 20 } as any);

      expect(result.pagination.totalPages).toBe(0);
    });
  });

  describe('getListingDetail', () => {
    it('returns the enriched listing when active', async () => {
      mockListings.findById.mockResolvedValue(baseListing);
      mockUsers.findById.mockResolvedValue({ id: 'farmer-1', name: 'Ama Boateng', profile: {} } as any);

      const result = await marketplaceService.getListingDetail('listing-1');

      expect(result).toMatchObject({ id: 'listing-1', farmerName: 'Ama Boateng' });
    });

    it('throws NotFoundError if the listing does not exist', async () => {
      mockListings.findById.mockResolvedValue(null);
      await expect(marketplaceService.getListingDetail('missing')).rejects.toThrow(NotFoundError);
    });

    it('throws NotFoundError if the listing is not ACTIVE (e.g. already sold)', async () => {
      mockListings.findById.mockResolvedValue({ ...baseListing, status: 'SOLD' as any });
      await expect(marketplaceService.getListingDetail('listing-1')).rejects.toThrow(NotFoundError);
    });
  });
});
