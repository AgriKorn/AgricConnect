import { Router } from 'express';
import { authenticate } from '../../middleware/authenticate';
import { authorize } from '../../middleware/authorize';
import { validate } from '../../middleware/validate';
import {
  acceptJobHandler,
  declineJobHandler,
  getDriverJobsHandler,
  markDeliveredHandler,
  markPickedUpHandler,
} from './dispatch.controller';
import { getDriverJobsQuerySchema, jobIdParamSchema } from './dispatch.schema';

const router = Router();

router.use(authenticate, authorize('driver'));

/**
 * @swagger
 * /dispatch/jobs:
 *   get:
 *     summary: Driver retrieves list of assigned and offered delivery jobs
 *     tags: [Dispatch]
 *     security: [{ bearerAuth: [] }]
 *     parameters:
 *       - { in: query, name: status, schema: { type: string, enum: [PENDING, ACCEPTED, DECLINED, COMPLETED] } }
 *     responses:
 *       200: { description: List of driver jobs }
 * /dispatch/{jobId}/accept:
 *   patch:
 *     summary: Driver accepts an offered delivery job
 *     tags: [Dispatch]
 *     security: [{ bearerAuth: [] }]
 *     parameters:
 *       - { in: path, name: jobId, required: true, schema: { type: string, format: uuid } }
 *     responses:
 *       200: { description: Job accepted, driver marked unavailable }
 *       403: { description: Job wasn't offered to you, or is no longer pending }
 * /dispatch/{jobId}/decline:
 *   patch:
 *     summary: Driver declines an offered job — auto-reassigns to the next available driver
 *     tags: [Dispatch]
 *     security: [{ bearerAuth: [] }]
 *     parameters:
 *       - { in: path, name: jobId, required: true, schema: { type: string, format: uuid } }
 *     responses:
 *       200: { description: "{ job, reassigned }" }
 * /dispatch/{jobId}/picked-up:
 *   patch:
 *     summary: Driver confirms they've collected the produce from the farmer
 *     tags: [Dispatch]
 *     security: [{ bearerAuth: [] }]
 *     parameters:
 *       - { in: path, name: jobId, required: true, schema: { type: string, format: uuid } }
 *     responses:
 *       200: { description: Order moved to IN_TRANSIT }
 *       403: { description: Job isn't in ACCEPTED status }
 * /dispatch/{jobId}/mark-delivered:
 *   patch:
 *     summary: Driver confirms hand-off to the buyer — mints a one-time delivery QR the buyer scans to release escrow
 *     tags: [Dispatch]
 *     security: [{ bearerAuth: [] }]
 *     parameters:
 *       - { in: path, name: jobId, required: true, schema: { type: string, format: uuid } }
 *     responses:
 *       200: { description: Order moved to DELIVERED, response includes deliveryQrImage }
 *       403: { description: Job isn't in IN_TRANSIT status }
 */
router.get('/jobs', validate(getDriverJobsQuerySchema), getDriverJobsHandler);
router.patch('/:jobId/accept', validate(jobIdParamSchema), acceptJobHandler);
router.patch('/:jobId/decline', validate(jobIdParamSchema), declineJobHandler);
router.patch('/:jobId/picked-up', validate(jobIdParamSchema), markPickedUpHandler);
router.patch('/:jobId/mark-delivered', validate(jobIdParamSchema), markDeliveredHandler);

export default router;
