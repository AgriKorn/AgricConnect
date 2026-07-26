import { z } from 'zod';
import { registry } from '../../docs/openapi.registry';

const MofaPriceReferenceSchema = z.object({
  cropType: z.string().openapi({ example: 'tomato' }),
  region: z.string().openapi({ example: 'Greater Accra' }),
  referencePricePerKg: z.number().openapi({ example: 15.00 }),
  priceCeilingPerKg: z.number().openapi({ example: 18.00 }),
  priceFloorPerKg: z.number().openapi({ example: 12.00 }),
  updatedAt: z.string().datetime().openapi({ example: '2026-07-22T00:00:00.000Z' }),
});

// GET /api/mofa/reference
registry.registerPath({
  method: 'get',
  path: '/api/mofa/reference',
  summary: 'Get MOFA Reference Prices & Guardrail Ceilings/Floors',
  tags: ['MOFA Price Reference'],
  request: {
    query: z.object({
      crop: z.string().optional().openapi({ example: 'tomato' }),
      region: z.string().optional().openapi({ example: 'Greater Accra' }),
    }),
  },
  responses: {
    200: {
      description: 'MOFA reference price retrieved',
      content: {
        'application/json': {
          schema: z.object({
            success: z.literal(true).openapi({ example: true }),
            data: z.array(MofaPriceReferenceSchema),
          }),
        },
      },
    },
  },
});
