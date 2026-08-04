import { prisma } from '../../config/db';
import { CreateListingRecord, IListingRepository, ListingFilters, UpdateListingRecord } from './listing.repository';
import { Listing } from './listing.types';
import { Prisma } from '../../generated/prisma/client';

const mapPrismaToListing = (p: any): Listing => ({
  id: p.id,
  farmerId: p.farmer_id,
  cropType: p.crop_types?.name || 'unknown',
  cropCategory: p.crop_types?.category ?? null,
  quantityKg: Number(p.quantity_kg),
  freshnessScore: Number(p.freshness_score),
  shelfLifeDays: p.estimated_viable_days,
  farmerLat: Number(p.gps_lat),
  farmerLong: Number(p.gps_lng),
  pricePerKg: Number(p.listed_price),
  listingHash: p.listing_hash ? p.listing_hash.trim() : '',
  qrCodeData: p.qr_code_data || '',
  imageUrl: p.photo_url || undefined,
  description: p.description ?? null,
  status: p.status === 'sold' ? 'SOLD' : p.status === 'active' ? 'ACTIVE' : 'INACTIVE',
  createdAt: p.created_at,
  updatedAt: p.updated_at,
});

export class PrismaListingRepository implements IListingRepository {
  async create(data: CreateListingRecord): Promise<Listing> {
    // Add Listing is a free-text "Crop / Produce Name" field, not a picker
    // bound to this lookup table — rejecting anything not already seeded
    // (mango, okra, groundnut, ...) was blocking real produce a farmer
    // actually grows. Reuse an existing row case-insensitively so "Tomato"
    // and "tomato" don't fork into duplicates; only create a new one
    // (always lowercased, for consistency) when it's genuinely new.
    let crop = await prisma.crop_types.findFirst({
      where: { name: { equals: data.cropType, mode: 'insensitive' } },
    });

    if (!crop) {
      crop = await prisma.crop_types.create({
        data: { name: data.cropType.trim().toLowerCase() },
      });
    }

    // Anchor the ceiling/floor to a real government reference price when one
    // exists for this crop and region — without it there's no real market
    // data to compare against, so fall back to a plain band around the
    // farmer's own price rather than mislabeling that as a MOFA reference.
    const referencePrice = data.mofaReferencePrice ?? data.pricePerKg;

    const created = await prisma.produce_listings.create({
      data: {
        farmer_id: data.farmerId,
        crop_type_id: crop.id,
        quantity_kg: new Prisma.Decimal(data.quantityKg),
        region: data.region || 'Greater Accra',
        gps_lat: new Prisma.Decimal(data.farmerLat),
        gps_lng: new Prisma.Decimal(data.farmerLong),
        freshness_score: new Prisma.Decimal(data.freshnessScore),
        estimated_viable_days: data.shelfLifeDays,
        mofa_reference_price: new Prisma.Decimal(referencePrice),
        price_ceiling: new Prisma.Decimal(referencePrice * 1.2),
        price_floor: new Prisma.Decimal(referencePrice * 0.8),
        listed_price: new Prisma.Decimal(data.pricePerKg),
        listing_hash: data.listingHash,
        qr_code_data: data.qrCodeData,
        ...(data.imageUrl && { photo_url: data.imageUrl }),
        ...(data.description && { description: data.description }),
        status: 'active',
      },
      include: { crop_types: true },
    });

    return mapPrismaToListing(created);
  }

  async findManyByFarmer(farmerId: string): Promise<Listing[]> {
    // Excludes 'cancelled' (soft-deleted) — otherwise a deleted listing maps
    // to the generic INACTIVE status and reappears mislabeled as "Pending"
    // instead of actually disappearing from the farmer's own list.
    const list = await prisma.produce_listings.findMany({
      where: { farmer_id: farmerId, status: { not: 'cancelled' } },
      include: { crop_types: true },
      orderBy: { created_at: 'desc' },
    });
    return list.map(mapPrismaToListing);
  }

  async findActive(filters: ListingFilters): Promise<{ listings: Listing[]; total: number }> {
    const where: any = { status: 'active' };

    if (filters.crop) {
      where.crop_types = { name: { equals: filters.crop, mode: 'insensitive' } };
    }
    // Both bounds go in one object: assigning freshness_score twice would drop
    // whichever was written first.
    if (filters.minFreshness !== undefined || filters.maxFreshness !== undefined) {
      where.freshness_score = {
        ...(filters.minFreshness !== undefined && { gte: filters.minFreshness }),
        ...(filters.maxFreshness !== undefined && { lte: filters.maxFreshness }),
      };
    }
    if (filters.minQuantity !== undefined) {
      where.quantity_kg = { gte: filters.minQuantity };
    }
    // An empty farmerIds means the region filter matched no farmers, which must
    // return nothing. Skipping the clause on empty (`length > 0`) dropped the
    // region filter entirely, so browsing a region with no farmers returned
    // every listing in the country.
    if (filters.farmerIds !== undefined) {
      where.farmer_id = { in: filters.farmerIds };
    }

    let orderBy: any = { created_at: filters.order };
    if (filters.sort === 'freshness') {
      orderBy = { freshness_score: filters.order };
    } else if (filters.sort === 'price') {
      orderBy = { listed_price: filters.order };
    }

    const [list, total] = await Promise.all([
      prisma.produce_listings.findMany({
        where,
        include: { crop_types: true },
        orderBy,
        skip: (filters.page - 1) * filters.limit,
        take: filters.limit,
      }),
      prisma.produce_listings.count({ where }),
    ]);

    return { listings: list.map(mapPrismaToListing), total };
  }

  async findAllActive(): Promise<Listing[]> {
    const list = await prisma.produce_listings.findMany({
      where: { status: 'active' },
      include: { crop_types: true },
    });
    return list.map(mapPrismaToListing);
  }

  async findById(id: string): Promise<Listing | null> {
    const found = await prisma.produce_listings.findUnique({
      where: { id },
      include: { crop_types: true },
    });
    return found ? mapPrismaToListing(found) : null;
  }

  async update(id: string, data: UpdateListingRecord): Promise<Listing> {
    const updateData: any = {};
    if (data.pricePerKg !== undefined) updateData.listed_price = new Prisma.Decimal(data.pricePerKg);
    if (data.quantityKg !== undefined) updateData.quantity_kg = new Prisma.Decimal(data.quantityKg);

    const updated = await prisma.produce_listings.update({
      where: { id },
      data: updateData,
      include: { crop_types: true },
    });
    return mapPrismaToListing(updated);
  }

  async softDelete(id: string): Promise<Listing> {
    const updated = await prisma.produce_listings.update({
      where: { id },
      data: { status: 'cancelled' },
      include: { crop_types: true },
    });
    return mapPrismaToListing(updated);
  }

  async markSold(id: string): Promise<Listing> {
    const updated = await prisma.produce_listings.update({
      where: { id },
      data: { status: 'sold', sold_at: new Date() },
      include: { crop_types: true },
    });
    return mapPrismaToListing(updated);
  }
}

export const listingRepository = new PrismaListingRepository();
