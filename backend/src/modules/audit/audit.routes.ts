import { Router } from 'express';
import { authenticate } from '../../middleware/authenticate';
import { authorize } from '../../middleware/authorize';
import { exportAuditLogsCsvHandler, verifyEntityChainHandler } from './audit.controller';

const router = Router();

// Export audit logs as CSV — restricted to admin users only
router.get('/export', authenticate, authorize('admin'), exportAuditLogsCsvHandler);

// Public — anyone can verify the chain of custody for a listing/transaction.
router.get('/:entityId', verifyEntityChainHandler);

export default router;
