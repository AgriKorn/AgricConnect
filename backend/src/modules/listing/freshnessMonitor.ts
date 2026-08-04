import { projectFreshness } from '../pricing/freshnessDecay';

/**
 * Freshness-threshold monitoring (SRS 3.1, "System Notification"):
 * "The system shall notify farmers when the freshness score is projected to
 *  fall below a predefined threshold within 48 hours."
 *
 * A listing records its freshness at the moment it was created. Real freshness
 * decays from there, so the projection has to account for the time already
 * elapsed since listing — not just the recorded score. All of that goes through
 * the single, tested `projectFreshness` curve so the marketplace and this alert
 * never disagree about how a crop ages.
 */

export interface FreshnessSnapshot {
  /** Freshness percentage recorded when the listing was created. */
  freshnessScore: number;
  /** Total shelf life in days from listing to zero freshness. */
  shelfLifeDays: number;
  /** When the listing was created — the origin for the decay clock. */
  createdAt: Date;
}

const MS_PER_DAY = 1000 * 60 * 60 * 24;

/** Projected freshness of a listing at a given instant, accounting for elapsed decay. */
export const projectedFreshnessAt = (snapshot: FreshnessSnapshot, at: Date): number => {
  const daysElapsed = Math.max(0, (at.getTime() - snapshot.createdAt.getTime()) / MS_PER_DAY);
  return projectFreshness(snapshot.freshnessScore, daysElapsed, snapshot.shelfLifeDays);
};

/**
 * True when a listing is at or above `threshold` now but is projected to fall
 * below it within `withinHours`. This is the edge the SRS asks about: the alert
 * fires as the crossing approaches, not for produce already past it (that alert
 * would have fired on an earlier poll) — which also keeps a listing from
 * re-alerting on every subsequent poll once it is below the line.
 */
export const willDropBelowThresholdWithin = (
  snapshot: FreshnessSnapshot,
  now: Date,
  threshold: number,
  withinHours: number,
): boolean => {
  const freshnessNow = projectedFreshnessAt(snapshot, now);
  if (freshnessNow < threshold) return false;

  const future = new Date(now.getTime() + withinHours * 60 * 60 * 1000);
  return projectedFreshnessAt(snapshot, future) < threshold;
};
