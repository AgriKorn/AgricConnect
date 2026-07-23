import { z } from 'zod';
import { registry } from '../../docs/openapi.registry';

const AuditTrailEntrySchema = z.object({
  id: z.string().openapi({ example: '65' }),
  eventType: z.string().openapi({ example: 'PURCHASE_INITIATED' }),
  entityId: z.string().uuid().openapi({ example: 'b9ba9890-4633-4955-bb08-7de29c1bdb86' }),
  userId: z.string().openapi({ example: '72882852-6a7e-41dc-9621-57c54fa57ec4' }),
  data: z.record(z.unknown()).openapi({ example: { amountGhs: 3000, listingId: 'edcac427-a0e3-4738-b4c1-0e7d375d135a' } }),
  hash: z.string().openapi({ example: '0e85a2090c7efa72733b00ee35ebbba1aa7158e920991de9ccea67ddfa441e34' }),
  previousHash: z.string().openapi({ example: 'GENESIS' }),
  createdAt: z.string().datetime().openapi({ example: '2026-07-22T22:31:00.000Z' }),
});

// GET /api/admin/audit
registry.registerPath({
  method: 'get',
  path: '/api/admin/audit',
  summary: 'Search & Filter Tamper-Evident Cryptographic Audit Logs (Admin only)',
  tags: ['Admin & Audit System'],
  security: [{ bearerAuth: [] }],
  request: {
    query: z.object({
      eventType: z.string().optional().openapi({ example: 'PURCHASE_INITIATED' }),
      actorId: z.string().optional().openapi({ example: '72882852-6a7e-41dc-9621-57c54fa57ec4' }),
      startDate: z.string().optional().openapi({ example: '2026-07-01' }),
      endDate: z.string().optional().openapi({ example: '2026-07-31' }),
      page: z.string().optional().openapi({ example: '1' }),
      limit: z.string().optional().openapi({ example: '20' }),
    }),
  },
  responses: {
    200: {
      description: 'Audit logs retrieved',
      content: {
        'application/json': {
          schema: z.object({
            success: z.literal(true).openapi({ example: true }),
            data: z.object({
              entries: z.array(AuditTrailEntrySchema),
              pagination: z.object({
                page: z.number().openapi({ example: 1 }),
                limit: z.number().openapi({ example: 20 }),
                total: z.number().openapi({ example: 65 }),
                pages: z.number().openapi({ example: 4 }),
              }),
            }),
          }),
        },
      },
    },
    403: { description: 'Forbidden - Admin role required (`FORBIDDEN`)' },
  },
});
