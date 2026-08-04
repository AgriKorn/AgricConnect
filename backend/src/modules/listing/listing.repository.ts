import { Listing } from './listing.types';

// cropCategory is excluded: it is derived from the crop_types row the listing
// resolves to, never supplied by the caller. region is added (not part of the
// public Listing shape) so the service layer can pass the farmer's real
// region through for storage — the repository has no user lookup of its own.
export type CreateListingRecord = Omit<Listing, 'id' | 'createdAt' | 'updatedAt' | 'cropCategory'> & {
  region?: string;
  /** Real MOFA reference price for this crop/region, when one is on file — undefined when there isn't one yet. */
  mofaReferencePrice?: number;
};
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
  markSold(id: string): Promise<Listing>;
}
