import { Router } from 'express';
import { validate } from '../../middleware/validate';
import {
  forgotPasswordHandler,
  getGoogleAuthUrlHandler,
  googleAuthHandler,
  loginHandler,
  logoutHandler,
  refreshHandler,
  registerHandler,
  resetPasswordHandler,
} from './auth.controller';
import {
  forgotPasswordSchema,
  googleAuthSchema,
  loginSchema,
  refreshSchema,
  registerSchema,
  resetPasswordSchema,
} from './auth.schema';

const router = Router();

/**
 * @swagger
 * /auth/register:
 *   post:
 *     summary: Register a new user
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [name, phone, password, role]
 *             properties:
 *               name: { type: string, example: Kwame Asante }
 *               phone: { type: string, example: "+233241234567" }
 *               password: { type: string, format: password }
 *               role: { type: string, enum: [farmer, buyer, driver] }
 *     responses:
 *       201: { description: Registered, account pending admin approval }
 *       409: { description: Phone number already registered }
 */
router.post('/register', validate(registerSchema), registerHandler);

/**
 * @swagger
 * /auth/google/url:
 *   get:
 *     summary: Get Supabase Google OAuth authorization URL
 *     tags: [Auth]
 *     parameters:
 *       - { in: query, name: redirectTo, schema: { type: string } }
 *     responses:
 *       200: { description: OAuth redirect URL }
 */
router.get('/google/url', getGoogleAuthUrlHandler);

/**
 * @swagger
 * /auth/google:
 *   post:
 *     summary: Sign up or log in via Google OAuth / Supabase token
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [token]
 *             properties:
 *               token: { type: string }
 *               role: { type: string, enum: [farmer, buyer, driver] }
 *     responses:
 *       200: { description: Access token (15m) + refresh token (7d) issued }
 *       401: { description: Invalid Google token }
 */
router.post('/google', validate(googleAuthSchema), googleAuthHandler);

/**
 * @swagger
 * /auth/forgot-password:
 *   post:
 *     summary: Request a password reset token
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [phone]
 *             properties:
 *               phone: { type: string, example: "+233241234567" }
 *     responses:
 *       200: { description: Password reset token issued }
 *       404: { description: User not found }
 */
router.post('/forgot-password', validate(forgotPasswordSchema), forgotPasswordHandler);

/**
 * @swagger
 * /auth/reset-password:
 *   post:
 *     summary: Reset user password using reset token
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [token, newPassword]
 *             properties:
 *               token: { type: string }
 *               newPassword: { type: string, format: password }
 *     responses:
 *       200: { description: Password reset successfully }
 *       400: { description: Invalid or expired token }
 */
router.post('/reset-password', validate(resetPasswordSchema), resetPasswordHandler);

/**
 * @swagger
 * /auth/login:
 *   post:
 *     summary: Log in and receive JWT access + refresh tokens
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [phone, password]
 *             properties:
 *               phone: { type: string }
 *               password: { type: string, format: password }
 *     responses:
 *       200: { description: Access token (15m) + refresh token (7d) issued }
 *       401: { description: Invalid credentials }
 *       403: { description: Phone not yet verified, or account rejected }
 */
router.post('/login', validate(loginSchema), loginHandler);

/**
 * @swagger
 * /auth/refresh:
 *   post:
 *     summary: Exchange a valid refresh token for a new access token
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [refreshToken]
 *             properties: { refreshToken: { type: string } }
 *     responses:
 *       200: { description: New access token issued }
 *       401: { description: Refresh token invalid, expired, or revoked }
 */
router.post('/refresh', validate(refreshSchema), refreshHandler);

/**
 * @swagger
 * /auth/logout:
 *   post:
 *     summary: Invalidate a refresh token
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [refreshToken]
 *             properties: { refreshToken: { type: string } }
 *     responses:
 *       200: { description: Logged out }
 */
router.post('/logout', validate(refreshSchema), logoutHandler);

export default router;
