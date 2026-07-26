import { z } from 'zod';

export const createListingSchema = z.object({
  body: z.object({
    cropType: z.string({
      required_error: 'Crop type is required',
      invalid_type_error: 'Crop type must be a string',
    }).min(1, 'Crop type cannot be empty'),

    quantityKg: z.number({
      required_error: 'Quantity (kg) is required',
      invalid_type_error: 'Quantity must be a number',
    }).positive('Quantity must be greater than 0'),

    freshnessScore: z.number({
      required_error: 'Freshness score is required',
      invalid_type_error: 'Freshness score must be a number',
    }).min(0, 'Freshness score must be at least 0').max(100, 'Freshness score cannot exceed 100'),

    shelfLifeDays: z.number({
      required_error: 'Shelf life (days) is required',
      invalid_type_error: 'Shelf life must be a number',
    }).int('Shelf life must be a whole number').positive('Shelf life must be greater than 0'),

    farmerLat: z.number({
      required_error: 'Latitude is required',
      invalid_type_error: 'Latitude must be a number',
    }).min(-90, 'Latitude must be between -90 and 90').max(90, 'Latitude must be between -90 and 90'),

    farmerLong: z.number({
      required_error: 'Longitude is required',
      invalid_type_error: 'Longitude must be a number',
    }).min(-180, 'Longitude must be between -180 and 180').max(180, 'Longitude must be between -180 and 180'),

    pricePerKg: z.number({
      required_error: 'Price per kg is required',
      invalid_type_error: 'Price per kg must be a number',
    }).positive('Price per kg must be greater than 0'),
  }),
});

export const updateListingSchema = z.object({
  body: z.object({
    pricePerKg: z.number({
      invalid_type_error: 'Price per kg must be a number',
    }).positive('Price per kg must be greater than 0').optional(),

    quantityKg: z.number({
      invalid_type_error: 'Quantity must be a number',
    }).positive('Quantity must be greater than 0').optional(),
  }),
});

export const listingIdParamSchema = z.object({
  params: z.object({
    id: z.string({
      required_error: 'Listing ID is required',
      invalid_type_error: 'Listing ID must be a string',
    }).uuid('Listing ID must be a valid UUID'),
  }),
});

export type CreateListingInput = z.infer<typeof createListingSchema>['body'];
export type UpdateListingInput = z.infer<typeof updateListingSchema>['body'];
export type ListingIdParam = z.infer<typeof listingIdParamSchema>['params'];
