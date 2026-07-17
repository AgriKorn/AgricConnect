import { Router } from 'express';
import { validate } from '../../middleware/validate';
import { loginHandler, logoutHandler, refreshHandler, registerHandler, verifyOtpHandler } from './auth.controller';
import { loginSchema, refreshSchema, registerSchema, verifyOtpSchema } from './auth.schema';

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
 *       201: { description: Registered, OTP dispatched via SmsService }
 *       409: { description: Phone number already registered }
 */
router.post('/register', validate(registerSchema), registerHandler);

/**
 * @swagger
 * /auth/verify-otp:
 *   post:
 *     summary: Verify the OTP sent at registration
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [phone, otp]
 *             properties:
 *               phone: { type: string }
 *               otp: { type: string, minLength: 6, maxLength: 6 }
 *     responses:
 *       200: { description: Phone verified, account now pending admin approval }
 *       400: { description: Invalid or expired OTP }
 */
router.post('/verify-otp', validate(verifyOtpSchema), verifyOtpHandler);

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
