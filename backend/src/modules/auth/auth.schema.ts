import { z } from 'zod';

export const registerSchema = z.object({
  body: z.object({
    name: z.string().min(2, 'Name must be at least 2 characters'),
    phone: z.string().regex(/^\+233\d{9}$/, 'Phone must be a valid Ghana number (+233XXXXXXXXX)'),
    password: z.string().min(6, 'Password must be at least 6 characters'),
    role: z.enum(['farmer', 'buyer', 'driver']),
  }),
});

export const verifyOtpSchema = z.object({
  body: z.object({
    phone: z.string().regex(/^\+233\d{9}$/, 'Phone must be a valid Ghana number (+233XXXXXXXXX)'),
    otp: z.string().length(6, 'OTP must be 6 digits'),
  }),
});

export const loginSchema = z.object({
  body: z.object({
    phone: z.string().regex(/^\+233\d{9}$/, 'Phone must be a valid Ghana number (+233XXXXXXXXX)'),
    password: z.string().min(1, 'Password is required'),
  }),
});

export const refreshSchema = z.object({
  body: z.object({
    refreshToken: z.string().min(1, 'Refresh token is required'),
  }),
});

export type RegisterInput = z.infer<typeof registerSchema>['body'];
export type VerifyOtpInput = z.infer<typeof verifyOtpSchema>['body'];
export type LoginInput = z.infer<typeof loginSchema>['body'];
export type RefreshInput = z.infer<typeof refreshSchema>['body'];
