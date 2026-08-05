import { Router } from 'express';
import { authenticate } from '../../middleware/authenticate';
import { authorize } from '../../middleware/authorize';
import { requireApproved } from '../../middleware/requireApproved';
import { validate } from '../../middleware/validate';
import { confirmDeliveryHandler, getMyTransactionsHandler, getTransactionHandler, purchaseHandler } from './transaction.controller';
import { confirmDeliverySchema, purchaseSchema, transactionIdParamSchema } from './transaction.schema';

const router = Router();

router.use(authenticate);

/**
 * @swagger
 * /transactions/purchase:
 *   post:
 *     summary: Buyer purchases a listing — funds held in escrow, driver auto-dispatched if needed
 *     tags: [Transactions]
 *     security: [{ bearerAuth: [] }]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [listingId, hasOwnTransport]
 *             properties:
 *               listingId: { type: string, format: uuid }
 *               hasOwnTransport: { type: boolean }
 *     responses:
 *       201: { description: "{ transaction, dispatch }" }
 *       409: { description: Listing already has a purchase in progress }
 */
router.post('/purchase', authorize('buyer'), requireApproved, validate(purchaseSchema), purchaseHandler);

router.get('/', getMyTransactionsHandler);

/**
 * @swagger
 * /transactions/{id}/confirm-delivery:
 *   post:
 *     summary: Buyer confirms delivery by scanning a QR code — releases escrowed funds to the farmer
 *     description: >
 *       For self-collect orders this is the farmer's static per-listing QR, scanned at pickup.
 *       For driver-delivered orders this is the one-time QR the driver generates via
 *       PATCH /dispatch/{jobId}/mark-delivered, scanned off the driver's screen at hand-off.
 *       Only the buyer may call this endpoint.
 *     tags: [Transactions]
 *     security: [{ bearerAuth: [] }]
 *     parameters:
 *       - { in: path, name: id, required: true, schema: { type: string, format: uuid } }
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [code]
 *             properties: { code: { type: string } }
 *     responses:
 *       200: { description: Transaction RELEASED, payment transferred to farmer }
 *       400: { description: Code does not match, is expired, or order isn't awaiting confirmation }
 *       403: { description: Only the buyer may confirm delivery }
 */
router.post('/:id/confirm-delivery', validate(transactionIdParamSchema), validate(confirmDeliverySchema), confirmDeliveryHandler);
router.get('/:id', validate(transactionIdParamSchema), getTransactionHandler);

export default router;
