export type DisputeType = 'WRONG_PRODUCE' | 'NON_DELIVERY' | 'PAYMENT_ISSUE' | 'OTHER';
export type DisputeStatus = 'OPEN' | 'RESOLVED';

export interface Dispute {
  id: string;
  transactionId: string;
  raisedBy: string;
  type: DisputeType;
  description: string;
  status: DisputeStatus;
  resolution: string | null;
  createdAt: Date;
  updatedAt: Date;
}
