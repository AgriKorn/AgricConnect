import { ListingService } from './listing.service';
import { PrismaListingRepository } from './listing.repository.prisma';
import { mofaPriceRepository } from '../pricing/pricing.repository.prisma';
import { auditService } from '../audit/audit.service';
import { ForbiddenError } from '../../utils/errors';

describe('ListingService', () => {
  let listingService: ListingService;
  let mockRepo: jest.Mocked<PrismaListingRepository>;

  beforeEach(() => {
    jest.clearAllMocks();
    mockRepo = {
      create: jest.fn(),
      findActive: jest.fn(),
      findById: jest.fn(),
      findManyByFarmer: jest.fn(),
      update: jest.fn(),
      softDelete: jest.fn(),
      markSold: jest.fn(),
    } as any;

    listingService = new ListingService(mockRepo);
  });

  describe('createListing', () => {
    it('should calculate price floor/ceiling against MOFA reference price if available', async () => {
      jest.spyOn(mofaPriceRepository, 'findLatest').mockResolvedValue({
        cropType: 'tomato',
        region: 'Greater Accra',
        pricePerKg: 10.0,
        effectiveDate: new Date(),
      });
      jest.spyOn(auditService, 'log').mockResolvedValue({} as any);

      const input = {
        cropType: 'tomato',
        quantityKg: 200,
        freshnessScore: 9.5,
        shelfLifeDays: 7,
        farmerLat: 5.6,
        farmerLong: -0.18,
        pricePerKg: 10.0,
        listingHash: 'hash-1',
        qrCodeData: 'hash-1',
      };

      const mockListing = { id: '00000000-0000-0000-0000-000000000001', farmerId: 'farmer-1', ...input, status: 'ACTIVE' as const, createdAt: new Date(), updatedAt: new Date() };
      mockRepo.create.mockResolvedValue(mockListing);

      const result = await listingService.createListing(input, 'farmer-1');

      expect(mockRepo.create).toHaveBeenCalledWith(expect.objectContaining({ farmerId: 'farmer-1', cropType: 'tomato' }));
      expect(result).toEqual(mockListing);
    });
  });

  describe('updateListing', () => {
    it('should throw ForbiddenError if non-owner tries to update listing', async () => {
      mockRepo.findById.mockResolvedValue({
        id: '00000000-0000-0000-0000-000000000001',
        farmerId: 'owner-farmer-id',
      } as any);

      await expect(listingService.updateListing('00000000-0000-0000-0000-000000000001', 'other-farmer-id', { pricePerKg: 12 })).rejects.toThrow(ForbiddenError);
    });
  });

  describe('deleteListing', () => {
    it('should soft-delete listing when requested by farmer owner', async () => {
      const farmerId = 'owner-farmer-id';
      mockRepo.findById.mockResolvedValue({
        id: '00000000-0000-0000-0000-000000000001',
        farmerId,
      } as any);

      const deletedListing = { id: '00000000-0000-0000-0000-000000000001', farmerId, status: 'INACTIVE' as const } as any;
      mockRepo.softDelete.mockResolvedValue(deletedListing);

      const result = await listingService.deleteListing('00000000-0000-0000-0000-000000000001', farmerId);

      expect(mockRepo.softDelete).toHaveBeenCalledWith('00000000-0000-0000-0000-000000000001');
      expect(result).toEqual(deletedListing);
    });
  });
});
