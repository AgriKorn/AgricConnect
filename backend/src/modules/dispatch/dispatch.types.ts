export type DriverJobStatus = 'PENDING' | 'ACCEPTED' | 'IN_TRANSIT' | 'DELIVERED' | 'DECLINED' | 'COMPLETED';

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
  /**
   * Data-URI QR image of the one-time delivery code, present only once
   * status is DELIVERED — the buyer scans this straight off the driver's
   * screen to confirm receipt and release escrow. Regenerated on read from
   * the stored code, not persisted as an image.
   */
  deliveryQrImage: string | null;
}
