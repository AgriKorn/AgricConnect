import { FreshnessMonitorWorker } from './freshness-monitor.worker';
import { Listing } from '../modules/listing/listing.types';

describe('FreshnessMonitorWorker', () => {
  const day = (n: number) => new Date(2026, 0, 1 + n);

  const listing = (overrides?: Partial<Listing>): Listing => ({
    id: 'listing-1',
    farmerId: 'farmer-1',
    cropType: 'tomato',
    cropCategory: 'vegetables',
    quantityKg: 100,
    freshnessScore: 100,
    shelfLifeDays: 5, // 20 pts/day
    farmerLat: 5.6,
    farmerLong: -0.2,
    pricePerKg: 10,
    listingHash: 'h',
    qrCodeData: 'q',
    imageUrls: [],
    status: 'ACTIVE',
    createdAt: day(0),
    updatedAt: day(0),
    ...overrides,
  });

  let listings: { findAllActive: jest.Mock };
  let notifications: { existsForListingAndType: jest.Mock };
  let notifier: { sendNotification: jest.Mock };
  let worker: FreshnessMonitorWorker;

  beforeEach(() => {
    listings = { findAllActive: jest.fn() };
    notifications = { existsForListingAndType: jest.fn().mockResolvedValue(false) };
    notifier = { sendNotification: jest.fn().mockResolvedValue(undefined) };
    // threshold 40%, window 48h
    worker = new FreshnessMonitorWorker(40, 48, listings as any, notifications as any, notifier as any);
  });

  it('alerts the owning farmer when a listing is projected to cross the threshold within the window', async () => {
    // Day 2: at 60%, falls to 20% by day 4 — crosses 40% within 48h.
    listings.findAllActive.mockResolvedValue([listing()]);

    const count = await worker.sweep(day(2));

    expect(count).toBe(1);
    expect(notifier.sendNotification).toHaveBeenCalledWith(
      expect.objectContaining({ userId: 'farmer-1', type: 'FRESHNESS_WARNING', listingId: 'listing-1' }),
    );
    expect(notifier.sendNotification.mock.calls[0][0].message).toContain('40%');
  });

  it('does not alert while the crossing is still beyond the window', async () => {
    // Day 0: 48h out it is 60%, still above 40%.
    listings.findAllActive.mockResolvedValue([listing()]);

    const count = await worker.sweep(day(0));

    expect(count).toBe(0);
    expect(notifier.sendNotification).not.toHaveBeenCalled();
  });

  it('does not re-alert a listing that already has a freshness warning (dedup)', async () => {
    listings.findAllActive.mockResolvedValue([listing()]);
    notifications.existsForListingAndType.mockResolvedValue(true);

    const count = await worker.sweep(day(2));

    expect(count).toBe(0);
    expect(notifications.existsForListingAndType).toHaveBeenCalledWith('listing-1', 'FRESHNESS_WARNING');
    expect(notifier.sendNotification).not.toHaveBeenCalled();
  });

  it('checks dedup per listing and alerts only the ones that cross', async () => {
    listings.findAllActive.mockResolvedValue([
      listing({ id: 'crossing', farmerId: 'f-cross' }),
      listing({ id: 'safe', farmerId: 'f-safe', shelfLifeDays: 60 }), // decays far slower, nowhere near 40%
    ]);

    const count = await worker.sweep(day(2));

    expect(count).toBe(1);
    expect(notifier.sendNotification).toHaveBeenCalledTimes(1);
    expect(notifier.sendNotification.mock.calls[0][0].listingId).toBe('crossing');
  });

  it('returns zero and sends nothing when there are no active listings', async () => {
    listings.findAllActive.mockResolvedValue([]);

    expect(await worker.sweep(day(2))).toBe(0);
    expect(notifier.sendNotification).not.toHaveBeenCalled();
  });

  it('honours a custom threshold and window', async () => {
    // 100% over 10 days = 10 pts/day. At day 0, 48h out = 80%.
    listings.findAllActive.mockResolvedValue([listing({ shelfLifeDays: 10 })]);
    const strict = new FreshnessMonitorWorker(90, 48, listings as any, notifications as any, notifier as any);

    const count = await strict.sweep(day(0));

    expect(count).toBe(1); // 80% is below the 90% threshold within the window
  });
});
