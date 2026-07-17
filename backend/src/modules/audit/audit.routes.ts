import { Router } from 'express';
import { verifyEntityChainHandler } from './audit.controller';

const router = Router();

// Public — anyone can verify the chain of custody for a listing/transaction.
router.get('/:entityId', verifyEntityChainHandler);

export default router;
