import { z } from 'zod';

export const jobIdParamSchema = z.object({
  params: z.object({
    jobId: z.string({ required_error: 'Job ID is required' }).uuid('Job ID must be a valid UUID'),
  }),
});

export const getDriverJobsQuerySchema = z.object({
  query: z.object({
    status: z.enum(['PENDING', 'ACCEPTED', 'DECLINED', 'COMPLETED']).optional(),
  }),
});

export type GetDriverJobsQuery = z.infer<typeof getDriverJobsQuerySchema>['query'];
