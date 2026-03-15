/**
 * Jest Global Setup
 *
 * Runs ONCE before any test suite. Starts a PostgreSQL container via
 * testcontainers and applies the baseline migration. Stores the
 * connection string in an environment variable so test helpers can
 * connect to it.
 *
 * Why testcontainers instead of mocking?
 *   - Tests run against real PostgreSQL: enums, triggers, indexes,
 *     CASCADE deletes, and uuid-ossp all behave exactly like production.
 *   - Container starts in ~3-5 seconds and is fully ephemeral.
 */
import { PostgreSqlContainer } from '@testcontainers/postgresql';
import { Client } from 'pg';
import * as fs from 'fs';
import * as path from 'path';

export default async function setup() {
  console.log('\n🐘 Starting PostgreSQL test container...');

  const container = await new PostgreSqlContainer('postgres:16')
    .withDatabase('industrynight_test')
    .withUsername('test')
    .withPassword('test')
    .start();

  const connectionString = container.getConnectionUri();

  // Store container ID so teardown can stop it
  process.env.TEST_PG_CONTAINER_ID = container.getId();
  // Store connection details for the app's database module
  process.env.DATABASE_URL = connectionString;

  // Write connection info to a temp file that test workers can read
  // (globalSetup runs in a separate context from test workers)
  const configPath = path.join(__dirname, '.test-db-config.json');
  fs.writeFileSync(configPath, JSON.stringify({
    containerId: container.getId(),
    connectionString,
    host: container.getHost(),
    port: container.getMappedPort(5432),
    database: 'industrynight_test',
    user: 'test',
    password: 'test',
  }));

  // Apply the baseline migration
  console.log('📦 Applying baseline migration...');

  const client = new Client({ connectionString });
  await client.connect();

  const migrationPath = path.resolve(
    __dirname, '..', '..', 'database', 'migrations', '001_baseline_schema.sql'
  );
  const migrationSql = fs.readFileSync(migrationPath, 'utf-8');
  await client.query(migrationSql);

  await client.end();

  console.log('✅ Test database ready\n');
}
