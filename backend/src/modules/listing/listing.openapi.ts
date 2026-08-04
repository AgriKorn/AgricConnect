import { z } from 'zod';
import { registry } from '../../docs/openapi.registry';

const ListingSchema = z.object({
  id: z.string().uuid().openapi({ example: 'edcac427-a0e3-4738-b4c1-0e7d375d135a' }),
  farmerId: z.string().uuid().openapi({ example: '84130725-3a7e-41dc-9621-57c54fa57ec4' }),
  cropType: z.string().openapi({ example: 'tomato' }),
  quantityKg: z.number().openapi({ example: 200 }),
  freshnessScore: z.number().openapi({ example: 9.5 }),
  shelfLifeDays: z.number().openapi({ example: 7 }),
  farmerLat: z.number().openapi({ example: 5.6037 }),
  farmerLong: z.number().openapi({ example: -0.1870 }),
  region: z.string().openapi({ example: 'Ashanti', description: "Farmer's registered region at listing time — drives the MOFA price lookup" }),
  pricePerKg: z.number().openapi({ example: 15.00 }),
  mofaReferencePrice: z.number().openapi({ example: 10.0, description: 'MOFA reference price (GHS/kg) pricePerKg was checked against' }),
  priceCeiling: z.number().openapi({ example: 8.5, description: 'pricePerKg above this is rejected at creation time' }),
  priceFloor: z.number().openapi({ example: 6.0, description: 'pricePerKg below this is allowed but sets belowFloorAcknowledged' }),
  belowFloorAcknowledged: z.boolean().openapi({ example: false }),
  listingHash: z.string().openapi({ example: 'a2de10e46d04737a4bf17b6343bbe1190248bde34cb9b1a35604402fc3414920' }),
  qrCodeData: z.string().openapi({ example: 'a2de10e46d04737a4bf17b6343bbe1190248bde34cb9b1a35604402fc3414920' }),
  status: z.enum(['ACTIVE', 'SOLD', 'INACTIVE']).openapi({ example: 'ACTIVE' }),
  createdAt: z.string().datetime().openapi({ example: '2026-07-22T22:30:00.000Z' }),
});

// POST /api/listings
registry.registerPath({
  method: 'post',
  path: '/api/listings',
  summary: 'Create Produce Listing (Farmer only)',
  tags: ['Listings'],
  security: [{ bearerAuth: [] }],
  request: {
    body: {
      content: {
        'application/json': {
          schema: z.object({
            cropType: z.string().openapi({ example: 'tomato', description: 'Case-insensitive crop name (tomato, maize, cassava, plantain, yam, onion, pepper)' }),
            quantityKg: z.number().positive().openapi({ example: 200 }),
            freshnessScore: z.number().min(0).max(10).openapi({ example: 9.5 }),
            shelfLifeDays: z.number().int().positive().openapi({ example: 7 }),
            farmerLat: z.number().openapi({ example: 5.6037 }),
            farmerLong: z.number().openapi({ example: -0.1870 }),
            pricePerKg: z.number().positive().openapi({ example: 15.00 }),
            listingHash: z.string().openapi({ example: 'a2de10e46d04737a4bf17b6343bbe1190248bde34cb9b1a35604402fc3414920' }),
            qrCodeData: z.string().openapi({ example: 'a2de10e46d04737a4bf17b6343bbe1190248bde34cb9b1a35604402fc3414920' }),
          }),
        },
      },
    },
  },
  responses: {
    201: {
      description: 'Listing created successfully',
      content: {
        'application/json': {
          schema: z.object({
            success: z.literal(true).openapi({ example: true }),
            data: ListingSchema,
          }),
        },
      },
    },
    400: { description: 'Unknown crop type (`UNKNOWN_CROP_TYPE`)' },
    401: { description: 'Unauthorized (`INVALID_TOKEN`)' },
    403: { description: 'Forbidden - Farmer role required (`FORBIDDEN`)' },
  },
});

// GET /api/listings
registry.registerPath({
  method: 'get',
  path: '/api/listings',
  summary: 'Browse Active Produce Listings (Public or Filtered)',
  tags: ['Listings'],
  request: {
    query: z.object({
      crop: z.string().optional().openapi({ example: 'tomato' }),
      minFreshness: z.string().optional().openapi({ example: '8.0' }),
      minQuantity: z.string().optional().openapi({ example: '100' }),
      sort: z.enum(['created_at', 'freshness', 'price']).optional().openapi({ example: 'freshness' }),
      order: z.enum(['asc', 'desc']).optional().openapi({ example: 'desc' }),
      page: z.string().optional().openapi({ example: '1' }),
      limit: z.string().optional().openapi({ example: '20' }),
    }),
  },
  responses: {
    200: {
      description: 'Listings retrieved successfully',
      content: {
        'application/json': {
          schema: z.object({
            success: z.literal(true).openapi({ example: true }),
            data: z.object({
              listings: z.array(ListingSchema),
              pagination: z.object({
                page: z.number().openapi({ example: 1 }),
                limit: z.number().openapi({ example: 20 }),
                total: z.number().openapi({ example: 42 }),
                pages: z.number().openapi({ example: 3 }),
              }),
            }),
          }),
        },
      },
    },
  },
});

// GET /api/listings/:id
registry.registerPath({
  method: 'get',
  path: '/api/listings/{id}',
  summary: 'Get Produce Listing by ID',
  tags: ['Listings'],
  request: {
    params: z.object({
      id: z.string().uuid().openapi({ example: 'edcac427-a0e3-4738-b4c1-0e7d375d135a' }),
    }),
  },
  responses: {
    200: {
      description: 'Listing found',
      content: {
        'application/json': {
          schema: z.object({
            success: z.literal(true).openapi({ example: true }),
            data: ListingSchema,
          }),
        },
      },
    },
    404: { description: 'Listing not found (`NOT_FOUND`)' },
  },
});

// PATCH /api/listings/:id
registry.registerPath({
  method: 'patch',
  path: '/api/listings/{id}',
  summary: 'Update Produce Listing Price or Quantity (Farmer owner only)',
  tags: ['Listings'],
  security: [{ bearerAuth: [] }],
  request: {
    params: z.object({
      id: z.string().uuid().openapi({ example: 'edcac427-a0e3-4738-b4c1-0e7d375d135a' }),
    }),
    body: {
      content: {
        'application/json': {
          schema: z.object({
            pricePerKg: z.number().positive().optional().openapi({ example: 14.50 }),
            quantityKg: z.number().positive().optional().openapi({ example: 150 }),
          }),
        },
      },
    },
  },
  responses: {
    200: {
      description: 'Listing updated successfully',
      content: {
        'application/json': {
          schema: z.object({
            success: z.literal(true).openapi({ example: true }),
            data: ListingSchema,
          }),
        },
      },
    },
    403: { description: 'Forbidden - Not listing owner (`FORBIDDEN`)' },
    404: { description: 'Listing not found (`NOT_FOUND`)' },
  },
});

// DELETE /api/listings/:id
registry.registerPath({
  method: 'delete',
  path: '/api/listings/{id}',
  summary: 'Soft-delete Produce Listing (Farmer owner only)',
  tags: ['Listings'],
  security: [{ bearerAuth: [] }],
  request: {
    params: z.object({
      id: z.string().uuid().openapi({ example: 'edcac427-a0e3-4738-b4c1-0e7d375d135a' }),
    }),
  },
  responses: {
    200: {
      description: 'Listing cancelled successfully',
      content: {
        'application/json': {
          schema: z.object({
            success: z.literal(true).openapi({ example: true }),
            data: ListingSchema,
          }),
        },
      },
    },
  },
});
