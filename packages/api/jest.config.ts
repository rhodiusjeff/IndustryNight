import type { Config } from 'jest';

const config: Config = {
  // Use ts-jest to compile TypeScript on the fly
  preset: 'ts-jest',
  testEnvironment: 'node',

  // Test files live in tests/ directory
  roots: ['<rootDir>/tests'],
  testMatch: ['**/*.test.ts'],

  // Global setup/teardown — starts and stops the PostgreSQL container
  globalSetup: '<rootDir>/tests/setup.ts',
  globalTeardown: '<rootDir>/tests/teardown.ts',

  // Timeout: testcontainers PG startup can take ~10 seconds
  testTimeout: 30000,

  // Module resolution matches tsconfig
  moduleFileExtensions: ['ts', 'js', 'json'],

  // Don't transform node_modules
  transformIgnorePatterns: ['/node_modules/'],

  // Run test files sequentially — they share a single test database
  maxWorkers: 1,

  // Force exit after tests complete (pg pool keeps event loop alive)
  forceExit: true,

  // Verbose output so you can see each test name
  verbose: true,
};

export default config;
