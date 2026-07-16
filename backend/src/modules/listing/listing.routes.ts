import { Router } from 'express';
import { validate } from '../../middleware/validate';
import {
  createListingHandler,
  deleteListingHandler,
  getFarmerListingsHandler,
  getListingByIdHandler,
  updateListingHandler,
} from './listing.controller';
import { createListingSchema, listingIdParamSchema, updateListingSchema } from './listing.schema';

const router = Router();

// NOTE: authenticate + authorize('farmer') pending Afia's auth middleware (A2).
// Once available: router.post('/', authenticate, authorize('farmer'), validate(createListingSchema), createListingHandler);
router.post('/', validate(createListingSchema), createListingHandler);
router.get('/', getFarmerListingsHandler);
router.get('/:id', validate(listingIdParamSchema), getListingByIdHandler);
router.patch('/:id', validate(listingIdParamSchema), validate(updateListingSchema), updateListingHandler);
router.delete('/:id', validate(listingIdParamSchema), deleteListingHandler);

export default router;
