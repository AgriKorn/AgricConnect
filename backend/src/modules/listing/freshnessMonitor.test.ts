import { projectedFreshnessAt, willDropBelowThresholdWithin, FreshnessSnapshot } from './freshnessMonitor';

describe('freshnessMonitor', () => {
  const day = (n: number) => new Date(2026, 0, 1 + n);

  describe('projectedFreshnessAt', () => {
    it('returns the recorded freshness at the moment of listing', () => {
      const snap: FreshnessSnapshot = { freshnessScore: 90, shelfLifeDays: 6, createdAt: day(0) };
      expect(projectedFreshnessAt(snap, day(0))).toBe(90);
    });

    it('decays linearly as days pass since listing', () => {
      // 100% over a 4-day shelf life loses 25 points/day.
      const snap: FreshnessSnapshot = { freshnessScore: 100, shelfLifeDays: 4, createdAt: day(0) };
      expect(projectedFreshnessAt(snap, day(1))).toBe(75);
      expect(projectedFreshnessAt(snap, day(2))).toBe(50);
    });

    it('never reports a future freshness for a timestamp before listing (clamps elapsed at 0)', () => {
      const snap: FreshnessSnapshot = { freshnessScore: 80, shelfLifeDays: 5, createdAt: day(3) };
      expect(projectedFreshnessAt(snap, day(0))).toBe(80);
    });
  });

  describe('willDropBelowThresholdWithin', () => {
    const threshold = 40;
    const window = 48; // hours

    it('fires when freshness is above the threshold now but below it within the window', () => {
      // 100% over 5 days = 20 pts/day. On day 2 it is at 60%; two days later (day 4) it is 20%.
      const snap: FreshnessSnapshot = { freshnessScore: 100, shelfLifeDays: 5, createdAt: day(0) };
      expect(willDropBelowThresholdWithin(snap, day(2), threshold, window)).toBe(true);
    });

    it('does not fire while the crossing is still more than the window away', () => {
      // On day 0 it is 100%; 48h later it is 60% — still above 40%.
      const snap: FreshnessSnapshot = { freshnessScore: 100, shelfLifeDays: 5, createdAt: day(0) };
      expect(willDropBelowThresholdWithin(snap, day(0), threshold, window)).toBe(false);
    });

    it('does not fire once freshness is already below the threshold (that alert has passed)', () => {
      // Day 4 of a 5-day life at 100% start = 20%, already under 40%.
      const snap: FreshnessSnapshot = { freshnessScore: 100, shelfLifeDays: 5, createdAt: day(0) };
      expect(willDropBelowThresholdWithin(snap, day(4), threshold, window)).toBe(false);
    });

    it('fires exactly at the boundary poll where the crossing enters the window', () => {
      // 100% over 10 days = 10 pts/day; threshold 40 is hit at day 6.
      // At day 4, freshness is 60% and in 48h (day 6) it is exactly 40% — not below.
      // At day 4 + a hair, the day-6+ projection dips under 40, so from just after day 4 it fires.
      const snap: FreshnessSnapshot = { freshnessScore: 100, shelfLifeDays: 10, createdAt: day(0) };
      expect(willDropBelowThresholdWithin(snap, day(4), threshold, window)).toBe(false); // 40 is not < 40
      const justAfterDay4 = new Date(day(4).getTime() + 60 * 60 * 1000); // +1h
      expect(willDropBelowThresholdWithin(snap, justAfterDay4, threshold, window)).toBe(true);
    });

    it('respects a custom threshold', () => {
      const snap: FreshnessSnapshot = { freshnessScore: 100, shelfLifeDays: 10, createdAt: day(0) };
      // At day 0, 48h out it is 80%. Below a 90% threshold, above a 70% one.
      expect(willDropBelowThresholdWithin(snap, day(0), 90, window)).toBe(true);
      expect(willDropBelowThresholdWithin(snap, day(0), 70, window)).toBe(false);
    });
  });
});
