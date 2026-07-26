import swaggerJsdoc from 'swagger-jsdoc';

export const swaggerSpec = swaggerJsdoc({
  definition: {
    openapi: '3.0.3',
    info: {
      title: 'AgriConnect API',
      version: '0.1.0',
      description: 'Backend API for the AgriConnect freshness-aware agricultural marketplace.',
    },
    servers: [{ url: '/api', description: 'Current server' }],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
        },
      },
      schemas: {
        SuccessResponse: {
          type: 'object',
          properties: {
            success: { type: 'boolean', example: true },
            data: { type: 'object' },
          },
        },
        ErrorResponse: {
          type: 'object',
          properties: {
            success: { type: 'boolean', example: false },
            error: {
              type: 'object',
              properties: {
                code: { type: 'string', example: 'VALIDATION_ERROR' },
                message: { type: 'string', example: 'Human-readable error message' },
              },
            },
          },
        },
      },
    },
  },
  // Both globs are listed since the deploy package only ships dist/ (source
  // comments survive compilation — removeComments isn't set in tsconfig).
  apis: ['./src/app.ts', './src/modules/**/*.routes.ts', './dist/app.js', './dist/modules/**/*.routes.js'],
});
