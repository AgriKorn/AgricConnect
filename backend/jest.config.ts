import type { Config } from 'jest';

const config: Config = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/src'],
  testMatch: ['**/*.test.ts'],
  collectCoverageFrom: [
    'src/modules/auth/auth.service.ts',
    'src/modules/audit/audit.service.ts',
    'src/modules/dispatch/dispatch.service.ts',
    'src/modules/dispute/dispute.service.ts',
    'src/modules/listing/listing.service.ts',
    'src/modules/notification/notification.service.ts',
    'src/modules/transaction/transaction.service.ts',
  ],
  coverageThreshold: {
    global: {
      statements: 80,
      branches: 50,
      functions: 80,
      lines: 85,
    },
  },
};

export default config;
