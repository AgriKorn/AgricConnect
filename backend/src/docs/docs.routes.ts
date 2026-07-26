import { Router } from 'express';
import swaggerUi from 'swagger-ui-express';
import { authenticate } from '../middleware/authenticate';
import { authorize } from '../middleware/authorize';
import { generateOpenAPIDocument } from './openapi.generator';

const docsRouter = Router();

// Middleware implementing hardened production exposure control
docsRouter.use((req, res, next) => {
  const isProduction = process.env.NODE_ENV === 'production';
  const isDocsEnabled = process.env.ENABLE_DOCS === 'true';

  if (isProduction) {
    if (!isDocsEnabled) {
      // In production without ENABLE_DOCS=true, return 404 to conceal route existence
      return res.status(404).json({
        success: false,
        error: {
          code: 'NOT_FOUND',
          message: `Cannot ${req.method} ${req.originalUrl}`,
        },
      });
    }

    // In production with ENABLE_DOCS=true, gate strictly behind admin auth
    return authenticate(req, res, () => {
      authorize('admin')(req, res, next);
    });
  }

  // In development/staging, allow open access for team iteration
  next();
});

// GET /api/docs/json - Raw OpenAPI 3.0 Spec JSON
docsRouter.get('/json', (_req, res) => {
  const spec = generateOpenAPIDocument();
  res.setHeader('Content-Type', 'application/json');
  res.send(spec);
});

// GET /api/docs - Interactive Swagger UI
const openapiDocument = generateOpenAPIDocument();
docsRouter.use('/', swaggerUi.serve, swaggerUi.setup(openapiDocument, {
  customSiteTitle: 'AgriConnect API Documentation (v1.0.0-stable)',
}));

export default docsRouter;
