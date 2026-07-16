import crypto from 'crypto';
import QRCode from 'qrcode';
import { ForbiddenError, NotFoundError } from '../../utils/errors';
import { CreateListingInput, UpdateListingInput } from './listing.schema';
import { IListingRepository } from './listing.repository';
import { InMemoryListingRepository } from './listing.repository.memory';
import { Listing } from './listing.types';

/**
 * Generates the listing's SHA-256 fingerprint and its QR code representation.
 * The QR code is what the farmer shows at delivery for hash verification.
 */
const generateListingProof = async (farmerId: string, data: CreateListingInput) => {
  const hashInput = {
    farmerId,
    cropType: data.cropType,
    quantityKg: data.quantityKg,
    freshnessScore: data.freshnessScore,
    pricePerKg: data.pricePerKg,
    timestamp: new Date().toISOString(),
  };
  const listingHash = crypto.createHash('sha256').update(JSON.stringify(hashInput)).digest('hex');
  const qrCodeData = await QRCode.toDataURL(listingHash);
  return { listingHash, qrCodeData };
};

export class ListingService {
  constructor(private readonly repo: IListingRepository) {}

  async createListing(data: CreateListingInput, farmerId: string): Promise<Listing> {
    const { listingHash, qrCodeData } = await generateListingProof(farmerId, data);

    return this.repo.create({
      farmerId,
      ...data,
      listingHash,
      qrCodeData,
      status: 'ACTIVE',
    });
  }

  getFarmerListings(farmerId: string): Promise<Listing[]> {
    return this.repo.findManyByFarmer(farmerId);
  }

  getListingById(id: string): Promise<Listing | null> {
    return this.repo.findById(id);
  }

  async updateListing(id: string, farmerId: string, data: UpdateListingInput): Promise<Listing> {
    const listing = await this.assertOwnedListing(id, farmerId);
    return this.repo.update(listing.id, data);
  }

  async deleteListing(id: string, farmerId: string): Promise<Listing> {
    const listing = await this.assertOwnedListing(id, farmerId);
    return this.repo.softDelete(listing.id);
  }

  private async assertOwnedListing(id: string, farmerId: string): Promise<Listing> {
    const listing = await this.repo.findById(id);
    if (!listing) throw new NotFoundError('Listing not found');
    if (listing.farmerId !== farmerId) throw new ForbiddenError('You can only modify your own listings');
    return listing;
  }
}

// Swap InMemoryListingRepository for a PrismaListingRepository once schema.prisma exists.
export const listingService = new ListingService(new InMemoryListingRepository());
