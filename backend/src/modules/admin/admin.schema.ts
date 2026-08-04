import { z } from 'zod';
import { emailSchema, phoneSchema } from '../auth/auth.schema';

export const userIdParamSchema = z.object({
  params: z.object({
    id: z.string({ required_error: 'User ID is required' }).uuid('User ID must be a valid UUID'),
  }),
});

export const createAdminSchema = z.object({
  body: z.object({
    name: z.string().trim().min(2, 'Name must be at least 2 characters'),
    email: emailSchema,
    phone: phoneSchema,
    password: z.string().min(8, 'Password must be at least 8 characters'),
  }),
});

export type CreateAdminInput = z.infer<typeof createAdminSchema>['body'];

export const manualAssignDriverSchema = z.object({
  body: z.object({
    transactionId: z.string({ required_error: 'transactionId is required' }).uuid('transactionId must be a valid UUID'),
    driverId: z.string({ required_error: 'driverId is required' }).uuid('driverId must be a valid UUID'),
  }),
});
