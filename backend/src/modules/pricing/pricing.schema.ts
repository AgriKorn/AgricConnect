import { z } from 'zod';

export const recommendPriceSchema = z.object({
  query: z.object({
    crop: z.string().min(1, 'Crop is required'),
    region: z.string().min(1, 'Region is required'),
    freshness: z.coerce.number().min(0, 'Freshness must be at least 0').max(100, 'Freshness cannot exceed 100'),
    shelfLifeDays: z.coerce.number().int().positive().optional(),
  }),
});

export type RecommendPriceQuery = z.infer<typeof recommendPriceSchema>['query'];
