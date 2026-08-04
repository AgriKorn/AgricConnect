import { Router } from 'express';
import { authenticate } from '../../middleware/authenticate';
import { authorize } from '../../middleware/authorize';
import { validate } from '../../middleware/validate';
import { disputeIdParamSchema, resolveDisputeSchema } from '../dispute/dispute.schema';
import {
  approveUserHandler,
  createAdminHandler,
  getAuditLogsHandler,
  listAdminsHandler,
  listDisputesHandler,
  listPendingUsersHandler,
  listTransactionsHandler,
  manualAssignDriverHandler,
  rejectUserHandler,
  removeAdminHandler,
  resolveDisputeHandler,
} from './admin.controller';
import { createAdminSchema, manualAssignDriverSchema, userIdParamSchema } from './admin.schema';

const router = Router();

router.use(authenticate, authorize('admin'));

router.get('/admins', listAdminsHandler);
router.post('/admins', validate(createAdminSchema), createAdminHandler);
router.delete('/admins/:id', validate(userIdParamSchema), removeAdminHandler);

router.get('/users/pending', listPendingUsersHandler);
router.patch('/users/:id/approve', validate(userIdParamSchema), approveUserHandler);
router.patch('/users/:id/reject', validate(userIdParamSchema), rejectUserHandler);

router.get('/transactions', listTransactionsHandler);

router.get('/disputes', listDisputesHandler);
router.patch('/disputes/:id/resolve', validate(disputeIdParamSchema), validate(resolveDisputeSchema), resolveDisputeHandler);

router.post('/dispatch/assign', validate(manualAssignDriverSchema), manualAssignDriverHandler);

router.get('/audit', getAuditLogsHandler);

export default router;
