import { DashboardService } from './dashboard.service';
import { IUserRepository } from '../user/user.repository';
import { ITransactionRepository } from '../transaction/transaction.repository';
import { IListingRepository } from '../listing/listing.repository';
import { PricingService } from '../pricing/pricing.service';
import { Transaction } from '../transaction/transaction.types';
import { Listing } from '../listing/listing.types';
import { User } from '../user/user.types';
import { NotFoundError } from '../../utils/errors';

describe('DashboardService', () => {
  let dashboardService: DashboardService;
  let mockUsers: jest.Mocked<Pick<IUserRepository, 'findById'>>;
  let mockTransactions: jest.Mocked<Pick<ITransactionRepository, 'findManyForUser'>>;
  let mockListings: jest.Mocked<Pick<IListingRepository, 'findManyByFarmer'>>;
  let mockPricing: jest.Mocked<Pick<PricingService, 'getMarketTrend'>>;

  const farmerId = 'farmer-1';

  const makeFarmer = (overrides?: Partial<User>): User => ({
    id: farmerId,
    name: 'Test Farmer',
    phone: '+233500000000',
    email: 'farmer@test.com',
    passwordHash: 'hash',
    role: 'farmer',
    status: 'ACTIVE',
    otp: null,
    otpExpiry: null,
    refreshToken: null,
    profile: { farmRegion: 'Ashanti' },
    createdAt: new Date(),
    updatedAt: new Date(),
    ...overrides,
  });

  const makeTx = (overrides?: Partial<Transaction>): Transaction => ({
    id: 'tx-1',
    listingId: 'listing-1',
    buyerId: 'buyer-1',
    farmerId,
    farmerName: 'Test Farmer',
    buyerName: 'Test Buyer',
    driverName: null,
    driverPhone: null,
    driverId: null,
    cropType: 'tomato',
    amountGhs: 100,
    status: 'RELEASED',
    hasOwnTransport: false,
    paymentReference: 'ref',
    transferCode: null,
    createdAt: new Date(),
    updatedAt: new Date(),
    ...overrides,
  });

  const makeListing = (overrides?: Partial<Listing>): Listing => ({
    id: 'listing-1',
    farmerId,
    cropType: 'tomato',
    cropCategory: 'vegetables',
    quantityKg: 50,
    freshnessScore: 90,
    shelfLifeDays: 7,
    farmerLat: 0,
    farmerLong: 0,
    pricePerKg: 10,
    listingHash: 'hash',
    qrCodeData: '',
    status: 'ACTIVE',
    createdAt: new Date(),
    updatedAt: new Date(),
    ...overrides,
  });

  beforeEach(() => {
    mockUsers = { findById: jest.fn() };
    mockTransactions = { findManyForUser: jest.fn() };
    mockListings = { findManyByFarmer: jest.fn() };
    mockPricing = { getMarketTrend: jest.fn().mockResolvedValue({ trendPercent: null }) };

    dashboardService = new DashboardService(mockUsers, mockTransactions, mockListings, mockPricing);
  });

  it('throws NotFoundError when the farmer does not exist', async () => {
    mockUsers.findById.mockResolvedValue(null);
    mockTransactions.findManyForUser.mockResolvedValue([]);
    mockListings.findManyByFarmer.mockResolvedValue([]);

    await expect(dashboardService.getFarmerSummary(farmerId)).rejects.toThrow(NotFoundError);
  });

  it('sums released transactions into total earnings and counts held ones as active orders', async () => {
    mockUsers.findById.mockResolvedValue(makeFarmer());
    mockTransactions.findManyForUser.mockResolvedValue([
      makeTx({ id: 'tx-1', status: 'RELEASED', amountGhs: 100 }),
      makeTx({ id: 'tx-2', status: 'RELEASED', amountGhs: 50 }),
      makeTx({ id: 'tx-3', status: 'PAYMENT_HELD', amountGhs: 75 }),
      makeTx({ id: 'tx-4', status: 'CANCELLED', amountGhs: 999 }),
    ]);
    mockListings.findManyByFarmer.mockResolvedValue([]);

    const result = await dashboardService.getFarmerSummary(farmerId);

    expect(result.totalEarningsGhs).toBe(150);
    expect(result.salesCount).toBe(2);
    expect(result.activeOrders).toBe(1);
  });

  it('excludes transactions belonging to a different farmer (defensive against a leaked buyer-side row)', async () => {
    mockUsers.findById.mockResolvedValue(makeFarmer());
    mockTransactions.findManyForUser.mockResolvedValue([
      makeTx({ farmerId: 'someone-else', status: 'RELEASED', amountGhs: 500 }),
    ]);
    mockListings.findManyByFarmer.mockResolvedValue([]);

    const result = await dashboardService.getFarmerSummary(farmerId);

    expect(result.totalEarningsGhs).toBe(0);
    expect(result.salesCount).toBe(0);
  });

  it('only counts released transactions updated today toward todaysEarnings', async () => {
    mockUsers.findById.mockResolvedValue(makeFarmer());
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    mockTransactions.findManyForUser.mockResolvedValue([
      makeTx({ id: 'tx-today', status: 'RELEASED', amountGhs: 40, updatedAt: new Date() }),
      makeTx({ id: 'tx-yesterday', status: 'RELEASED', amountGhs: 60, updatedAt: yesterday }),
    ]);
    mockListings.findManyByFarmer.mockResolvedValue([]);

    const result = await dashboardService.getFarmerSummary(farmerId);

    expect(result.todaysEarningsGhs).toBe(40);
    expect(result.totalEarningsGhs).toBe(100);
  });

  it('ranks primary crops by listing count, most-listed first', async () => {
    mockUsers.findById.mockResolvedValue(makeFarmer());
    mockTransactions.findManyForUser.mockResolvedValue([]);
    mockListings.findManyByFarmer.mockResolvedValue([
      makeListing({ cropType: 'cassava' }),
      makeListing({ cropType: 'tomato' }),
      makeListing({ cropType: 'tomato' }),
      makeListing({ cropType: 'tomato' }),
      makeListing({ cropType: 'maize' }),
      makeListing({ cropType: 'maize' }),
    ]);

    const result = await dashboardService.getFarmerSummary(farmerId);

    expect(result.primaryCrops).toEqual(['Tomato', 'Maize', 'Cassava']);
  });

  it('uses the farmer real region for location and passes it to the market trend lookup', async () => {
    mockUsers.findById.mockResolvedValue(makeFarmer({ profile: { farmRegion: 'Volta' } }));
    mockTransactions.findManyForUser.mockResolvedValue([]);
    mockListings.findManyByFarmer.mockResolvedValue([makeListing({ cropType: 'yam' })]);

    const result = await dashboardService.getFarmerSummary(farmerId);

    expect(result.location).toBe('Volta');
    expect(mockPricing.getMarketTrend).toHaveBeenCalledWith(['yam'], 'Volta');
  });

  it('passes through a null market trend instead of fabricating a percentage', async () => {
    mockUsers.findById.mockResolvedValue(makeFarmer());
    mockTransactions.findManyForUser.mockResolvedValue([]);
    mockListings.findManyByFarmer.mockResolvedValue([]);
    mockPricing.getMarketTrend.mockResolvedValue({ trendPercent: null });

    const result = await dashboardService.getFarmerSummary(farmerId);

    expect(result.marketTrendPercent).toBeNull();
  });
});
