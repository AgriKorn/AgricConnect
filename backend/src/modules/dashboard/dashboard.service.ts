import { NotFoundError } from '../../utils/errors';
import { IListingRepository } from '../listing/listing.repository';
import { listingRepository } from '../listing/listing.repository.prisma';
import { PricingService, pricingService } from '../pricing/pricing.service';
import { ITransactionRepository } from '../transaction/transaction.repository';
import { transactionRepository } from '../transaction/transaction.repository.prisma';
import { IUserRepository } from '../user/user.repository';
import { userRepository } from '../user/user.repository.prisma';
import { FarmerDashboardSummary } from './dashboard.types';

const titleCase = (s: string) => (s.length === 0 ? s : s.charAt(0).toUpperCase() + s.slice(1));

export class DashboardService {
  constructor(
    private readonly users: Pick<IUserRepository, 'findById'>,
    private readonly transactions: Pick<ITransactionRepository, 'findManyForUser'>,
    private readonly listings: Pick<IListingRepository, 'findManyByFarmer'>,
    private readonly pricing: Pick<PricingService, 'getMarketTrend'>,
  ) {}

  async getFarmerSummary(farmerId: string): Promise<FarmerDashboardSummary> {
    const [farmer, transactions, listings] = await Promise.all([
      this.users.findById(farmerId),
      this.transactions.findManyForUser(farmerId),
      this.listings.findManyByFarmer(farmerId),
    ]);
    if (!farmer) throw new NotFoundError('User not found');

    const released = transactions.filter((t) => t.status === 'RELEASED' && t.farmerId === farmerId);
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);

    const todaysEarningsGhs = released
      .filter((t) => t.updatedAt >= todayStart)
      .reduce((sum, t) => sum + t.amountGhs, 0);
    const totalEarningsGhs = released.reduce((sum, t) => sum + t.amountGhs, 0);
    const activeOrders = transactions.filter((t) => t.status === 'PAYMENT_HELD' && t.farmerId === farmerId).length;

    const cropCounts = new Map<string, number>();
    for (const listing of listings) {
      cropCounts.set(listing.cropType, (cropCounts.get(listing.cropType) ?? 0) + 1);
    }
    const primaryCrops = [...cropCounts.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, 3)
      .map(([crop]) => titleCase(crop));

    const region = farmer.profile.farmRegion || farmer.profile.operatingRegion || 'Greater Accra';
    const { trendPercent } = await this.pricing.getMarketTrend([...cropCounts.keys()], region);

    return {
      location: region,
      todaysEarningsGhs: Number(todaysEarningsGhs.toFixed(2)),
      totalEarningsGhs: Number(totalEarningsGhs.toFixed(2)),
      activeOrders,
      salesCount: released.length,
      primaryCrops,
      marketTrendPercent: trendPercent,
    };
  }
}

export const dashboardService = new DashboardService(userRepository, transactionRepository, listingRepository, pricingService);
