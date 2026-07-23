import { z } from 'zod';
import { registry } from '../../docs/openapi.registry';

const UserResponseSchema = z.object({
  id: z.string().uuid().openapi({ example: '84130725-3a7e-41dc-9621-57c54fa57ec4' }),
  name: z.string().openapi({ example: 'Kofi Mensah' }),
  phone: z.string().openapi({ example: '+233541234567' }),
  email: z.string().email().nullable().openapi({ example: 'kofi.mensah@agriconnect.com' }),
  role: z.enum(['farmer', 'buyer', 'driver', 'admin']).openapi({ example: 'farmer' }),
  status: z.enum(['pending_approval', 'approved', 'rejected']).openapi({ example: 'approved' }),
  createdAt: z.string().datetime().openapi({ example: '2026-07-22T22:00:00.000Z' }),
});

const AuthTokensResponseSchema = z.object({
  accessToken: z.string().openapi({ example: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...' }),
  refreshToken: z.string().openapi({ example: 'd87ceb39-43e2-45c9-a063-be88067e5710' }),
  user: UserResponseSchema,
});

// POST /api/auth/register
registry.registerPath({
  method: 'post',
  path: '/api/auth/register',
  summary: 'Register a new user (Farmer, Buyer, Driver, Admin)',
  tags: ['Authentication'],
  request: {
    body: {
      content: {
        'application/json': {
          schema: z.object({
            name: z.string().min(2).openapi({ example: 'Kofi Mensah' }),
            phone: z.string().min(10).openapi({ example: '+233541234567' }),
            password: z.string().min(6).openapi({ example: 'SecureFarmerP@ss1' }),
            role: z.enum(['farmer', 'buyer', 'driver', 'admin']).default('buyer').openapi({ example: 'farmer' }),
            email: z.string().email().optional().openapi({ example: 'kofi.mensah@agriconnect.com' }),
          }),
        },
      },
    },
  },
  responses: {
    201: {
      description: 'Registration successful',
      content: {
        'application/json': {
          schema: z.object({
            success: z.literal(true).openapi({ example: true }),
            data: AuthTokensResponseSchema,
          }),
        },
      },
    },
    400: { description: 'Validation error or invalid input format' },
    409: { description: 'Phone number already registered (`PHONE_ALREADY_REGISTERED`)' },
    429: { description: 'Too many authentication attempts (`AUTH_RATE_LIMIT`)' },
  },
});

// POST /api/auth/login
registry.registerPath({
  method: 'post',
  path: '/api/auth/login',
  summary: 'Authenticate with Phone and Password',
  tags: ['Authentication'],
  request: {
    body: {
      content: {
        'application/json': {
          schema: z.object({
            phone: z.string().openapi({ example: '+233541234567' }),
            password: z.string().openapi({ example: 'SecureFarmerP@ss1' }),
          }),
        },
      },
    },
  },
  responses: {
    200: {
      description: 'Authentication successful',
      content: {
        'application/json': {
          schema: z.object({
            success: z.literal(true).openapi({ example: true }),
            data: AuthTokensResponseSchema,
          }),
        },
      },
    },
    401: { description: 'Invalid phone or password (`INVALID_CREDENTIALS`)' },
    403: { description: 'Account pending approval or rejected (`ACCOUNT_PENDING_APPROVAL`, `ACCOUNT_REJECTED`)' },
  },
});

// POST /api/auth/google
registry.registerPath({
  method: 'post',
  path: '/api/auth/google',
  summary: 'Authenticate or Register via Supabase Google OAuth',
  tags: ['Authentication'],
  request: {
    body: {
      content: {
        'application/json': {
          schema: z.object({
            idToken: z.string().openapi({ example: 'eyJhbGciOiJSUzI1NiIsImtpZCI6...' }),
            role: z.enum(['farmer', 'buyer', 'driver', 'admin']).optional().default('buyer').openapi({ example: 'buyer' }),
          }),
        },
      },
    },
  },
  responses: {
    200: {
      description: 'Google OAuth authentication successful',
      content: {
        'application/json': {
          schema: z.object({
            success: z.literal(true).openapi({ example: true }),
            data: AuthTokensResponseSchema,
          }),
        },
      },
    },
    400: { description: 'Invalid Google OAuth ID token (`OAUTH_PROVIDER_ERROR`)' },
  },
});

// POST /api/auth/refresh
registry.registerPath({
  method: 'post',
  path: '/api/auth/refresh',
  summary: 'Rotate Access Token using Refresh Token',
  tags: ['Authentication'],
  request: {
    body: {
      content: {
        'application/json': {
          schema: z.object({
            refreshToken: z.string().openapi({ example: 'd87ceb39-43e2-45c9-a063-be88067e5710' }),
          }),
        },
      },
    },
  },
  responses: {
    200: {
      description: 'Token refreshed successfully',
      content: {
        'application/json': {
          schema: z.object({
            success: z.literal(true).openapi({ example: true }),
            data: z.object({
              accessToken: z.string().openapi({ example: 'eyJhbGciOiJIUzI1NiIsInR5cCI6...' }),
              refreshToken: z.string().openapi({ example: 'b95868b5-89fd-46be-bc23-701925c83b1d' }),
            }),
          }),
        },
      },
    },
    401: { description: 'Refresh token expired or revoked (`INVALID_TOKEN`, `TOKEN_EXPIRED`)' },
  },
});

// POST /api/auth/logout
registry.registerPath({
  method: 'post',
  path: '/api/auth/logout',
  summary: 'Revoke Refresh Token & Logout User',
  tags: ['Authentication'],
  request: {
    body: {
      content: {
        'application/json': {
          schema: z.object({
            refreshToken: z.string().openapi({ example: 'd87ceb39-43e2-45c9-a063-be88067e5710' }),
          }),
        },
      },
    },
  },
  responses: {
    200: {
      description: 'Logout successful',
      content: {
        'application/json': {
          schema: z.object({
            success: z.literal(true).openapi({ example: true }),
            data: z.object({ message: z.string().openapi({ example: 'Logged out successfully' }) }),
          }),
        },
      },
    },
  },
});

// POST /api/auth/forgot-password
registry.registerPath({
  method: 'post',
  path: '/api/auth/forgot-password',
  summary: 'Request Password Reset Token',
  tags: ['Authentication'],
  request: {
    body: {
      content: {
        'application/json': {
          schema: z.object({
            phone: z.string().openapi({ example: '+233541234567' }),
          }),
        },
      },
    },
  },
  responses: {
    200: {
      description: 'Password reset request acknowledged',
      content: {
        'application/json': {
          schema: z.object({
            success: z.literal(true).openapi({ example: true }),
            data: z.object({ message: z.string().openapi({ example: 'Password reset token generated' }) }),
          }),
        },
      },
    },
  },
});

// POST /api/auth/reset-password
registry.registerPath({
  method: 'post',
  path: '/api/auth/reset-password',
  summary: 'Confirm Password Reset with Token',
  tags: ['Authentication'],
  request: {
    body: {
      content: {
        'application/json': {
          schema: z.object({
            token: z.string().openapi({ example: 'reset_token_uuid' }),
            newPassword: z.string().min(6).openapi({ example: 'NewSecureP@ss2026' }),
          }),
        },
      },
    },
  },
  responses: {
    200: {
      description: 'Password reset successfully',
      content: {
        'application/json': {
          schema: z.object({
            success: z.literal(true).openapi({ example: true }),
            data: z.object({ message: z.string().openapi({ example: 'Password reset successful' }) }),
          }),
        },
      },
    },
    400: { description: 'Invalid or expired reset token (`INVALID_TOKEN`)' },
  },
});
