import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';
import swaggerUi from 'swagger-ui-express';
import { errorHandler } from './middleware/errorHandler';
import { sendSuccess } from './utils/response';
import { swaggerSpec } from './config/swagger';
import authRoutes from './modules/auth/auth.routes';
import userRoutes from './modules/user/user.routes';
import adminRoutes from './modules/admin/admin.routes';
import listingRoutes from './modules/listing/listing.routes';
import marketplaceRoutes from './modules/marketplace/marketplace.routes';
import pricingRoutes from './modules/pricing/pricing.routes';
import auditRoutes from './modules/audit/audit.routes';
import transactionRoutes from './modules/transaction/transaction.routes';
import dispatchRoutes from './modules/dispatch/dispatch.routes';
import disputeRoutes from './modules/dispute/dispute.routes';
import notificationRoutes from './modules/notification/notification.routes';
import paymentRoutes from './modules/payment/payment.routes';

const app = express();

// --------------- Trust Proxy (Required for AWS Load Balancers & App Runner) ---------------
app.set('trust proxy', 1);

// --------------- Security Middleware ---------------
app.use(helmet());
app.use(cors());

// --------------- Rate Limiting ---------------
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per window
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, error: { code: 'RATE_LIMIT', message: 'Too many requests, please try again later' } },
});
app.use(limiter);

// Strict rate limit for authentication endpoints to prevent brute-force attacks
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 20, // max 20 requests per 15 min per IP
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, error: { code: 'AUTH_RATE_LIMIT', message: 'Too many authentication attempts, please try again later' } },
});
app.use('/api/auth', authLimiter);

// --------------- Body Parsing ---------------
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// --------------- Request Logging ---------------
app.use(morgan('dev'));

import docsRouter from './docs/docs.routes';

// --------------- API Docs ---------------
app.use('/api/docs', docsRouter);

/**
 * @swagger
 * /health:
 *   get:
 *     summary: Health check
 *     description: Confirms the API is running. Template annotation for the rest of the team.
 *     tags: [System]
 *     responses:
 *       200:
 *         description: API is healthy
 *         content:
 *           application/json:
 *             schema:
 *               allOf:
 *                 - $ref: '#/components/schemas/SuccessResponse'
 */
app.get('/api/health', (_req, res) => {
  sendSuccess(res, { message: 'AgriConnect API is running' });
});

// --------------- Routes ---------------
app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/listings', listingRoutes);
app.use('/api/marketplace', marketplaceRoutes);
app.use('/api/pricing', pricingRoutes);
app.use('/api/audit', auditRoutes);
app.use('/api/transactions', transactionRoutes);
app.use('/api/dispatch', dispatchRoutes);
app.use('/api/disputes', disputeRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/payments', paymentRoutes);

// --------------- Global Error Handler (must be last) ---------------
app.use(errorHandler);

export default app;
