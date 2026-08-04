import { randomUUID } from 'crypto';
import { NotFoundError } from '../../utils/errors';
import { Listing } from './listing.types';
import { CreateListingRecord, IListingRepository, ListingFilters, UpdateListingRecord } from './listing.repository';

/**
 * Temporary in-memory store standing in for the Prisma-backed repository.
 * Swap this for a PrismaListingRepository once schema.prisma exists (K3/K4) —
 * ListingService and MarketplaceService only depend on IListingRepository,
 * so nothing else changes.
 */
export class InMemoryListingRepository implements IListingRepository {
  private readonly listings = new Map<string, Listing>();

  async create(data: CreateListingRecord): Promise<Listing> {
    const now = new Date();
    const listing: Listing = {
      id: randomUUID(),
      ...data,
      // No crop_types table to resolve against in memory; the Prisma repository
      // fills this from the joined crop row.
      cropCategory: null,
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

  async findAllActive(): Promise<Listing[]> {
    return [...this.listings.values()].filter((listing) => listing.status === 'ACTIVE');
  }

  async findActive(filters: ListingFilters): Promise<{ listings: Listing[]; total: number }> {
    let results = [...this.listings.values()].filter((listing) => listing.status === 'ACTIVE');

    if (filters.crop) results = results.filter((l) => l.cropType.toLowerCase() === filters.crop!.toLowerCase());
    if (filters.minFreshness !== undefined) results = results.filter((l) => l.freshnessScore >= filters.minFreshness!);
    if (filters.maxFreshness !== undefined) results = results.filter((l) => l.freshnessScore <= filters.maxFreshness!);
    if (filters.minQuantity !== undefined) results = results.filter((l) => l.quantityKg >= filters.minQuantity!);
    if (filters.farmerIds) results = results.filter((l) => filters.farmerIds!.includes(l.farmerId));

    const sortKey = filters.sort === 'freshness' ? 'freshnessScore' : filters.sort === 'price' ? 'pricePerKg' : 'createdAt';
    const direction = filters.order === 'asc' ? 1 : -1;
    results.sort((a, b) => {
      const aVal = a[sortKey] as number | Date;
      const bVal = b[sortKey] as number | Date;
      const aNum = aVal instanceof Date ? aVal.getTime() : aVal;
      const bNum = bVal instanceof Date ? bVal.getTime() : bVal;
      return (aNum - bNum) * direction;
    });

    const total = results.length;
    const start = (filters.page - 1) * filters.limit;
    const listings = results.slice(start, start + filters.limit);

    return { listings, total };
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

  async markSold(id: string): Promise<Listing> {
    const existing = this.listings.get(id);
    if (!existing) throw new NotFoundError('Listing not found');
    const updated: Listing = { ...existing, status: 'SOLD', updatedAt: new Date() };
    this.listings.set(id, updated);
    return updated;
  }
}

// Shared singleton — the listing and marketplace modules read/write the same store.
export const listingRepository = new InMemoryListingRepository();
