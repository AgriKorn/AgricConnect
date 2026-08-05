export type AuditEventType =
  | 'LISTING_CREATED'
  | 'LISTING_UPDATED'
  | 'PURCHASE_INITIATED'
  | 'PAYMENT_HELD'
  | 'DRIVER_DISPATCHED'
  | 'DRIVER_ACCEPTED'
  | 'DRIVER_MANUALLY_ASSIGNED'
  | 'DRIVER_DISPATCH_EXHAUSTED'
  | 'DRIVER_PICKED_UP'
  | 'DRIVER_MARKED_DELIVERED'
  | 'DELIVERY_CONFIRMED'
  | 'PAYMENT_RELEASED';

export interface AuditEntry {
  id: string;
  eventType: AuditEventType;
  entityId: string;
  data: Record<string, unknown>;
  userId: string;
  hash: string;
  previousHash: string;
  createdAt: Date;
}
