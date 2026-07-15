import crypto from 'crypto';
import QRCode from 'qrcode';
import prisma from '../../config/prisma';
import { CreateListingInput, UpdateListingInput } from './listing.schema';

/**
 * Creates a new agricultural listing, generating a unique SHA-256 hash
 * and a corresponding QR Code based on the listing data.
 * 
 * Cryptographic Hashing Step:
 * We use a SHA-256 hash to create a unique, immutable fingerprint of the listing
 * at the time of creation. This hash combines the farmer's ID, the crop type, 
 * quantity, price, and the current timestamp. By turning this hash into a QR code, 
 * buyers or logistics handlers can scan it to verify the listing's authenticity 
 * and origin, ensuring the data hasn't been tampered with.
 *
 * @param {CreateListingInput} data - Validated listing data
 * @param {string} farmerUserId - The authenticated farmer's user ID
 * @returns {Promise<any>} The newly created listing record
 */
export const createListing = async (data: CreateListingInput, farmerUserId: string) => {
  // 1. Generate the unique fingerprint for the listing
  const timestamp = Date.now().toString();
  const rawDataToHash = `${farmerUserId}:${data.crop_type}:${data.quantity_kg}:${data.price_per_kg}:${timestamp}`;
  
  const hash = crypto.createHash('sha256').update(rawDataToHash).digest('hex');

  // 2. Generate a QR code from the SHA-256 hash
  // We use toDataURL to store the image representation directly as a base64 string.
  const qrCodeDataUrl = await QRCode.toDataURL(hash);

  // 3. Save everything to the database
  const newListing = await prisma.listing.create({
    data: {
      farmer_user_id: farmerUserId,
      crop_type: data.crop_type,
      quantity_kg: data.quantity_kg,
      freshness_score: data.freshness_score,
      shelf_life_days: data.shelf_life_days,
      farmer_lat: data.farmer_lat,
      farmer_long: data.farmer_long,
      price_per_kg: data.price_per_kg,
      qr_code_data: qrCodeDataUrl,
      listing_status: 'ACTIVE',
      // price_ceiling and price_floor are calculated by the Price Engine later, left as null
    },
  });

  return newListing;
};

/**
 * Retrieves all active listings for a specific farmer.
 * 
 * @param {string} farmerUserId - The authenticated farmer's user ID
 * @returns {Promise<any[]>} Array of active listing records
 */
export const getFarmerListings = async (farmerUserId: string) => {
  return prisma.listing.findMany({
    where: {
      farmer_user_id: farmerUserId,
      listing_status: 'ACTIVE',
    },
    orderBy: {
      created_at: 'desc'
    }
  });
};

/**
 * Retrieves a single listing by its unique ID.
 * 
 * @param {string} listingId - The UUID of the listing
 * @returns {Promise<any | null>} The listing record, or null if not found
 */
export const getListingById = async (listingId: string) => {
  return prisma.listing.findUnique({
    where: {
      listing_id: listingId,
    },
  });
};

/**
 * Updates a listing with allowed optional fields.
 * 
 * @param {string} listingId - The UUID of the listing to update
 * @param {UpdateListingInput} updateData - Validated optional fields (price_per_kg, quantity_kg)
 * @returns {Promise<any>} The updated listing record
 */
export const updateListing = async (listingId: string, updateData: UpdateListingInput) => {
  return prisma.listing.update({
    where: {
      listing_id: listingId,
    },
    data: {
      ...updateData,
    },
  });
};

/**
 * Performs a soft delete on a listing by changing its status to INACTIVE.
 * Never physically deletes the record to maintain historical auditing and referential integrity.
 * 
 * @param {string} listingId - The UUID of the listing to softly delete
 * @returns {Promise<any>} The softly deleted listing record
 */
export const softDeleteListing = async (listingId: string) => {
  return prisma.listing.update({
    where: {
      listing_id: listingId,
    },
    data: {
      listing_status: 'INACTIVE',
    },
  });
};
