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
 *     summary: Confirm delivery via QR hash match — releases escrowed funds to the farmer
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
 *             required: [qrHash]
 *             properties: { qrHash: { type: string } }
 *     responses:
 *       200: { description: Transaction RELEASED, payment transferred to farmer }
 *       400: { description: QR hash does not match the listing }
 */
router.post('/:id/confirm-delivery', validate(transactionIdParamSchema), validate(confirmDeliverySchema), confirmDeliveryHandler);
router.get('/:id', validate(transactionIdParamSchema), getTransactionHandler);

export default router;
