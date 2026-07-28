import { projectFreshness } from './freshnessDecay';

describe('projectFreshness', () => {
  it('should return the starting freshness unchanged on day 0', () => {
    expect(projectFreshness(90, 0, 6)).toBe(90);
  });

  it('should decay linearly to zero across the shelf life', () => {
    // 100% freshness over a 4-day shelf life loses 25 points per day.
    expect(projectFreshness(100, 1, 4)).toBe(75);
    expect(projectFreshness(100, 2, 4)).toBe(50);
    expect(projectFreshness(100, 3, 4)).toBe(25);
    expect(projectFreshness(100, 4, 4)).toBe(0);
  });

  it('should scale the decay to the starting freshness, not to 100', () => {
    // Produce listed at 50% halves again by the midpoint of its shelf life.
    expect(projectFreshness(50, 3, 6)).toBe(25);
  });

  it('should clamp to 0 rather than going negative past the shelf life', () => {
    expect(projectFreshness(80, 10, 5)).toBe(0);
  });

  it('should return 0 for a non-positive shelf life instead of dividing by zero', () => {
    expect(projectFreshness(95, 1, 0)).toBe(0);
    expect(projectFreshness(95, 1, -3)).toBe(0);
  });

  it('should round to 2 decimal places', () => {
    // 85 * (1 - 1/3) = 56.6666… — must not leak float noise into pricing.
    expect(projectFreshness(85, 1, 3)).toBe(56.67);
  });

  it('should never produce a value above the starting freshness', () => {
    const start = 70;
    for (let day = 0; day <= 7; day++) {
      expect(projectFreshness(start, day, 7)).toBeLessThanOrEqual(start);
    }
  });

  it('should decrease monotonically as days elapse', () => {
    const series = Array.from({ length: 8 }, (_, day) => projectFreshness(100, day, 7));
    for (let i = 1; i < series.length; i++) {
      expect(series[i]).toBeLessThan(series[i - 1]);
    }
  });
});
