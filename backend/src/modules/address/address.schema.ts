import { z } from 'zod';

export const createAddressSchema = z.object({
  body: z.object({
    label: z.string().trim().min(1, 'Label is required').max(50),
    addressLine: z.string().trim().min(1, 'Address is required').max(255),
    region: z.string().trim().max(100).optional(),
    isDefault: z.boolean().optional(),
  }),
});

/**
 * `delivery_addresses.id` is a Postgres `uuid` column, so a non-UUID :id
 * reached Prisma and surfaced the driver's cast error as a raw 500 instead of
 * a 404 — `DELETE /api/users/addresses/foo` was enough. Same idiom as
 * transaction.schema.ts / marketplace.schema.ts.
 */
export const addressIdParamSchema = z.object({
  params: z.object({
    id: z.string({ required_error: 'Address ID is required' }).uuid('Address ID must be a valid UUID'),
  }),
});

export const updateAddressSchema = z.object({
  params: z.object({
    id: z.string({ required_error: 'Address ID is required' }).uuid('Address ID must be a valid UUID'),
  }),
  body: z.object({
    label: z.string().trim().min(1).max(50).optional(),
    addressLine: z.string().trim().min(1).max(255).optional(),
    region: z.string().trim().max(100).optional(),
    isDefault: z.boolean().optional(),
  }),
});

export type CreateAddressInput = z.infer<typeof createAddressSchema>['body'];
export type UpdateAddressInput = z.infer<typeof updateAddressSchema>['body'];
