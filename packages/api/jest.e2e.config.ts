/**
 * Jest config for E2E tests against deployed API.
 *
 * Key differences from jest.config.ts (local tests):
 *   - No globalSetup/teardown (no testcontainer needed)
 *   - testMatch points to tests/e2e/
 *   - runInBand: cleanup describe block must run last
 *   - Longer timeout: real HTTP calls over network
 *
 * Usage:
 *   API_BASE_URL=https://dev-api.industrynight.net npm run test:e2e
 */
import type { Config } from 'jest';

const config: Config = {
  preset: 'ts-jest',
  testEnvironment: 'node',

  roots: ['<rootDir>/tests/e2e'],
  testMatch: ['**/*.test.ts'],

  // No container setup — hits real API
  globalSetup: undefined,
  globalTeardown: undefined,

  // 30s timeout for real HTTP round-trips
  testTimeout: 30000,

  moduleFileExtensions: ['ts', 'js', 'json'],
  transformIgnorePatterns: ['/node_modules/'],
  forceExit: true,
  verbose: true,
};

export default config;
