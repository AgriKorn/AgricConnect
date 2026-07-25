import { z } from 'zod';
import dotenv from 'dotenv';
import logger from '../utils/logger';

dotenv.config();

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  PORT: z.string().default('3000').transform((val) => parseInt(val, 10)),
  DATABASE_URL: z.string({ required_error: 'DATABASE_URL environment variable is required' }),
  JWT_SECRET: z.string({ required_error: 'JWT_SECRET environment variable is required' }).min(16, 'JWT_SECRET should be at least 16 characters for security'),
  JWT_REFRESH_SECRET: z.string().default('agriconnect_refresh_secret_min_32_chars_key_2026'),
  PAYSTACK_SECRET_KEY: z.string().optional().default(''),
  AWS_REGION: z.string().default('eu-west-1'),
  AWS_S3_BUCKET_PUBLIC: z.string().default('agriconnect-public-assets'),
  AWS_S3_BUCKET_PRIVATE: z.string().default('agriconnect-private-docs'),
  SUPABASE_URL: z.string().optional().default(''),
  SUPABASE_ANON_KEY: z.string().optional().default(''),
  BOOTSTRAP_ADMIN_ENABLED: z.string().optional().default('false'),
  BOOTSTRAP_ADMIN_PHONE: z.string().optional().default(''),
  BOOTSTRAP_ADMIN_PASSWORD: z.string().optional().default(''),
});

export type EnvConfig = z.infer<typeof envSchema>;

let parsedEnv: EnvConfig;

try {
  parsedEnv = envSchema.parse(process.env);
} catch (error: any) {
  if (process.env.NODE_ENV !== 'test') {
    logger.error('❌ Invalid or missing environment configuration:', error.format ? error.format() : error.message);
  }
  // Fallback defaults for test runner
  parsedEnv = {
    NODE_ENV: (process.env.NODE_ENV as any) || 'test',
    PORT: 3000,
    DATABASE_URL: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/agriconnect_test',
    JWT_SECRET: process.env.JWT_SECRET || 'test_jwt_secret_min_16_characters_long',
    JWT_REFRESH_SECRET: process.env.JWT_REFRESH_SECRET || 'test_refresh_secret_min_32_characters_long',
    PAYSTACK_SECRET_KEY: process.env.PAYSTACK_SECRET_KEY || '',
    AWS_REGION: 'eu-west-1',
    AWS_S3_BUCKET_PUBLIC: 'agriconnect-public-assets',
    AWS_S3_BUCKET_PRIVATE: 'agriconnect-private-docs',
    SUPABASE_URL: process.env.SUPABASE_URL || '',
    SUPABASE_ANON_KEY: process.env.SUPABASE_ANON_KEY || '',
    BOOTSTRAP_ADMIN_ENABLED: 'false',
    BOOTSTRAP_ADMIN_PHONE: '',
    BOOTSTRAP_ADMIN_PASSWORD: '',
  };
}

export const env = parsedEnv;
