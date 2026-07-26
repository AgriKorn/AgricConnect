/**
 * Projects freshness decay over time. No product spec defines the actual
 * decay curve — it's an open question flagged since the original analysis
 * ("linear? exponential? per-crop?"). This assumes linear decay to 0 at the
 * end of shelf life, the simplest model and the easiest to swap for a real
 * one later — every caller goes through this one function.
 */
export const projectFreshness = (currentFreshness: number, daysElapsed: number, shelfLifeDays: number): number => {
  if (shelfLifeDays <= 0) return 0;
  const decayed = currentFreshness * (1 - daysElapsed / shelfLifeDays);
  return Math.max(0, Math.round(decayed * 100) / 100);
};
