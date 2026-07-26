export type ListingStatus = 'ACTIVE' | 'INACTIVE' | 'SOLD';

export interface Listing {
  id: string;
  farmerId: string;
  cropType: string;
  quantityKg: number;
  freshnessScore: number;
  shelfLifeDays: number;
  farmerLat: number;
  farmerLong: number;
  pricePerKg: number;
  listingHash: string;
  qrCodeData: string;
  status: ListingStatus;
  createdAt: Date;
  updatedAt: Date;
}
