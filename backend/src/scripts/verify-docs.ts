import app from '../app';
import { generateOpenAPIDocument } from '../docs/openapi.generator';

async function runDocsVerification() {
  console.log('🧪 Starting OpenAPI & Swagger Documentation Verification Suite...\n');

  // 1. Spec Generation Check
  const spec = generateOpenAPIDocument();
  console.log(`✅ Step 1: OpenAPI 3.0 Spec generated successfully.`);
  console.log(`   Title: ${spec.info.title}`);
  console.log(`   Version: ${spec.info.version}`);
  console.log(`   Total Endpoints Registered: ${Object.keys(spec.paths).length}`);

  if (spec.info.version !== '1.0.0-stable') {
    throw new Error(`❌ Expected spec version 1.0.0-stable, got ${spec.info.version}`);
  }

  // 2. Local Express Server Gating Test
  const server = app.listen(3099, async () => {
    try {
      console.log('\n🔒 Testing Security Exposure Control Policy...');

      // Test A: Development Mode (open access)
      process.env.NODE_ENV = 'development';
      const devRes = await fetch('http://localhost:3099/api/docs/json');
      console.log(`✅ Dev Mode (NODE_ENV=development): HTTP ${devRes.status} (Open Access)`);
      if (devRes.status !== 200) throw new Error('Expected HTTP 200 in dev mode');

      // Test B: Production Mode without ENABLE_DOCS (404 Not Found)
      process.env.NODE_ENV = 'production';
      delete process.env.ENABLE_DOCS;
      const prodDisabledRes = await fetch('http://localhost:3099/api/docs/json');
      console.log(`✅ Prod Mode (ENABLE_DOCS unset): HTTP ${prodDisabledRes.status} (Concealed 404)`);
      if (prodDisabledRes.status !== 404) throw new Error('Expected HTTP 404 in prod mode without ENABLE_DOCS');

      // Test C: Production Mode with ENABLE_DOCS=true (Unauthenticated -> 401 Unauthorized)
      process.env.NODE_ENV = 'production';
      process.env.ENABLE_DOCS = 'true';
      const prodUnauthRes = await fetch('http://localhost:3099/api/docs/json');
      console.log(`✅ Prod Mode (ENABLE_DOCS=true, Unauthenticated): HTTP ${prodUnauthRes.status} (Gated 401)`);
      if (prodUnauthRes.status !== 401) throw new Error('Expected HTTP 401 in prod mode for unauthenticated request');

      console.log('\n🎉 ALL OPENAPI & SWAGGER VERIFICATION CHECKS PASSED SUCCESSFULLY!');
    } catch (err) {
      console.error('❌ Verification Failed:', err);
      process.exitCode = 1;
    } finally {
      server.close();
    }
  });
}

runDocsVerification();
