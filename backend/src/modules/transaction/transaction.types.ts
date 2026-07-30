export type TransactionStatus = 'PAYMENT_HELD' | 'RELEASED' | 'CANCELLED';

export interface Transaction {
  id: string;
  listingId: string;
  buyerId: string;
  farmerId: string;
  farmerName: string | null;
  cropType: string;
  amountGhs: number;
  status: TransactionStatus;
  hasOwnTransport: boolean;
  paymentReference: string;
  transferCode: string | null;
  createdAt: Date;
  updatedAt: Date;
}
