import app from './app';
import { env } from './config/env';
import { prisma } from './config/db';
import logger from './utils/logger';
import { seedDevAdmin } from './modules/user/seedAdmin';

const PORT = env.PORT;

const box = (title: string, lines: string[]) =>
  ['', `  ${title}`, '', ...lines.map((l) => `  ${l}`), ''].join('\n');

/**
 * Fails fast with an explanation rather than a Prisma stack trace.
 *
 * Every service reads and writes Postgres, so an unreachable or unmigrated
 * database means nothing works. Previously the first query — inside
 * seedDevAdmin — rejected, and the process died printing an ECONNREFUSED
 * stack trace that never mentioned Postgres, migrations or the README.
 *
 * Connectivity and schema are checked separately because the fixes differ:
 * one needs the server started, the other needs migrations applied.
 */
const assertDatabaseReady = async (): Promise<void> => {
  try {
    await prisma.$queryRaw`SELECT 1`;
  } catch (err) {
    logger.error(
      box('Cannot reach the database.', [
        'The API needs PostgreSQL — every service reads and writes it.',
        '',
        'Check that:',
        '  1. PostgreSQL is running and accepting connections',
        '  2. DATABASE_URL and DIRECT_URL are set in backend/.env',
        '  3. Special characters in the password are percent-encoded',
        '     (an "@" must be written %40, or the host cannot be parsed)',
        '',
        'Setup instructions: backend/README.md',
      ]),
    );
    logger.error('Underlying error:', err);
    process.exit(1);
  }

  try {
    await prisma.user.findFirst({ select: { id: true } });
  } catch (err) {
    logger.error(
      box('Connected to the database, but the schema is missing.', [
        'The tables have not been created yet. From backend/:',
        '',
        '  npx prisma migrate dev',
        '',
        'Then seed the crop types and MOFA price benchmarks:',
        '',
        '  BOOTSTRAP_ADMIN_ENABLED=true \\',
        '    BOOTSTRAP_ADMIN_PHONE="+233200000001" \\',
        '    BOOTSTRAP_ADMIN_PASSWORD="<at least 12 chars>" \\',
        '    npx ts-node prisma/seed.ts',
        '',
        'Without BOOTSTRAP_ADMIN_ENABLED the seed skips every price row and',
        'pricing silently serves a flat GHS 10.00 fallback.',
      ]),
    );
    logger.error('Underlying error:', err);
    process.exit(1);
  }
};

const start = async () => {
  await assertDatabaseReady();

  if (env.NODE_ENV !== 'production') {
    await seedDevAdmin();
  }

  app.listen(PORT, () => {
    logger.info(`🚀 AgriConnect API running on port ${PORT}`);
    logger.info(`📋 Environment: ${env.NODE_ENV}`);
    logger.info(`💚 Health check: http://localhost:${PORT}/api/health`);
  });
};

start().catch((err) => {
  logger.error('Failed to start the API:', err);
  process.exit(1);
});
