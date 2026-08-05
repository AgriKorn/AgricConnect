import { z } from 'zod';

export const purchaseSchema = z.object({
  body: z.object({
    listingId: z.string({ required_error: 'Listing ID is required' }).uuid('Listing ID must be a valid UUID'),
    hasOwnTransport: z.boolean({ required_error: 'hasOwnTransport is required' }),
  }),
});

export const transactionIdParamSchema = z.object({
  params: z.object({
    id: z.string({ required_error: 'Transaction ID is required' }).uuid('Transaction ID must be a valid UUID'),
  }),
});

export const confirmDeliverySchema = z.object({
  body: z.object({
    code: z.string({ required_error: 'code is required' }).min(1, 'code cannot be empty'),
  }),
});

export type PurchaseInput = z.infer<typeof purchaseSchema>['body'];
export type ConfirmDeliveryInput = z.infer<typeof confirmDeliverySchema>['body'];
