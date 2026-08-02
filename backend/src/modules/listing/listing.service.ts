import crypto from 'crypto';
import QRCode from 'qrcode';
import { ForbiddenError, NotFoundError, PayoutNotConfiguredError } from '../../utils/errors';
import { auditService } from '../audit/audit.service';
import logger from '../../utils/logger';
import { s3Service, PresignedUploadUrlResult } from '../../services/s3.service';
import { userRepository } from '../user/user.repository.prisma';
import { CreateListingInput, UpdateListingInput } from './listing.schema';
import { IListingRepository } from './listing.repository';
import { listingRepository } from './listing.repository.prisma';
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

/**
 * Records an audit entry without letting its failure undo work already committed.
 *
 * The listing is written and committed before the audit entry is attempted, so
 * by that point it is durable and already visible in the marketplace. Rethrowing
 * returned a 500 for a listing that had in fact been created, and farmers
 * retried and produced duplicates.
 *
 * The audit gap is logged at error level rather than swallowed: a missing entry
 * breaks the hash chain and someone has to know.
 *
 * Now that listings and the audit trail share a database, the better fix is to
 * write both inside one `prisma.$transaction` and delete this wrapper. That
 * needs AuditService.log to accept a transaction client, which it does not yet —
 * tracked as follow-up work rather than folded into the persistence migration.
 *
 * Deliberately NOT applied to transaction/dispute/dispatch — those already call
 * auditService.log inside a `prisma.$transaction`, where a failed audit write
 * must roll the whole operation back.
 */
const auditNonFatal = async (operation: string, entityId: string, run: () => Promise<unknown>): Promise<void> => {
  try {
    await run();
  } catch (err) {
    logger.error(
      `[Audit] Failed to record ${operation} for ${entityId} — the operation succeeded but its audit entry is missing, breaking the hash chain:`,
      err,
    );
  }
};

export class ListingService {
  constructor(private readonly repo: IListingRepository) {}

  /** Presigned S3 PUT URL for a crop photo — same public bucket/flow as profile photos. */
  getPhotoUploadUrl(fileName: string, contentType: string): Promise<PresignedUploadUrlResult> {
    return s3Service.generatePublicUploadUrl(fileName, contentType);
  }

  async createListing(data: CreateListingInput, farmerId: string): Promise<Listing> {
    const farmer = await userRepository.findById(farmerId);
    if (!farmer?.profile.momoNumber) {
      throw new PayoutNotConfiguredError();
    }

    const { listingHash, qrCodeData } = await generateListingProof(farmerId, data);

    const listing = await this.repo.create({
      farmerId,
      ...data,
      listingHash,
      qrCodeData,
      status: 'ACTIVE',
    });

    await auditNonFatal('LISTING_CREATED', listing.id, () =>
      auditService.log('LISTING_CREATED', listing.id, { cropType: data.cropType, quantityKg: data.quantityKg, pricePerKg: data.pricePerKg }, farmerId),
    );

    return listing;
  }

  getFarmerListings(farmerId: string): Promise<Listing[]> {
    return this.repo.findManyByFarmer(farmerId);
  }

  getListingById(id: string): Promise<Listing | null> {
    return this.repo.findById(id);
  }

  async updateListing(id: string, farmerId: string, data: UpdateListingInput): Promise<Listing> {
    const listing = await this.assertOwnedListing(id, farmerId);
    const updated = await this.repo.update(listing.id, data);
    await auditNonFatal('LISTING_UPDATED', listing.id, () => auditService.log('LISTING_UPDATED', listing.id, data, farmerId));
    return updated;
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

export const listingService = new ListingService(listingRepository);
