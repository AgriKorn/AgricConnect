import type { Config } from 'jest';

const config: Config = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/src'],
  testMatch: ['**/*.test.ts'],
  setupFiles: ['<rootDir>/jest.setup.ts'],
  collectCoverageFrom: [
    'src/modules/admin/admin.service.ts',
    'src/modules/auth/auth.service.ts',
    'src/modules/audit/audit.service.ts',
    'src/modules/dispatch/dispatch.service.ts',
    'src/modules/dispute/dispute.service.ts',
    'src/modules/listing/listing.service.ts',
    'src/modules/marketplace/marketplace.service.ts',
    'src/modules/notification/notification.service.ts',
    'src/modules/pricing/freshnessDecay.ts',
    'src/modules/pricing/pricing.service.ts',
    'src/modules/transaction/transaction.service.ts',
    'src/modules/outbox/outbox.service.ts',
    'src/modules/user/user.service.ts',
    'src/services/payment.service.ts',
    'src/workers/outbox.worker.ts',
  ],
  coverageThreshold: {
    global: {
      statements: 85,
      branches: 60,
      functions: 85,
      lines: 90,
    },
  },
};

export default config;
