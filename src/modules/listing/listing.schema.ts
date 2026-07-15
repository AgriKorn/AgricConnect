import { z } from 'zod';

export const createListingSchema = z.object({
  body: z.object({
    crop_type: z.string({
      required_error: 'Crop type is required',
      invalid_type_error: 'Crop type must be a string',
    }).min(1, 'Crop type cannot be empty'),
    
    quantity_kg: z.number({
      required_error: 'Quantity (kg) is required',
      invalid_type_error: 'Quantity must be a number',
    }).positive('Quantity must be greater than 0'),
    
    freshness_score: z.number({
      required_error: 'Freshness score is required',
      invalid_type_error: 'Freshness score must be a number',
    }).min(0, 'Freshness score must be at least 0').max(100, 'Freshness score cannot exceed 100'),
    
    shelf_life_days: z.number({
      required_error: 'Shelf life (days) is required',
      invalid_type_error: 'Shelf life must be a number',
    }).int('Shelf life must be a whole number').positive('Shelf life must be greater than 0'),
    
    farmer_lat: z.number({
      required_error: 'Latitude is required',
      invalid_type_error: 'Latitude must be a number',
    }).min(-90, 'Latitude must be between -90 and 90').max(90, 'Latitude must be between -90 and 90'),
    
    farmer_long: z.number({
      required_error: 'Longitude is required',
      invalid_type_error: 'Longitude must be a number',
    }).min(-180, 'Longitude must be between -180 and 180').max(180, 'Longitude must be between -180 and 180'),
    
    price_per_kg: z.number({
      required_error: 'Price per kg is required',
      invalid_type_error: 'Price per kg must be a number',
    }).positive('Price per kg must be greater than 0'),
  })
});

export const updateListingSchema = z.object({
  body: z.object({
    price_per_kg: z.number({
      invalid_type_error: 'Price per kg must be a number',
    }).positive('Price per kg must be greater than 0').optional(),
    
    quantity_kg: z.number({
      invalid_type_error: 'Quantity must be a number',
    }).positive('Quantity must be greater than 0').optional(),
  })
});

export const listingIdParamSchema = z.object({
  params: z.object({
    id: z.string({
      required_error: 'Listing ID is required',
      invalid_type_error: 'Listing ID must be a string',
    }).uuid('Listing ID must be a valid UUID'),
  })
});

// Infer types for use in controllers/services if needed
export type CreateListingInput = z.infer<typeof createListingSchema>['body'];
export type UpdateListingInput = z.infer<typeof updateListingSchema>['body'];
export type ListingIdParam = z.infer<typeof listingIdParamSchema>['params'];
