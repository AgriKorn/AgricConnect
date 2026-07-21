import { Router } from 'express';
import { authenticate } from '../../middleware/authenticate';
import { authorize } from '../../middleware/authorize';
import { validate } from '../../middleware/validate';
import { disputeIdParamSchema, resolveDisputeSchema } from '../dispute/dispute.schema';
import {
  approveUserHandler,
  listDisputesHandler,
  listPendingUsersHandler,
  listTransactionsHandler,
  rejectUserHandler,
  resolveDisputeHandler,
} from './admin.controller';
import { userIdParamSchema } from './admin.schema';

const router = Router();

router.use(authenticate, authorize('admin'));

router.get('/users/pending', listPendingUsersHandler);
router.patch('/users/:id/approve', validate(userIdParamSchema), approveUserHandler);
router.patch('/users/:id/reject', validate(userIdParamSchema), rejectUserHandler);

router.get('/transactions', listTransactionsHandler);

router.get('/disputes', listDisputesHandler);
router.patch('/disputes/:id/resolve', validate(disputeIdParamSchema), validate(resolveDisputeSchema), resolveDisputeHandler);

export default router;
