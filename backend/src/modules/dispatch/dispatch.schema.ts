import { z } from 'zod';

export const jobIdParamSchema = z.object({
  params: z.object({
    jobId: z.string({ required_error: 'Job ID is required' }).uuid('Job ID must be a valid UUID'),
  }),
});
