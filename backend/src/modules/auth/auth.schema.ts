import { z } from 'zod';

/** Preprocesses Ghana phone numbers (05X... or 233... to +233...) and role strings (FARMER to farmer) */

export const normalizePhone = (val: unknown): unknown => {
  if (typeof val !== 'string') return val;
  let p = val.trim().replace(/\s+/g, '');
  if (/^0\d{9}$/.test(p)) {
    return `+233${p.slice(1)}`;
  }
  if (/^233\d{9}$/.test(p)) {
    return `+${p}`;
  }
  return p;
};

const normalizeRole = (val: unknown): unknown => {
  if (typeof val !== 'string') return val;
  return val.trim().toLowerCase();
};

export const phoneSchema = z.preprocess(
  normalizePhone,
  z.string().trim().regex(/^\+233\d{9}$/, 'Phone must be a valid Ghana number (+233XXXXXXXXX)'),
);

const roleSchema = z.preprocess(
  normalizeRole,
  z.enum(['farmer', 'buyer', 'driver']),
);

export const registerSchema = z.object({
  body: z.object({
    name: z.string().trim().min(2, 'Name must be at least 2 characters'),
    phone: phoneSchema,
    email: z.string().trim().toLowerCase().email('Enter a valid email address').optional(),
    password: z.string().min(8, 'Password must be at least 8 characters'),
    role: roleSchema,
  }),
});

export const forgotPasswordSchema = z.object({
  body: z.object({
    phone: phoneSchema,
  }),
});

export const resetPasswordSchema = z.object({
  body: z.object({
    token: z.string().trim().min(1, 'Reset token is required'),
    newPassword: z.string().min(8, 'New password must be at least 8 characters'),
  }),
});

export const loginSchema = z.object({
  body: z.object({
    phone: phoneSchema,
    password: z.string().min(1, 'Password is required'),
  }),
});

export const refreshSchema = z.object({
  body: z.object({
    refreshToken: z.string().min(1, 'Refresh token is required'),
  }),
});

export const googleAuthSchema = z.object({
  body: z.object({
    token: z.string().trim().min(1, 'Google ID token or Supabase session token is required'),
    role: z.preprocess(normalizeRole, z.enum(['farmer', 'buyer', 'driver']).optional()),
  }),
});

export type RegisterInput = z.infer<typeof registerSchema>['body'];
export type ForgotPasswordInput = z.infer<typeof forgotPasswordSchema>['body'];
export type ResetPasswordInput = z.infer<typeof resetPasswordSchema>['body'];
export type LoginInput = z.infer<typeof loginSchema>['body'];
export type RefreshInput = z.infer<typeof refreshSchema>['body'];
export type GoogleAuthInput = z.infer<typeof googleAuthSchema>['body'];
