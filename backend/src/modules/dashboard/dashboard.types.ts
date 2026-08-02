export interface FarmerDashboardSummary {
  location: string;
  todaysEarningsGhs: number;
  totalEarningsGhs: number;
  activeOrders: number;
  salesCount: number;
  primaryCrops: string[];
  /** null when there isn't enough MOFA price history yet to compute a real trend. */
  marketTrendPercent: number | null;
}
