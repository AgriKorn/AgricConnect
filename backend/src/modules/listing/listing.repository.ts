import { Listing } from './listing.types';

export type CreateListingRecord = Omit<Listing, 'id' | 'createdAt' | 'updatedAt'>;
export type UpdateListingRecord = Partial<Pick<Listing, 'pricePerKg' | 'quantityKg'>>;

export interface IListingRepository {
  create(data: CreateListingRecord): Promise<Listing>;
  findManyByFarmer(farmerId: string): Promise<Listing[]>;
  findById(id: string): Promise<Listing | null>;
  update(id: string, data: UpdateListingRecord): Promise<Listing>;
  softDelete(id: string): Promise<Listing>;
}
