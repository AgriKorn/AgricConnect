import { OpenApiGeneratorV3 } from '@asteasolutions/zod-to-openapi';
import { registry } from './openapi.registry';

// Import all module OpenAPI registrations to ensure they populate the registry
import '../modules/admin/admin.openapi';
import '../modules/auth/auth.openapi';
import '../modules/dispatch/dispatch.openapi';
import '../modules/dispute/dispute.openapi';
import '../modules/listing/listing.openapi';
import '../modules/notification/notification.openapi';
import '../modules/pricing/pricing.openapi';
import '../modules/transaction/transaction.openapi';

export const generateOpenAPIDocument = () => {
  const generator = new OpenApiGeneratorV3(registry.definitions);

  return generator.generateDocument({
    openapi: '3.0.0',
    info: {
      title: 'AgriConnect Backend API Specification',
      version: '1.0.0-stable',
      description: `
### AgriConnect REST API Documentation (v1.0.0-stable)
Production-grade RESTful web service API for the AgriConnect Flutter mobile application platform connecting agricultural produce farmers, buyers, logistics drivers, and platform administrators.

#### Authentication
Most endpoints require a **Bearer JWT Token** passed in the HTTP Authorization header:
\`\`\`http
Authorization: Bearer <your_access_token>
\`\`\`

#### Standard Response Format
All API responses follow a consistent machine-readable envelope shape:
* **Success**: \`{ "success": true, "data": ... }\`
* **Error**: \`{ "success": false, "error": { "code": "MACHINE_READABLE_CODE", "message": "Human readable message" } }\`
      `,
    },
    servers: [
      {
        url: 'http://localhost:3000',
        description: 'Local Development Server',
      },
      {
        url: 'https://api.agriconnect.com',
        description: 'AWS Production API Server',
      },
    ],
  });
};
