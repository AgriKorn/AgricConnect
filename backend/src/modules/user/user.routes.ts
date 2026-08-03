import { Router } from 'express';
import { authenticate } from '../../middleware/authenticate';
import { validate } from '../../middleware/validate';
import { getProfileHandler, updateProfileHandler, getPhotoUploadUrlHandler, registerDeviceTokenHandler, removeDeviceTokenHandler } from './user.controller';
import { updateProfileSchema, photoUploadUrlSchema, registerDeviceTokenSchema, removeDeviceTokenSchema } from './user.schema';

const router = Router();

router.get('/profile', authenticate, getProfileHandler);
router.patch('/profile', authenticate, validate(updateProfileSchema), updateProfileHandler);
router.post('/profile/photo-upload-url', authenticate, validate(photoUploadUrlSchema), getPhotoUploadUrlHandler);
router.post('/device-token', authenticate, validate(registerDeviceTokenSchema), registerDeviceTokenHandler);
router.delete('/device-token', authenticate, validate(removeDeviceTokenSchema), removeDeviceTokenHandler);

export default router;
