import { NotFoundError } from '../../utils/errors';
import { IListingRepository, ListingFilters } from '../listing/listing.repository';
import { listingRepository } from '../listing/listing.repository.prisma';
import { IUserRepository } from '../user/user.repository';
import { userRepository } from '../user/user.repository.prisma';
import { BrowseMarketplaceQuery } from './marketplace.schema';

export class MarketplaceService {
  constructor(
    private readonly listings: IListingRepository,
    private readonly users: IUserRepository,
  ) {}

  async browse(query: BrowseMarketplaceQuery) {
    const filters: ListingFilters = {
      crop: query.crop,
      minFreshness: query.minFreshness,
      maxFreshness: query.maxFreshness,
      minQuantity: query.minQuantity,
      sort: query.sort,
      order: query.order,
      page: query.page,
      limit: query.limit,
    };

    if (query.region) {
      filters.farmerIds = await this.users.findFarmerIdsByRegion(query.region);
    }

    const { listings, total } = await this.listings.findActive(filters);
    const enriched = await Promise.all(listings.map((listing) => this.withFarmerRegion(listing)));

    return {
      listings: enriched,
      pagination: {
        page: query.page,
        limit: query.limit,
        total,
        totalPages: total === 0 ? 0 : Math.ceil(total / query.limit),
      },
    };
  }

  async getListingDetail(id: string) {
    const listing = await this.listings.findById(id);
    if (!listing || listing.status !== 'ACTIVE') throw new NotFoundError('Listing not found');
    return this.withFarmerRegion(listing);
  }

  private async withFarmerRegion<T extends { farmerId: string }>(listing: T) {
    const farmer = await this.users.findById(listing.farmerId);
    return { ...listing, farmerRegion: farmer?.profile.farmRegion ?? null };
  }
}

export const marketplaceService = new MarketplaceService(listingRepository, userRepository);
