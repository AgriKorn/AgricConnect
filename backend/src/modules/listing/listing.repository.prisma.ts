import { prisma } from '../../config/db';
import { BadRequestError } from '../../utils/errors';
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
  region: p.region,
  pricePerKg: Number(p.listed_price),
  mofaReferencePrice: Number(p.mofa_reference_price),
  priceCeiling: Number(p.price_ceiling),
  priceFloor: Number(p.price_floor),
  belowFloorAcknowledged: p.below_floor_acknowledged,
  listingHash: p.listing_hash ? p.listing_hash.trim() : '',
  qrCodeData: p.qr_code_data || '',
  status: p.status === 'sold' ? 'SOLD' : p.status === 'active' ? 'ACTIVE' : 'INACTIVE',
  createdAt: p.created_at,
  updatedAt: p.updated_at,
});

export class PrismaListingRepository implements IListingRepository {
  async create(data: CreateListingRecord): Promise<Listing> {
    const crop = await prisma.crop_types.findFirst({
      where: { name: { equals: data.cropType, mode: 'insensitive' } },
    });

    if (!crop) {
      const validCrops = await prisma.crop_types.findMany({ select: { name: true } });
      const cropList = validCrops.map((c) => c.name).join(', ');
      throw new BadRequestError(`Unknown crop type '${data.cropType}'. Valid choices are: ${cropList}`);
    }

    const created = await prisma.produce_listings.create({
      data: {
        farmer_id: data.farmerId,
        crop_type_id: crop.id,
        quantity_kg: new Prisma.Decimal(data.quantityKg),
        region: data.region,
        gps_lat: new Prisma.Decimal(data.farmerLat),
        gps_lng: new Prisma.Decimal(data.farmerLong),
        freshness_score: new Prisma.Decimal(data.freshnessScore),
        estimated_viable_days: data.shelfLifeDays,
        // mofa_reference_price/price_ceiling/price_floor come from
        // ListingService.createListing's real PricingService lookup — do not
        // re-derive these from listed_price here, that was the original bug
        // (a listing's own price validating itself against a range built
        // from that same price).
        mofa_reference_price: new Prisma.Decimal(data.mofaReferencePrice),
        price_ceiling: new Prisma.Decimal(data.priceCeiling),
        price_floor: new Prisma.Decimal(data.priceFloor),
        below_floor_acknowledged: data.belowFloorAcknowledged,
        listed_price: new Prisma.Decimal(data.pricePerKg),
        listing_hash: data.listingHash,
        qr_code_data: data.qrCodeData,
        status: 'active',
      },
      include: { crop_types: true },
    });

    return mapPrismaToListing(created);
  }

  async findManyByFarmer(farmerId: string): Promise<Listing[]> {
    const list = await prisma.produce_listings.findMany({
      where: { farmer_id: farmerId },
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
