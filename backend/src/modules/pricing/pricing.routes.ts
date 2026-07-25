import { Router } from 'express';
import { authenticate } from '../../middleware/authenticate';
import { validate } from '../../middleware/validate';
import { recommendPriceHandler } from './pricing.controller';
import { recommendPriceSchema } from './pricing.schema';

const router = Router();

/**
 * @swagger
 * /pricing/recommend:
 *   get:
 *     summary: Get a freshness-weighted price recommendation against the MOFA reference price
 *     tags: [Pricing]
 *     security: [{ bearerAuth: [] }]
 *     parameters:
 *       - { in: query, name: crop, required: true, schema: { type: string }, example: tomato }
 *       - { in: query, name: region, required: true, schema: { type: string }, example: "greater accra" }
 *       - { in: query, name: freshness, required: true, schema: { type: number, minimum: 0, maximum: 100 } }
 *       - { in: query, name: shelfLifeDays, schema: { type: integer, minimum: 1 }, description: "Optional — when given, returns a day-by-day decay projection (linear model)" }
 *     responses:
 *       200: { description: "{ mofaPrice, ceiling, softFloor, freshness, decayProjection? }" }
 *       404: { description: No MOFA reference price for that crop/region }
 */
router.get('/recommend', authenticate, validate(recommendPriceSchema), recommendPriceHandler);

export default router;
