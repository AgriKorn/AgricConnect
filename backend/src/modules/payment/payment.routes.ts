import { Router } from 'express';
import { authenticate } from '../../middleware/authenticate';
import { resolveMomoAccountHandler, paystackWebhookHandler } from './payment.controller';

const router = Router();

// Mobile Money account verification (requires JWT auth)
router.get('/paystack/resolve-momo', authenticate, resolveMomoAccountHandler);

// Paystack Webhook receiver endpoint (signed by Paystack HMAC SHA-512)
router.post('/paystack/webhook', paystackWebhookHandler);

export default router;
