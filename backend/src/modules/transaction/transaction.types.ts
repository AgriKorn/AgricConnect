export type TransactionStatus = 'PAYMENT_HELD' | 'RELEASED' | 'CANCELLED';

export interface Transaction {
  id: string;
  listingId: string;
  buyerId: string;
  farmerId: string;
  farmerName: string | null;
  /** The buyer's display name — what a farmer sees on their sales list. */
  buyerName: string | null;
  /** Name/phone/id of the driver who accepted this delivery job — null until one has (or for self-collect orders, always). */
  driverName: string | null;
  driverPhone: string | null;
  driverId: string | null;
  cropType: string;
  amountGhs: number;
  status: TransactionStatus;
  hasOwnTransport: boolean;
  paymentReference: string;
  transferCode: string | null;
  createdAt: Date;
  updatedAt: Date;
}
