import { randomUUID } from 'crypto';
import { NotFoundError } from '../../utils/errors';
import { Listing } from './listing.types';
import { CreateListingRecord, IListingRepository, UpdateListingRecord } from './listing.repository';

/**
 * Temporary in-memory store standing in for the Prisma-backed repository.
 * Swap this for a PrismaListingRepository once schema.prisma exists (K3/K4) —
 * ListingService only depends on IListingRepository, so nothing else changes.
 */
export class InMemoryListingRepository implements IListingRepository {
  private readonly listings = new Map<string, Listing>();

  async create(data: CreateListingRecord): Promise<Listing> {
    const now = new Date();
    const listing: Listing = {
      id: randomUUID(),
      ...data,
      createdAt: now,
      updatedAt: now,
    };
    this.listings.set(listing.id, listing);
    return listing;
  }

  async findManyByFarmer(farmerId: string): Promise<Listing[]> {
    return [...this.listings.values()]
      .filter((listing) => listing.farmerId === farmerId && listing.status === 'ACTIVE')
      .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
  }

  async findById(id: string): Promise<Listing | null> {
    return this.listings.get(id) ?? null;
  }

  async update(id: string, data: UpdateListingRecord): Promise<Listing> {
    const existing = this.listings.get(id);
    if (!existing) throw new NotFoundError('Listing not found');
    const updated: Listing = { ...existing, ...data, updatedAt: new Date() };
    this.listings.set(id, updated);
    return updated;
  }

  async softDelete(id: string): Promise<Listing> {
    const existing = this.listings.get(id);
    if (!existing) throw new NotFoundError('Listing not found');
    const updated: Listing = { ...existing, status: 'INACTIVE', updatedAt: new Date() };
    this.listings.set(id, updated);
    return updated;
  }
}
