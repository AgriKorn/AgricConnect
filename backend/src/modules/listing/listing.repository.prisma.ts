import { prisma } from '../../config/db';
import { BadRequestError } from '../../utils/errors';
import { CreateListingRecord, IListingRepository, ListingFilters, UpdateListingRecord } from './listing.repository';
import { Listing } from './listing.types';
import { listing_status, Prisma } from '../../generated/prisma/client';

const mapPrismaToListing = (p: any): Listing => ({
  id: p.id,
  farmerId: p.farmer_id,
  cropType: p.crop_types?.name || 'unknown',
  quantityKg: Number(p.quantity_kg),
  freshnessScore: Number(p.freshness_score),
  shelfLifeDays: p.estimated_viable_days,
  farmerLat: Number(p.gps_lat),
  farmerLong: Number(p.gps_lng),
  pricePerKg: Number(p.listed_price),
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
        region: 'Greater Accra',
        gps_lat: new Prisma.Decimal(data.farmerLat),
        gps_lng: new Prisma.Decimal(data.farmerLong),
        freshness_score: new Prisma.Decimal(data.freshnessScore),
        estimated_viable_days: data.shelfLifeDays,
        mofa_reference_price: new Prisma.Decimal(data.pricePerKg),
        price_ceiling: new Prisma.Decimal(data.pricePerKg * 1.2),
        price_floor: new Prisma.Decimal(data.pricePerKg * 0.8),
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
    if (filters.minFreshness !== undefined) {
      where.freshness_score = { gte: filters.minFreshness };
    }
    if (filters.minQuantity !== undefined) {
      where.quantity_kg = { gte: filters.minQuantity };
    }
    if (filters.farmerIds && filters.farmerIds.length > 0) {
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
