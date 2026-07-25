import { z } from 'zod';
import { registry } from '../../docs/openapi.registry';

const DisputeSchema = z.object({
  id: z.string().uuid().openapi({ example: '0f48258f-434c-4133-8869-374c7d471a84' }),
  transactionId: z.string().uuid().openapi({ example: '0a41abac-f904-41d8-8a2c-30461261f887' }),
  raisedBy: z.string().uuid().openapi({ example: '72882852-6a7e-41dc-9621-57c54fa57ec4' }),
  reason: z.string().openapi({ example: 'Produce damaged in transit — 50kg spoiled' }),
  evidenceUrl: z.string().url().nullable().openapi({ example: 'https://storage.supabase.co/agriconnect/evidence_01.jpg' }),
  status: z.enum(['OPEN', 'RESOLVED']).openapi({ example: 'OPEN' }),
  resolution: z.string().nullable().openapi({ example: null }),
  createdAt: z.string().datetime().openapi({ example: '2026-07-22T22:33:00.000Z' }),
});

// POST /api/disputes
registry.registerPath({
  method: 'post',
  path: '/api/disputes',
  summary: 'Raise Financial Dispute on Escrow Order',
  tags: ['Disputes & Arbitration'],
  security: [{ bearerAuth: [] }],
  request: {
    body: {
      content: {
        'application/json': {
          schema: z.object({
            transactionId: z.string().uuid().openapi({ example: '0a41abac-f904-41d8-8a2c-30461261f887' }),
            reason: z.string().min(5).openapi({ example: 'Produce damaged in transit — 50kg spoiled' }),
            evidenceUrl: z.string().url().optional().openapi({ example: 'https://storage.supabase.co/agriconnect/evidence_01.jpg' }),
          }),
        },
      },
    },
  },
  responses: {
    201: {
      description: 'Dispute raised successfully',
      content: {
        'application/json': {
          schema: z.object({
            success: z.literal(true).openapi({ example: true }),
            data: DisputeSchema,
          }),
        },
      },
    },
    403: { description: 'User not party to order (`FORBIDDEN`)' },
    404: { description: 'Transaction not found (`NOT_FOUND`)' },
  },
});

// GET /api/disputes/:id
registry.registerPath({
  method: 'get',
  path: '/api/disputes/{id}',
  summary: 'Get Dispute Details by ID',
  tags: ['Disputes & Arbitration'],
  security: [{ bearerAuth: [] }],
  request: {
    params: z.object({
      id: z.string().uuid().openapi({ example: '0f48258f-434c-4133-8869-374c7d471a84' }),
    }),
  },
  responses: {
    200: {
      description: 'Dispute details retrieved',
      content: {
        'application/json': {
          schema: z.object({
            success: z.literal(true).openapi({ example: true }),
            data: DisputeSchema,
          }),
        },
      },
    },
    404: { description: 'Dispute not found (`NOT_FOUND`)' },
  },
});

// POST /api/disputes/:id/resolve (Admin only)
registry.registerPath({
  method: 'post',
  path: '/api/disputes/{id}/resolve',
  summary: 'Resolve Dispute & Execute Transactional Escrow Side-Effects (Admin only)',
  tags: ['Disputes & Arbitration'],
  security: [{ bearerAuth: [] }],
  request: {
    params: z.object({
      id: z.string().uuid().openapi({ example: '0f48258f-434c-4133-8869-374c7d471a84' }),
    }),
    body: {
      content: {
        'application/json': {
          schema: z.object({
            action: z.enum(['REFUND_BUYER', 'RELEASE_FARMER']).openapi({ example: 'REFUND_BUYER', description: 'REFUND_BUYER cancels order, refunds payment & re-activates listing. RELEASE_FARMER releases funds to farmer.' }),
            resolution: z.string().min(5).openapi({ example: 'Full refund granted due to damaged produce' }),
          }),
        },
      },
    },
  },
  responses: {
    200: {
      description: 'Dispute resolved & financial escrow side-effects executed',
      content: {
        'application/json': {
          schema: z.object({
            success: z.literal(true).openapi({ example: true }),
            data: DisputeSchema,
          }),
        },
      },
    },
    403: { description: 'Forbidden - Admin role required (`FORBIDDEN`)' },
    409: { description: 'Dispute already resolved (`DISPUTE_ALREADY_RESOLVED`)' },
  },
});
