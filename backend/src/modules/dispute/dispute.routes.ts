import { Router } from 'express';
import { authenticate } from '../../middleware/authenticate';
import { validate } from '../../middleware/validate';
import { raiseDisputeHandler } from './dispute.controller';
import { createDisputeSchema } from './dispute.schema';

const router = Router();

/**
 * @swagger
 * /disputes:
 *   post:
 *     summary: Raise a dispute on a transaction you're party to
 *     tags: [Disputes]
 *     security: [{ bearerAuth: [] }]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [transactionId, type, description]
 *             properties:
 *               transactionId: { type: string, format: uuid }
 *               type: { type: string, enum: [WRONG_PRODUCE, NON_DELIVERY, PAYMENT_ISSUE, OTHER] }
 *               description: { type: string, minLength: 10 }
 *     responses:
 *       201: { description: Dispute filed, status OPEN }
 *       403: { description: Not a participant in that transaction }
 */
router.post('/', authenticate, validate(createDisputeSchema), raiseDisputeHandler);

export default router;
