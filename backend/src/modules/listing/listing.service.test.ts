import { ListingService } from './listing.service';
import { PrismaListingRepository } from './listing.repository.prisma';
import { auditService } from '../audit/audit.service';
import { BadRequestError, ForbiddenError } from '../../utils/errors';
import { User } from '../user/user.types';

describe('ListingService', () => {
  let listingService: ListingService;
  let mockRepo: jest.Mocked<PrismaListingRepository>;
  let mockUsers: { findById: jest.Mock };
  let mockPricing: { recommend: jest.Mock };

  const mockFarmer = (region: string | undefined): User =>
    ({
      id: 'farmer-1',
      profile: { farmRegion: region },
    }) as unknown as User;

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
    mockUsers = { findById: jest.fn() };
    mockPricing = { recommend: jest.fn() };

    listingService = new ListingService(mockRepo, mockUsers as any, mockPricing as any);
  });

  describe('createListing', () => {
    const input = {
      cropType: 'tomato',
      quantityKg: 200,
      freshnessScore: 90,
      shelfLifeDays: 7,
      farmerLat: 5.6,
      farmerLong: -0.18,
      pricePerKg: 9.0,
      listingHash: 'hash-1',
      qrCodeData: 'hash-1',
    };

    it("looks up the farmer's real region and checks pricePerKg against the real MOFA-anchored range, not a self-derived one", async () => {
      mockUsers.findById.mockResolvedValue(mockFarmer('Ashanti'));
      mockPricing.recommend.mockResolvedValue({ mofaPrice: 10.0, ceiling: 9.0, softFloor: 6.0 });
      jest.spyOn(auditService, 'log').mockResolvedValue({} as any);

      const mockListing = {
        id: '00000000-0000-0000-0000-000000000001',
        farmerId: 'farmer-1',
        ...input,
        region: 'Ashanti',
        mofaReferencePrice: 10.0,
        priceCeiling: 9.0,
        priceFloor: 6.0,
        belowFloorAcknowledged: false,
        cropCategory: 'vegetables',
        status: 'ACTIVE' as const,
        createdAt: new Date(),
        updatedAt: new Date(),
      };
      mockRepo.create.mockResolvedValue(mockListing);

      const result = await listingService.createListing(input, 'farmer-1');

      expect(mockPricing.recommend).toHaveBeenCalledWith({
        crop: 'tomato',
        region: 'Ashanti',
        freshness: 90,
        shelfLifeDays: 7,
      });
      expect(mockRepo.create).toHaveBeenCalledWith(
        expect.objectContaining({
          region: 'Ashanti',
          mofaReferencePrice: 10.0,
          priceCeiling: 9.0,
          priceFloor: 6.0,
          belowFloorAcknowledged: false,
        }),
      );
      expect(result).toEqual(mockListing);
    });

    it('falls back to the default region if the farmer has none on file', async () => {
      mockUsers.findById.mockResolvedValue(mockFarmer(undefined));
      mockPricing.recommend.mockResolvedValue({ mofaPrice: 10.0, ceiling: 9.0, softFloor: 6.0 });
      jest.spyOn(auditService, 'log').mockResolvedValue({} as any);
      mockRepo.create.mockResolvedValue({ id: 'x' } as any);

      await listingService.createListing(input, 'farmer-1');

      expect(mockPricing.recommend).toHaveBeenCalledWith(expect.objectContaining({ region: 'Greater Accra' }));
    });

    it('rejects a price above the ceiling', async () => {
      mockUsers.findById.mockResolvedValue(mockFarmer('Ashanti'));
      mockPricing.recommend.mockResolvedValue({ mofaPrice: 10.0, ceiling: 9.0, softFloor: 6.0 });

      await expect(listingService.createListing({ ...input, pricePerKg: 9.01 }, 'farmer-1')).rejects.toThrow(BadRequestError);
      expect(mockRepo.create).not.toHaveBeenCalled();
    });

    it('allows a price below the floor but flags belowFloorAcknowledged', async () => {
      mockUsers.findById.mockResolvedValue(mockFarmer('Ashanti'));
      mockPricing.recommend.mockResolvedValue({ mofaPrice: 10.0, ceiling: 9.0, softFloor: 6.0 });
      jest.spyOn(auditService, 'log').mockResolvedValue({} as any);
      mockRepo.create.mockResolvedValue({ id: 'x' } as any);

      await listingService.createListing({ ...input, pricePerKg: 5.0 }, 'farmer-1');

      expect(mockRepo.create).toHaveBeenCalledWith(expect.objectContaining({ belowFloorAcknowledged: true }));
    });

    it('should still return the created listing when the audit write fails', async () => {
      // Regression: listings commit to their repository before the audit entry
      // is attempted, so rethrowing here returned a 500 for a listing that had
      // in fact been created — farmers retried and produced duplicates.
      mockUsers.findById.mockResolvedValue(mockFarmer('Ashanti'));
      mockPricing.recommend.mockResolvedValue({ mofaPrice: 10.0, ceiling: 9.0, softFloor: 6.0 });
      jest.spyOn(auditService, 'log').mockRejectedValue(new Error('audit database unreachable'));

      const mockListing = {
        id: '00000000-0000-0000-0000-000000000001',
        farmerId: 'farmer-1',
        ...input,
        region: 'Ashanti',
        mofaReferencePrice: 10.0,
        priceCeiling: 9.0,
        priceFloor: 6.0,
        belowFloorAcknowledged: false,
        cropCategory: 'vegetables',
        status: 'ACTIVE' as const,
        createdAt: new Date(),
        updatedAt: new Date(),
      };
      mockRepo.create.mockResolvedValue(mockListing);

      const result = await listingService.createListing(input, 'farmer-1');

      expect(result).toEqual(mockListing);
      expect(auditService.log).toHaveBeenCalled();
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

    it('should still return the updated listing when the audit write fails', async () => {
      const farmerId = 'owner-farmer-id';
      mockRepo.findById.mockResolvedValue({ id: '00000000-0000-0000-0000-000000000001', farmerId } as any);

      const updated = { id: '00000000-0000-0000-0000-000000000001', farmerId, pricePerKg: 12 } as any;
      mockRepo.update.mockResolvedValue(updated);
      jest.spyOn(auditService, 'log').mockRejectedValue(new Error('audit database unreachable'));

      const result = await listingService.updateListing('00000000-0000-0000-0000-000000000001', farmerId, { pricePerKg: 12 });

      expect(result).toEqual(updated);
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
