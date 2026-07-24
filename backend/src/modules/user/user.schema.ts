import { z } from 'zod';

export const updateProfileSchema = z.object({
  body: z.object({
    name: z.string().min(2).optional(),
    // Farmer
    farmRegion: z.string().optional(),
    gpsLatitude: z.number().min(-90).max(90).optional(),
    gpsLongitude: z.number().min(-180).max(180).optional(),
    // Buyer
    businessName: z.string().optional(),
    deliveryAddress: z.string().optional(),
    // Driver
    truckCapacity: z.number().positive('Truck capacity must be positive').optional(),
    operatingRegion: z.string().optional(),
    isAvailable: z.boolean().optional(),
  }),
});

export const registerDeviceTokenSchema = z.object({
  body: z.object({
    fcmToken: z.string({ required_error: 'fcmToken is required' }).min(1, 'fcmToken cannot be empty'),
  }),
});

export type UpdateProfileInput = z.infer<typeof updateProfileSchema>['body'];
export type RegisterDeviceTokenInput = z.infer<typeof registerDeviceTokenSchema>['body'];
