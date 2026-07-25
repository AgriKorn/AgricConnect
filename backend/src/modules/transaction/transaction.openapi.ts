import { z } from 'zod';
import { registry } from '../../docs/openapi.registry';

const TransactionSchema = z.object({
  id: z.string().uuid().openapi({ example: 'b9ba9890-4633-4955-bb08-7de29c1bdb86' }),
  listingId: z.string().uuid().openapi({ example: 'edcac427-a0e3-4738-b4c1-0e7d375d135a' }),
  buyerId: z.string().uuid().openapi({ example: '72882852-6a7e-41dc-9621-57c54fa57ec4' }),
  farmerId: z.string().uuid().openapi({ example: '84130725-3a7e-41dc-9621-57c54fa57ec4' }),
  amountGhs: z.number().openapi({ example: 3000.00 }),
  status: z.enum(['PAYMENT_HELD', 'RELEASED', 'CANCELLED', 'DISPUTED']).openapi({ example: 'PAYMENT_HELD' }),
  hasOwnTransport: z.boolean().openapi({ example: false }),
  paymentReference: z.string().openapi({ example: 'stub_80d7c72a-8635-45a6-9488-6afe9187b94f' }),
  createdAt: z.string().datetime().openapi({ example: '2026-07-22T22:31:00.000Z' }),
});

const DispatchJobSchema = z.object({
  id: z.string().uuid().openapi({ example: 'efabba71-4916-4f64-af13-7de416504c99' }),
  transactionId: z.string().uuid().openapi({ example: 'b9ba9890-4633-4955-bb08-7de29c1bdb86' }),
  driverId: z.string().uuid().openapi({ example: '36d92bc0-8c62-4634-a192-a14250856e9c' }),
  status: z.enum(['PENDING', 'ACCEPTED', 'DECLINED', 'COMPLETED']).openapi({ example: 'ACCEPTED' }),
  assignedAt: z.string().datetime().openapi({ example: '2026-07-22T22:31:05.000Z' }),
});

// POST /api/transactions/purchase
registry.registerPath({
  method: 'post',
  path: '/api/transactions/purchase',
  summary: 'Purchase Produce & Hold Funds in Escrow (Buyer only)',
  tags: ['Transactions & Escrow'],
  security: [{ bearerAuth: [] }],
  request: {
    body: {
      content: {
        'application/json': {
          schema: z.object({
            listingId: z.string().uuid().openapi({ example: 'edcac427-a0e3-4738-b4c1-0e7d375d135a' }),
            hasOwnTransport: z.boolean().optional().default(false).openapi({ example: false, description: 'Set true if buyer collects produce, false if driver dispatch required' }),
          }),
        },
      },
    },
  },
  responses: {
    201: {
      description: 'Purchase completed and escrow held',
      content: {
        'application/json': {
          schema: z.object({
            success: z.literal(true).openapi({ example: true }),
            data: z.object({
              transaction: TransactionSchema,
              dispatch: DispatchJobSchema.nullable(),
            }),
          }),
        },
      },
    },
    400: { description: 'Duplicate purchase attempt within 60s TTL (`DUPLICATE_PURCHASE_ATTEMPT`)' },
    409: { description: 'Listing already sold (`LISTING_ALREADY_SOLD`)' },
    404: { description: 'Listing not found (`NOT_FOUND`)' },
  },
});

// GET /api/transactions/:id
registry.registerPath({
  method: 'get',
  path: '/api/transactions/{id}',
  summary: 'Get Escrow Order & Transaction Details',
  tags: ['Transactions & Escrow'],
  security: [{ bearerAuth: [] }],
  request: {
    params: z.object({
      id: z.string().uuid().openapi({ example: 'b9ba9890-4633-4955-bb08-7de29c1bdb86' }),
    }),
  },
  responses: {
    200: {
      description: 'Transaction details retrieved',
      content: {
        'application/json': {
          schema: z.object({
            success: z.literal(true).openapi({ example: true }),
            data: TransactionSchema,
          }),
        },
      },
    },
    403: { description: 'Forbidden - User not party to order (`FORBIDDEN`)' },
    404: { description: 'Transaction not found (`NOT_FOUND`)' },
  },
});

// POST /api/transactions/:id/confirm-delivery
registry.registerPath({
  method: 'post',
  path: '/api/transactions/{id}/confirm-delivery',
  summary: 'Confirm Delivery via QR Hash & Release Escrow Funds (Buyer or Driver)',
  tags: ['Transactions & Escrow'],
  security: [{ bearerAuth: [] }],
  request: {
    params: z.object({
      id: z.string().uuid().openapi({ example: 'b9ba9890-4633-4955-bb08-7de29c1bdb86' }),
    }),
    body: {
      content: {
        'application/json': {
          schema: z.object({
            qrHash: z.string().openapi({ example: 'a2de10e46d04737a4bf17b6343bbe1190248bde34cb9b1a35604402fc3414920', description: 'Scanned QR code listing hash' }),
          }),
        },
      },
    },
  },
  responses: {
    200: {
      description: 'Delivery confirmed & escrow funds released to farmer',
      content: {
        'application/json': {
          schema: z.object({
            success: z.literal(true).openapi({ example: true }),
            data: TransactionSchema,
          }),
        },
      },
    },
    400: { description: 'QR hash mismatch (`BAD_REQUEST`)' },
    409: { description: 'Transaction not in PAYMENT_HELD status (`CONFLICT`)' },
  },
});
