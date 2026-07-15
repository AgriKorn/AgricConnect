import { Router } from 'express';
import {
  createListingHandler,
  getFarmerListingsHandler,
  getListingByIdHandler,
  updateListingHandler,
  deleteListingHandler
} from './listing.controller';

const router = Router();

// ==========================================
// Middleware Injection Points (Pending Afia's auth and validate middleware)
// Example usage: router.post('/', authenticate, validate(createListingSchema), createListingHandler);
// ==========================================

// Map POST / -> createListingHandler
// Requires: authenticate, validate(createListingSchema)
router.post('/', createListingHandler);

// Map GET / -> getFarmerListingsHandler
// Requires: authenticate
router.get('/', getFarmerListingsHandler);

// Map GET /:id -> getListingByIdHandler
// Requires: authenticate, validate(listingIdParamSchema)
router.get('/:id', getListingByIdHandler);

// Map PATCH /:id -> updateListingHandler
// Requires: authenticate, validate(listingIdParamSchema), validate(updateListingSchema)
router.patch('/:id', updateListingHandler);

// Map DELETE /:id -> deleteListingHandler
// Requires: authenticate, validate(listingIdParamSchema)
router.delete('/:id', deleteListingHandler);

export default router;
