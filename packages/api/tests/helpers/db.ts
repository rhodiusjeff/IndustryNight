/**
 * Test Database Helpers
 *
 * Provides a test-specific database pool and cleanup utilities.
 * Every test file should call resetDb() in beforeEach to get a
 * clean slate — this TRUNCATEs all tables (fast, ~5ms) rather
 * than dropping/recreating schema.
 *
 * Usage in a test file:
 *   import { getTestPool, resetDb, closeTestPool } from './helpers/db';
 *
 *   beforeEach(() => resetDb());
 *   afterAll(() => closeTestPool());
 */
import { Pool } from 'pg';
import * as fs from 'fs';
import * as path from 'path';

let pool: Pool | null = null;

/** Get or create the test database pool */
export function getTestPool(): Pool {
  if (pool) return pool;

  const configPath = path.join(__dirname, '..', '.test-db-config.json');
  const config = JSON.parse(fs.readFileSync(configPath, 'utf-8'));

  pool = new Pool({
    connectionString: config.connectionString,
    max: 5,
  });

  return pool;
}

/** Load test DB config (connection details) */
export function getTestDbConfig() {
  const configPath = path.join(__dirname, '..', '.test-db-config.json');
  return JSON.parse(fs.readFileSync(configPath, 'utf-8'));
}

/**
 * TRUNCATE all application tables. Fast (~5ms) and resets
 * sequences (auto-increment counters). Run in beforeEach
 * so every test starts with an empty database.
 *
 * Table order respects FK constraints via CASCADE.
 */
export async function resetDb(): Promise<void> {
  const p = getTestPool();

  // TRUNCATE with CASCADE handles FK ordering for us
  await p.query(`
    TRUNCATE TABLE
      post_likes,
      post_comments,
      event_vendors,
      data_export_requests,
      audit_log,
      analytics_influence,
      analytics_events,
      analytics_users_daily,
      analytics_connections_daily,
      posh_orders,
      discounts,
      event_images,
      event_sponsors,
      tickets,
      connections,
      posts,
      events,
      sponsors,
      vendors,
      venues,
      verification_codes,
      specialties,
      admin_users,
      users
    CASCADE
  `);
}

/** Close the test pool. Call in afterAll. */
export async function closeTestPool(): Promise<void> {
  if (pool) {
    await pool.end();
    pool = null;
  }
}
