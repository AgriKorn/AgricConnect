export type DriverJobStatus = 'PENDING' | 'ACCEPTED' | 'DECLINED' | 'COMPLETED';

export interface DriverJob {
  id: string;
  transactionId: string;
  listingId: string;
  driverId: string;
  cropType: string;
  quantityKg: number;
  amountGhs: number;
  status: DriverJobStatus;
  createdAt: Date;
  updatedAt: Date;
  /** Pickup contact — the farmer who listed the produce. */
  farmerName: string | null;
  farmerPhone: string | null;
  pickupRegion: string | null;
  /** Dropoff contact — the buyer who purchased it. */
  buyerName: string | null;
  buyerPhone: string | null;
  dropoffRegion: string | null;
}
