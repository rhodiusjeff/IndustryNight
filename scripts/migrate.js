#!/usr/bin/env node
/**
 * migrate.js — Apply pending database migrations
 *
 * Tracks applied migrations in a _migrations table so it is safe to run
 * multiple times — already-applied migrations are skipped.
 *
 * WHAT THIS DOES:
 *   1. Creates _migrations tracking table if it doesn't exist
 *   2. Reads all *.sql files from packages/database/migrations/ in filename order
 *   3. Skips any already recorded in _migrations
 *   4. Applies each pending migration in a transaction
 *   5. Records it in _migrations on success
 *
 * DATA PRESERVATION:
 *   Each migration SQL file is responsible for its own data preservation.
 *   As of 004_event_enhancements.sql this includes:
 *     - Backfilling venue_name/venue_address from the venues table
 *     - Moving image_url rows into event_images before dropping the column
 *
 * PREREQUISITES:
 *   - kubectl port-forward active (or --skip-k8s flag):
 *       ./scripts/pf-db.sh start
 *   - DB_PASSWORD env var set
 *
 * USAGE:
 *   DB_PASSWORD=xxx node scripts/migrate.js              # Auto port-forward + migrate
 *   DB_PASSWORD=xxx node scripts/migrate.js --skip-k8s  # Port-forward already open
 *   DB_PASSWORD=xxx node scripts/migrate.js --dry-run   # Show pending, don't apply
 *   DB_PASSWORD=xxx node scripts/migrate.js --status    # Show applied/pending table
 */

'use strict';

const fs    = require('fs');
const path  = require('path');
const net   = require('net');
const { execSync, spawn } = require('child_process');

// Resolve pg from the api package (no root-level node_modules)
const { Pool } = require(
  require.resolve('pg', { paths: [path.resolve(__dirname, '../packages/api')] })
);

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

if (!process.env.DB_PASSWORD) {
  console.error('ERROR: DB_PASSWORD environment variable is required.');
  console.error('  export DB_PASSWORD=<password>');
  process.exit(1);
}

const DB_CONFIG = {
  host:     process.env.DB_HOST     || 'localhost',
  port:     parseInt(process.env.DB_PORT || '5432'),
  database: process.env.DB_NAME     || 'industrynight',
  user:     process.env.DB_USER     || 'industrynight',
  password: process.env.DB_PASSWORD,
  ssl: { rejectUnauthorized: false },
};

const NAMESPACE      = process.env.IN_NAMESPACE   || 'industrynight';
const AWS_PROFILE    = process.env.IN_AWS_PROFILE || 'industrynight-admin';
const MIGRATIONS_DIR = path.resolve(__dirname, '../packages/database/migrations');

const args     = process.argv.slice(2);
const SKIP_K8S = args.includes('--skip-k8s');
const DRY_RUN  = args.includes('--dry-run');
const STATUS   = args.includes('--status');

// ---------------------------------------------------------------------------
// Port-forward helpers (same pattern as db-reset.js)
// ---------------------------------------------------------------------------

function isPortOpen(port) {
  return new Promise(resolve => {
    const s = net.createConnection(port, '127.0.0.1');
    s.on('connect', () => { s.destroy(); resolve(true); });
    s.on('error',   () => resolve(false));
  });
}

async function waitForPort(port, maxSeconds = 15) {
  for (let i = 0; i < maxSeconds; i++) {
    if (await isPortOpen(port)) return;
    await new Promise(r => setTimeout(r, 1000));
  }
  throw new Error(`Port ${port} did not open within ${maxSeconds}s`);
}

let pfProcess = null;

