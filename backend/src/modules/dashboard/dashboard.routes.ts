import { Router } from 'express';
import { authenticate } from '../../middleware/authenticate';
import { authorize } from '../../middleware/authorize';
import { getFarmerSummaryHandler } from './dashboard.controller';

const router = Router();

/**
 * @swagger
 * /dashboard/farmer-summary:
 *   get:
 *     summary: Real dashboard stats for the logged-in farmer — earnings, active orders, sales, primary crops, market trend
 *     tags: [Dashboard]
 *     security: [{ bearerAuth: [] }]
 *     responses:
 *       200: { description: "{ location, todaysEarningsGhs, totalEarningsGhs, activeOrders, salesCount, primaryCrops, marketTrendPercent }" }
 */
router.get('/farmer-summary', authenticate, authorize('farmer'), getFarmerSummaryHandler);

export default router;
