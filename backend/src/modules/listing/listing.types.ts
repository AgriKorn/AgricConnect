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
  /** Farmer's registered region at the time of listing — drives the MOFA price lookup below. */
  region: string;
  pricePerKg: number;
  /** MOFA reference price (GHS/kg) the farmer's chosen pricePerKg was checked against. */
  mofaReferencePrice: number;
  /** Upper bound of the recommended range; pricePerKg above this is rejected (see ListingService.createListing). */
  priceCeiling: number;
  /** Lower bound of the recommended range; pricePerKg below this is allowed but flagged via belowFloorAcknowledged. */
  priceFloor: number;
  /** True when pricePerKg was below priceFloor at creation time. */
  belowFloorAcknowledged: boolean;
  listingHash: string;
  qrCodeData: string;
  status: ListingStatus;
  createdAt: Date;
  updatedAt: Date;
}
