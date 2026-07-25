import { extendZodWithOpenApi, OpenAPIRegistry } from '@asteasolutions/zod-to-openapi';
import { z } from 'zod';

// Extend Zod methods with .openapi() metadata helpers
extendZodWithOpenApi(z);

export const registry = new OpenAPIRegistry();

// Register global Bearer Auth security scheme for JWT authentication
registry.registerComponent('securitySchemes', 'bearerAuth', {
  type: 'http',
  scheme: 'bearer',
  bearerFormat: 'JWT',
  description: 'Enter your Bearer JWT token obtained from /api/auth/login or /api/auth/google',
});

// Standard API Response Envelope schema
export const ErrorEnvelopeSchema = registry.register(
  'ErrorEnvelope',
  z
    .object({
      success: z.literal(false).openapi({ example: false }),
      error: z.object({
        code: z.string().openapi({ example: 'INVALID_TOKEN', description: 'Machine-readable application error code' }),
        message: z.string().openapi({ example: 'The provided access token is invalid or expired.', description: 'Human-readable error explanation' }),
      }),
    })
    .openapi({ description: 'Standard machine-readable error payload returned on any non-2xx status' }),
);

export const SuccessEnvelopeSchema = <T extends z.ZodTypeAny>(dataSchema: T, description?: string) =>
  z.object({
    success: z.literal(true).openapi({ example: true }),
    data: dataSchema,
  }).openapi({ description });
