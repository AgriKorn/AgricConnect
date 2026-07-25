import { z } from 'zod';
import { registry } from '../../docs/openapi.registry';

const DriverJobSchema = z.object({
  id: z.string().uuid().openapi({ example: 'efabba71-4916-4f64-af13-7de416504c99' }),
  transactionId: z.string().uuid().openapi({ example: 'b9ba9890-4633-4955-bb08-7de29c1bdb86' }),
  listingId: z.string().uuid().openapi({ example: 'edcac427-a0e3-4738-b4c1-0e7d375d135a' }),
  driverId: z.string().uuid().openapi({ example: '36d92bc0-8c62-4634-a192-a14250856e9c' }),
  cropType: z.string().openapi({ example: 'tomato' }),
  quantityKg: z.number().openapi({ example: 200 }),
  status: z.enum(['PENDING', 'ACCEPTED', 'DECLINED', 'COMPLETED']).openapi({ example: 'PENDING' }),
  assignedAt: z.string().datetime().openapi({ example: '2026-07-22T22:31:05.000Z' }),
});

// GET /api/dispatch/pending
registry.registerPath({
  method: 'get',
  path: '/api/dispatch/pending',
  summary: 'Get Pending Delivery Jobs Offered to Logged-in Driver',
  tags: ['Driver Dispatch & Logistics'],
  security: [{ bearerAuth: [] }],
  responses: {
    200: {
      description: 'Pending jobs retrieved',
      content: {
        'application/json': {
          schema: z.object({
            success: z.literal(true).openapi({ example: true }),
            data: z.array(DriverJobSchema),
          }),
        },
      },
    },
    403: { description: 'Forbidden - Driver role required (`FORBIDDEN`)' },
  },
});

// POST /api/dispatch/:id/accept
registry.registerPath({
  method: 'post',
  path: '/api/dispatch/{id}/accept',
  summary: 'Accept Delivery Job Offer (Driver only)',
  tags: ['Driver Dispatch & Logistics'],
  security: [{ bearerAuth: [] }],
  request: {
    params: z.object({
      id: z.string().uuid().openapi({ example: 'efabba71-4916-4f64-af13-7de416504c99' }),
    }),
  },
  responses: {
    200: {
      description: 'Job offer accepted',
      content: {
        'application/json': {
          schema: z.object({
            success: z.literal(true).openapi({ example: true }),
            data: DriverJobSchema,
          }),
        },
      },
    },
    403: { description: 'Job not offered to this driver (`FORBIDDEN`)' },
    409: { description: 'Job already accepted or completed (`JOB_ALREADY_ACCEPTED`)' },
  },
});

// POST /api/dispatch/:id/decline
registry.registerPath({
  method: 'post',
  path: '/api/dispatch/{id}/decline',
  summary: 'Decline Job Offer & Trigger Auto-Reassignment',
  tags: ['Driver Dispatch & Logistics'],
  security: [{ bearerAuth: [] }],
  request: {
    params: z.object({
      id: z.string().uuid().openapi({ example: 'efabba71-4916-4f64-af13-7de416504c99' }),
    }),
  },
  responses: {
    200: {
      description: 'Job declined and reassigned to next candidate driver (or manual dispatch alert triggered)',
      content: {
        'application/json': {
          schema: z.object({
            success: z.literal(true).openapi({ example: true }),
            data: z.object({
              declinedJob: DriverJobSchema,
              newDispatch: DriverJobSchema.nullable(),
              manualDispatchAlert: z.boolean().openapi({ example: false }),
            }),
          }),
        },
      },
    },
    403: { description: 'Job not offered to this driver (`FORBIDDEN`)' },
  },
});
