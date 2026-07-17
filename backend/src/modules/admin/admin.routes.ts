import { Router } from 'express';
import { authenticate } from '../../middleware/authenticate';
import { authorize } from '../../middleware/authorize';
import { validate } from '../../middleware/validate';
import { approveUserHandler, listPendingUsersHandler, rejectUserHandler } from './admin.controller';
import { userIdParamSchema } from './admin.schema';

const router = Router();

router.use(authenticate, authorize('admin'));
router.get('/users/pending', listPendingUsersHandler);
router.patch('/users/:id/approve', validate(userIdParamSchema), approveUserHandler);
router.patch('/users/:id/reject', validate(userIdParamSchema), rejectUserHandler);

export default router;
