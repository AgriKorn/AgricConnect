import { Router } from 'express';
import { authenticate } from '../../middleware/authenticate';
import { getNotificationsHandler, markReadHandler } from './notification.controller';

const router = Router();

router.use(authenticate);

router.get('/', getNotificationsHandler);
router.patch('/:id/read', markReadHandler);

export default router;