async function startPortForward() {
  if (await isPortOpen(DB_CONFIG.port)) {
    console.log('  Port-forward already open, using existing tunnel.');
    return;
  }

  console.log('  Starting kubectl port-forward...');
  pfProcess = spawn(
    'kubectl', ['port-forward', 'pod/db-proxy', `${DB_CONFIG.port}:5432`, '-n', NAMESPACE],
    { env: { ...process.env, AWS_PROFILE }, stdio: 'ignore' }
  );
  pfProcess.on('error', err => { throw new Error(`kubectl failed: ${err.message}`); });

  await waitForPort(DB_CONFIG.port);
  console.log('  Tunnel ready.\n');
}

function stopPortForward() {
  if (pfProcess) {
    pfProcess.kill();
    pfProcess = null;
  }
}

// ---------------------------------------------------------------------------
// Migration runner
// ---------------------------------------------------------------------------

function getMigrationFiles() {
  return fs.readdirSync(MIGRATIONS_DIR)
    .filter(f => f.endsWith('.sql'))
    .sort(); // lexicographic = 001, 002, 003, 004 ...
}

async function ensureMigrationsTable(client) {
  // Schema matches db-reset.js so both tools share the same tracking table
  await client.query(`
    CREATE TABLE IF NOT EXISTS _migrations (
      id         SERIAL PRIMARY KEY,
      name       VARCHAR(255) NOT NULL UNIQUE,
      applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    )
  `);
}

async function getAppliedMigrations(client) {
  const result = await client.query(
    'SELECT name FROM _migrations ORDER BY name'
  );
  return new Set(result.rows.map(r => r.name));
}

async function applyMigration(client, filename, sql) {
  console.log(`  Applying ${filename}...`);
  try {
    await client.query('BEGIN');
    await client.query(sql);
    await client.query(
      'INSERT INTO _migrations (name) VALUES ($1) ON CONFLICT DO NOTHING',
      [filename]
    );
    await client.query('COMMIT');
    console.log(`  ✓ ${filename}`);
  } catch (err) {
    await client.query('ROLLBACK');
    throw new Error(`Migration ${filename} failed: ${err.message}`);
  }
}

async function printStatus(client) {
  const applied = await getAppliedMigrations(client);
  const files   = getMigrationFiles();

  const pending = files.filter(f => !applied.has(f));

  console.log('\nMigration Status');
  console.log('─'.repeat(55));
  for (const f of files) {
    const state = applied.has(f) ? '✓ applied' : '○ pending';
    console.log(`  ${state}  ${f}`);
  }
  console.log('─'.repeat(55));
  console.log(`  ${applied.size} applied, ${pending.length} pending\n`);
  return;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  if (!SKIP_K8S) {
    console.log('[1/3] Checking DB tunnel...');
    await startPortForward();
  } else {
    console.log('[1/3] Skipping port-forward (--skip-k8s)\n');
  }

  const pool   = new Pool(DB_CONFIG);
  const client = await pool.connect();

  try {
    console.log('[2/3] Checking migration state...');
    await ensureMigrationsTable(client);

    if (STATUS) {
      await printStatus(client);
      return;
    }

    const applied  = await getAppliedMigrations(client);
    const allFiles = getMigrationFiles();
    const pending  = allFiles.filter(f => !applied.has(f));

    if (pending.length === 0) {
      console.log('  All migrations already applied.\n');
      return;
    }

    console.log(`  ${applied.size} applied, ${pending.length} pending:\n`);
    for (const f of pending) {
      console.log(`    ○ ${f}`);
    }
    console.log('');

    if (DRY_RUN) {
      console.log('[3/3] Dry run — no changes made.\n');
      return;
    }

    console.log('[3/3] Applying pending migrations...');
    for (const filename of pending) {
      const sql = fs.readFileSync(path.join(MIGRATIONS_DIR, filename), 'utf8');
      await applyMigration(client, filename, sql);
    }

    console.log(`\n  Done. ${pending.length} migration${pending.length === 1 ? '' : 's'} applied.\n`);

  } finally {
    client.release();
    await pool.end();
    stopPortForward();
  }
}

main().catch(err => {
  console.error('\nERROR:', err.message);
  stopPortForward();
  process.exit(1);
});
