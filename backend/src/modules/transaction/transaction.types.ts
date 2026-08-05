// Mirrors orders.order_status (minus pending_payment, which purchase()
// never leaves an order sitting in) so the app can show the buyer/driver
// where an order actually is instead of collapsing everything pre-release
// into one generic "in progress" state.
export type TransactionStatus =
  | 'AWAITING_DRIVER'
  | 'DRIVER_ASSIGNED'
  | 'IN_TRANSIT'
  | 'DELIVERED_PENDING_CONFIRMATION'
  | 'RELEASED'
  | 'DISPUTED'
  | 'CANCELLED';

/** Pre-release: escrow is still held and the order hasn't been cancelled or disputed. */
export const isActiveStatus = (status: TransactionStatus): boolean =>
  status !== 'RELEASED' && status !== 'CANCELLED' && status !== 'DISPUTED';

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
