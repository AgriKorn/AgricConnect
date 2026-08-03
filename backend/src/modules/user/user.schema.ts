import { z } from 'zod';
import { normalizePhone } from '../auth/auth.schema';

export const updateProfileSchema = z.object({
  body: z.object({
    name: z.string().min(2).optional(),
    // Farmer
    farmRegion: z.string().optional(),
    gpsLatitude: z.number().min(-90).max(90).optional(),
    gpsLongitude: z.number().min(-180).max(180).optional(),
    // Farmer payout — Mobile Money details required before listings can be created
    momoNumber: z.preprocess(
      normalizePhone,
      z.string().trim().regex(/^\+233\d{9}$/, 'MoMo number must be a valid Ghana number (+233XXXXXXXXX)'),
    ).optional(),
    momoNetwork: z.enum(['MTN', 'VOD', 'ATL'], {
      errorMap: () => ({ message: "momoNetwork must be one of 'MTN', 'VOD', 'ATL'" }),
    }).optional(),
    // Buyer
    businessName: z.string().optional(),
    businessType: z.string().optional(),
    deliveryAddress: z.string().optional(),
    // Driver
    truckCapacity: z.number().positive('Truck capacity must be positive').optional(),
    operatingRegion: z.string().optional(),
    isAvailable: z.boolean().optional(),
    // Shared — set after a successful photo upload (see photoUploadUrlSchema)
    photoUrl: z.string().url().optional(),
    // Shared — full object sent on every toggle flip, not a partial patch
    notificationPreferences: z
      .object({
        orderStatusUpdates: z.boolean().optional(),
        priceAlerts: z.boolean().optional(),
        freshnessNotifications: z.boolean().optional(),
        marketingOffers: z.boolean().optional(),
      })
      .optional(),
  }),
});

export const photoUploadUrlSchema = z.object({
  body: z.object({
    fileName: z.string().min(1, 'fileName is required'),
    contentType: z.string().regex(/^image\//, 'contentType must be an image MIME type'),
  }),
});

export const registerDeviceTokenSchema = z.object({
  body: z.object({
    fcmToken: z.string({ required_error: 'fcmToken is required' }).min(1, 'fcmToken cannot be empty'),
    platform: z.enum(['android', 'ios', 'web']).optional(),
    deviceId: z.string().optional(),
  }),
});

export const removeDeviceTokenSchema = z.object({
  body: z.object({
    fcmToken: z.string({ required_error: 'fcmToken is required' }).min(1, 'fcmToken cannot be empty'),
  }),
});

export type UpdateProfileInput = z.infer<typeof updateProfileSchema>['body'];
export type RegisterDeviceTokenInput = z.infer<typeof registerDeviceTokenSchema>['body'];
export type RemoveDeviceTokenInput = z.infer<typeof removeDeviceTokenSchema>['body'];
