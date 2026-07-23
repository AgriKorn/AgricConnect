import { z } from 'zod';

export const registerSchema = z.object({
  body: z.object({
    name: z.string().trim().min(2, 'Name must be at least 2 characters'),
    phone: z.string().trim().regex(/^\+233\d{9}$/, 'Phone must be a valid Ghana number (+233XXXXXXXXX)'),
    password: z.string().min(8, 'Password must be at least 8 characters'),
    role: z.enum(['farmer', 'buyer', 'driver']),
  }),
});

export const forgotPasswordSchema = z.object({
  body: z.object({
    phone: z.string().trim().regex(/^\+233\d{9}$/, 'Phone must be a valid Ghana number (+233XXXXXXXXX)'),
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
    phone: z.string().trim().regex(/^\+233\d{9}$/, 'Phone must be a valid Ghana number (+233XXXXXXXXX)'),
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
    role: z.enum(['farmer', 'buyer', 'driver']).optional(),
  }),
});

export type RegisterInput = z.infer<typeof registerSchema>['body'];
export type ForgotPasswordInput = z.infer<typeof forgotPasswordSchema>['body'];
export type ResetPasswordInput = z.infer<typeof resetPasswordSchema>['body'];
export type LoginInput = z.infer<typeof loginSchema>['body'];
export type RefreshInput = z.infer<typeof refreshSchema>['body'];
export type GoogleAuthInput = z.infer<typeof googleAuthSchema>['body'];
