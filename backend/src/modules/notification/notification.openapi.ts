import { z } from 'zod';
import { registry } from '../../docs/openapi.registry';

const NotificationSchema = z.object({
  id: z.string().uuid().openapi({ example: 'a1b2c3d4-e5f6-47a8-b9c0-d1e2f3a4b5c6' }),
  userId: z.string().uuid().openapi({ example: '84130725-3a7e-41dc-9621-57c54fa57ec4' }),
  type: z.string().openapi({ example: 'LISTING_PURCHASED' }),
  message: z.string().openapi({ example: 'Your listing for 200kg of tomato was purchased for GHS 3000.00.' }),
  isRead: z.boolean().openapi({ example: false }),
  createdAt: z.string().datetime().openapi({ example: '2026-07-22T22:31:00.000Z' }),
});

// GET /api/notifications
registry.registerPath({
  method: 'get',
  path: '/api/notifications',
  summary: 'Get Unread In-App Notifications for Logged-in User',
  tags: ['Notifications'],
  security: [{ bearerAuth: [] }],
  responses: {
    200: {
      description: 'Notifications retrieved',
      content: {
        'application/json': {
          schema: z.object({
            success: z.literal(true).openapi({ example: true }),
            data: z.array(NotificationSchema),
          }),
        },
      },
    },
    401: { description: 'Unauthorized (`INVALID_TOKEN`)' },
  },
});

// PATCH /api/notifications/:id/read
registry.registerPath({
  method: 'patch',
  path: '/api/notifications/{id}/read',
  summary: 'Mark Notification as Read',
  tags: ['Notifications'],
  security: [{ bearerAuth: [] }],
  request: {
    params: z.object({
      id: z.string().uuid().openapi({ example: 'a1b2c3d4-e5f6-47a8-b9c0-d1e2f3a4b5c6' }),
    }),
  },
  responses: {
    200: {
      description: 'Notification marked as read',
      content: {
        'application/json': {
          schema: z.object({
            success: z.literal(true).openapi({ example: true }),
            data: NotificationSchema,
          }),
        },
      },
    },
    404: { description: 'Notification not found (`NOT_FOUND`)' },
  },
});
