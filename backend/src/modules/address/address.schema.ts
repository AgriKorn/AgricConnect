import { z } from 'zod';

export const createAddressSchema = z.object({
  body: z.object({
    label: z.string().trim().min(1, 'Label is required').max(50),
    addressLine: z.string().trim().min(1, 'Address is required').max(255),
    region: z.string().trim().max(100).optional(),
    isDefault: z.boolean().optional(),
  }),
});

export const updateAddressSchema = z.object({
  body: z.object({
    label: z.string().trim().min(1).max(50).optional(),
    addressLine: z.string().trim().min(1).max(255).optional(),
    region: z.string().trim().max(100).optional(),
    isDefault: z.boolean().optional(),
  }),
});

export type CreateAddressInput = z.infer<typeof createAddressSchema>['body'];
export type UpdateAddressInput = z.infer<typeof updateAddressSchema>['body'];
