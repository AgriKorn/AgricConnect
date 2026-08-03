import { z } from 'zod';

export const createDisputeSchema = z.object({
  body: z.object({
    transactionId: z.string({ required_error: 'Transaction ID is required' }).uuid('Transaction ID must be a valid UUID'),
    type: z.enum(['WRONG_PRODUCE', 'NON_DELIVERY', 'PAYMENT_ISSUE', 'OTHER']),
    description: z.string().min(10, 'Description must be at least 10 characters'),
  }),
});

export const disputeIdParamSchema = z.object({
  params: z.object({
    id: z.string({ required_error: 'Dispute ID is required' }).uuid('Dispute ID must be a valid UUID'),
  }),
});

export const resolveDisputeSchema = z.object({
  body: z.object({
    resolution: z.string().min(5, 'Resolution must be at least 5 characters'),
    action: z.enum(['REFUND_BUYER', 'RELEASE_FARMER']).optional(),
  }),
});
