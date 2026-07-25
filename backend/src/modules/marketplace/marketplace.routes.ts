import { Router } from 'express';
import { authenticate } from '../../middleware/authenticate';
import { validate } from '../../middleware/validate';
import { browseMarketplaceHandler, getMarketplaceListingHandler } from './marketplace.controller';
import { browseMarketplaceSchema, listingIdParamSchema } from './marketplace.schema';

const router = Router();

/**
 * @swagger
 * /marketplace:
 *   get:
 *     summary: Browse active listings with filters, sort, and pagination
 *     tags: [Marketplace]
 *     security: [{ bearerAuth: [] }]
 *     parameters:
 *       - { in: query, name: crop, schema: { type: string } }
 *       - { in: query, name: region, schema: { type: string } }
 *       - { in: query, name: minFreshness, schema: { type: number } }
 *       - { in: query, name: maxFreshness, schema: { type: number } }
 *       - { in: query, name: minQuantity, schema: { type: number } }
 *       - { in: query, name: sort, schema: { type: string, enum: [date, freshness, price], default: date } }
 *       - { in: query, name: order, schema: { type: string, enum: [asc, desc], default: desc } }
 *       - { in: query, name: page, schema: { type: integer, default: 1 } }
 *       - { in: query, name: limit, schema: { type: integer, default: 20, maximum: 50 } }
 *     responses:
 *       200: { description: Paginated, filtered listings }
 */
router.get('/', authenticate, validate(browseMarketplaceSchema), browseMarketplaceHandler);

/**
 * @swagger
 * /marketplace/{id}:
 *   get:
 *     summary: Get marketplace detail view for one listing
 *     tags: [Marketplace]
 *     security: [{ bearerAuth: [] }]
 *     parameters:
 *       - { in: path, name: id, required: true, schema: { type: string, format: uuid } }
 *     responses:
 *       200: { description: Listing detail with farmer region }
 *       404: { description: Listing not found or not active }
 */
router.get('/:id', authenticate, validate(listingIdParamSchema), getMarketplaceListingHandler);

export default router;
