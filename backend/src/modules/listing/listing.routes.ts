import { Router } from 'express';
import { authenticate } from '../../middleware/authenticate';
import { authorize } from '../../middleware/authorize';
import { requireApproved } from '../../middleware/requireApproved';
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

/**
 * @swagger
 * /listings:
 *   post:
 *     summary: Create a produce listing (farmer only)
 *     tags: [Listings]
 *     security: [{ bearerAuth: [] }]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [cropType, quantityKg, freshnessScore, shelfLifeDays, farmerLat, farmerLong, pricePerKg]
 *             properties:
 *               cropType: { type: string, example: tomato }
 *               quantityKg: { type: number, example: 500 }
 *               freshnessScore: { type: number, minimum: 0, maximum: 100 }
 *               shelfLifeDays: { type: integer }
 *               farmerLat: { type: number }
 *               farmerLong: { type: number }
 *               pricePerKg: { type: number }
 *     responses:
 *       201: { description: Listing created with SHA-256 hash + QR code }
 *       401: { description: Authentication required }
 *   get:
 *     summary: Get the logged-in farmer's own listings
 *     tags: [Listings]
 *     security: [{ bearerAuth: [] }]
 *     responses:
 *       200: { description: Farmer's active listings }
 */
router.post('/', authenticate, authorize('farmer'), requireApproved, validate(createListingSchema), createListingHandler);
router.get('/', authenticate, authorize('farmer'), getFarmerListingsHandler);

/**
 * @swagger
 * /listings/{id}:
 *   get:
 *     summary: Get a single listing by ID (public)
 *     tags: [Listings]
 *     parameters:
 *       - { in: path, name: id, required: true, schema: { type: string, format: uuid } }
 *     responses:
 *       200: { description: Listing found }
 *       404: { description: Listing not found }
 *   patch:
 *     summary: Update price/quantity on your own listing (farmer only)
 *     tags: [Listings]
 *     security: [{ bearerAuth: [] }]
 *     parameters:
 *       - { in: path, name: id, required: true, schema: { type: string, format: uuid } }
 *     responses:
 *       200: { description: Listing updated }
 *       403: { description: Not the listing owner }
 *   delete:
 *     summary: Soft-delete your own listing (farmer only)
 *     tags: [Listings]
 *     security: [{ bearerAuth: [] }]
 *     parameters:
 *       - { in: path, name: id, required: true, schema: { type: string, format: uuid } }
 *     responses:
 *       200: { description: Listing marked INACTIVE }
 */
router.get('/:id', validate(listingIdParamSchema), getListingByIdHandler);
router.patch(
  '/:id',
  authenticate,
  authorize('farmer'),
  validate(listingIdParamSchema),
  validate(updateListingSchema),
  updateListingHandler,
);
router.delete('/:id', authenticate, authorize('farmer'), validate(listingIdParamSchema), deleteListingHandler);

export default router;
