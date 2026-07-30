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
}
