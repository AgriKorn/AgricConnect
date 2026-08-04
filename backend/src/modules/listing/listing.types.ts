export type ListingStatus = 'ACTIVE' | 'INACTIVE' | 'SOLD';

export interface Listing {
  id: string;
  farmerId: string;
  cropType: string;
  /**
   * The crop's category ('vegetables', 'grains', 'fruits', 'tubers'), taken from
   * crop_types. Exposed because the marketplace filters by category: without it
   * the client can only guess from the crop name, and every crop falls through
   * to the same default.
   */
  cropCategory: string | null;
  quantityKg: number;
  freshnessScore: number;
  shelfLifeDays: number;
  farmerLat: number;
  farmerLong: number;
  pricePerKg: number;
  listingHash: string;
  qrCodeData: string;
  /** Cover image: the first gallery image, or the legacy single photo — undefined until one is uploaded. */
  imageUrl?: string;
  /** Full gallery of public S3 URLs (SRS "Produce Upload": multiple images). Empty until any are uploaded. */
  imageUrls: string[];
  /** Free-text details the farmer added — null until they write one. */
  description?: string | null;
  status: ListingStatus;
  createdAt: Date;
  updatedAt: Date;
}
