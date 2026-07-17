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

export type UpdateProfileInput = z.infer<typeof updateProfileSchema>['body'];
