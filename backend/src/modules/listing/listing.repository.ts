import { Listing } from './listing.types';

export type CreateListingRecord = Omit<Listing, 'id' | 'createdAt' | 'updatedAt'>;
export type UpdateListingRecord = Partial<Pick<Listing, 'pricePerKg' | 'quantityKg'>>;

export interface ListingFilters {
  crop?: string;
  minFreshness?: number;
  maxFreshness?: number;
  minQuantity?: number;
  farmerIds?: string[];
  sort: 'date' | 'freshness' | 'price';
  order: 'asc' | 'desc';
  page: number;
  limit: number;
}

export interface IListingRepository {
  create(data: CreateListingRecord): Promise<Listing>;
  findManyByFarmer(farmerId: string): Promise<Listing[]>;
  findActive(filters: ListingFilters): Promise<{ listings: Listing[]; total: number }>;
  findById(id: string): Promise<Listing | null>;
  update(id: string, data: UpdateListingRecord): Promise<Listing>;
  softDelete(id: string): Promise<Listing>;
}
