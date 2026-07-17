import { z } from 'zod';

const numeric = () => z.coerce.number();

export const browseMarketplaceSchema = z.object({
  query: z.object({
    crop: z.string().optional(),
    region: z.string().optional(),
    minFreshness: numeric().min(0).max(100).optional(),
    maxFreshness: numeric().min(0).max(100).optional(),
    minQuantity: numeric().positive().optional(),
    sort: z.enum(['date', 'freshness', 'price']).default('date'),
    order: z.enum(['asc', 'desc']).default('desc'),
    page: numeric().int().positive().default(1),
    limit: numeric().int().positive().max(50).default(20),
  }),
});

export type BrowseMarketplaceQuery = z.infer<typeof browseMarketplaceSchema>['query'];

export const listingIdParamSchema = z.object({
  params: z.object({
    id: z.string({ required_error: 'Listing ID is required' }).uuid('Listing ID must be a valid UUID'),
  }),
});
