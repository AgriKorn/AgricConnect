import { Router } from 'express';
import { authenticate } from '../../middleware/authenticate';
import { validate } from '../../middleware/validate';
import { getProfileHandler, updateProfileHandler } from './user.controller';
import { updateProfileSchema } from './user.schema';

const router = Router();

router.get('/profile', authenticate, getProfileHandler);
router.patch('/profile', authenticate, validate(updateProfileSchema), updateProfileHandler);

export default router;
