import { Router } from 'express';
import { exportAuditLogsCsvHandler, verifyEntityChainHandler } from './audit.controller';

const router = Router();

// Export audit logs as CSV
router.get('/export', exportAuditLogsCsvHandler);

// Public — anyone can verify the chain of custody for a listing/transaction.
router.get('/:entityId', verifyEntityChainHandler);

export default router;
