import { z } from 'zod';

export const userIdParamSchema = z.object({
  params: z.object({
    id: z.string({ required_error: 'User ID is required' }).uuid('User ID must be a valid UUID'),
  }),
});
