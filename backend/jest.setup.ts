/**
 * Deterministic environment for the Jest test runner.
 *
 * Registered via `setupFiles`, so it runs before any application module is
 * imported. This guarantees the same secrets/config are present whether or not
 * a developer has a local `.env` file, so JWTs signed inside tests and verified
 * by the app middleware always use an identical secret. Without this, a missing
 * `.env` causes the test-signing fallback and the app's config fallback to
 * diverge, producing spurious 401s.
 *
 * Values are only set when absent, so CI-injected secrets always win.
 */
process.env.NODE_ENV = process.env.NODE_ENV || 'test';
process.env.JWT_SECRET =
  process.env.JWT_SECRET || 'test_jwt_secret_min_16_characters_long';
process.env.JWT_REFRESH_SECRET =
  process.env.JWT_REFRESH_SECRET || 'test_refresh_secret_min_32_characters_long';
process.env.DATABASE_URL =
  process.env.DATABASE_URL ||
  'postgresql://postgres:postgres@localhost:5432/agriconnect_test';

// DIRECT_URL must be pinned too, and it matters more than DATABASE_URL:
// config/db.ts resolves its connection as
//   process.env.DIRECT_URL || process.env.DATABASE_URL || env.DATABASE_URL
// so DIRECT_URL wins. Leaving it unset let dotenv.config() populate it from the
// developer's .env when config/env.ts loaded, which pointed the Prisma client in
// tests at the real development database. Suites are expected to mock Prisma, so
// this is a backstop: if one ever does reach for a live connection, it must not
// be able to find the dev data.
process.env.DIRECT_URL =
  process.env.DIRECT_URL ||
  'postgresql://postgres:postgres@localhost:5432/agriconnect_test';
