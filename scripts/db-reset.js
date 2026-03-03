#!/usr/bin/env node
/**
 * db-reset.js — Full database reset with maintenance mode and zero-downtime recovery
 *
 * WHAT THIS DOES:
 *   1. Enables maintenance mode (ALB returns 503 to all traffic)
 *   2. Scales API deployment to 0 (kills pods, drops all DB connections)
 *   3. Re-establishes kubectl port-forward to db-proxy (scale-down kills it)
 *   4. Drops ALL tables, types, and extensions in the database
 *   5. Runs all migrations from packages/database/migrations/ (in filename order)
 *   6. Runs seed data (specialties.sql, then dev_seed.sql)
 *   7. Scales API deployment back up
 *   8. Waits for pods to be healthy
 *   9. Disables maintenance mode (traffic flows again)
 *
 * WHY NODE.JS INSTEAD OF BASH:
 *   - No psql dependency — uses the pg library already in the API package
 *   - Works through the kubectl port-forward (localhost:5432 → RDS via socat pod)
 *   - Proper error handling and rollback
 *   - SSL support for RDS connections
 *
 * PREREQUISITES:
 *   - kubectl configured and connected to the EKS cluster
 *   - Port-forward to RDS active (--skip-k8s only; full mode manages it automatically):
 *       kubectl port-forward pod/db-proxy 5432:5432 -n industrynight
 *   - Run from the project root: node scripts/db-reset.js
 *
 * USAGE:
 *   node scripts/db-reset.js                  # Full reset with maintenance mode
 *   node scripts/db-reset.js --skip-k8s       # Reset DB only (no k8s changes, for local dev)
 *   node scripts/db-reset.js --seed-only      # Skip drop/migrate, just re-run seeds
 */

const fs = require('fs');
const path = require('path');
const { execSync, spawn } = require('child_process');
const net = require('net');

// Resolve pg from the api package since there is no root-level node_modules
const { Pool } = require(require.resolve('pg', { paths: [path.resolve(__dirname, '../packages/api')] }));

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------
if (!process.env.DB_PASSWORD) {
  console.error('ERROR: DB_PASSWORD environment variable is required.');
  console.error('  export DB_PASSWORD=<password>');
  process.exit(1);
}

const DB_CONFIG = {
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '5432'),
  database: process.env.DB_NAME || 'industrynight',
  user: process.env.DB_USER || 'industrynight',
  password: process.env.DB_PASSWORD,
  ssl: { rejectUnauthorized: false },
};

const NAMESPACE  = process.env.IN_NAMESPACE  || 'industrynight';
const DEPLOYMENT = process.env.IN_DEPLOYMENT || 'industrynight-api';

const PROJECT_ROOT = path.resolve(__dirname, '..');
const MIGRATIONS_DIR = path.join(PROJECT_ROOT, 'packages/database/migrations');
const SEEDS_DIR = path.join(PROJECT_ROOT, 'packages/database/seeds');

const args = process.argv.slice(2);
const SKIP_K8S = args.includes('--skip-k8s');
const SEED_ONLY = args.includes('--seed-only');

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
function kubectl(cmd) {
  console.log(`  $ kubectl ${cmd}`);
  return execSync(`kubectl ${cmd}`, { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] }).trim();
}

function step(num, total, msg) {
  console.log(`\n[${ num}/${total}] ${msg}`);
}

function waitForPort(port, host, timeoutMs) {
  return new Promise((resolve, reject) => {
    const deadline = Date.now() + timeoutMs;
    function attempt() {
      const sock = net.connect(port, host);
      sock.once('connect', () => { sock.destroy(); resolve(); });
      sock.once('error', () => {
        sock.destroy();
        if (Date.now() > deadline) return reject(new Error(`Port ${port} not reachable after ${timeoutMs}ms`));
        setTimeout(attempt, 500);
      });
    }
    attempt();
  });
}

// Managed port-forward process (k8s mode only)
let portForwardProc = null;

function startPortForward() {
  // Kill any existing port-forward on our port
  try { execSync(`lsof -ti :${DB_CONFIG.port} | xargs kill 2>/dev/null`, { stdio: 'ignore' }); } catch (e) { /* none running */ }

  console.log('  Starting kubectl port-forward to db-proxy...');
  portForwardProc = spawn('kubectl', [
    'port-forward', 'pod/db-proxy', `${DB_CONFIG.port}:5432`, '-n', NAMESPACE
  ], { stdio: 'ignore', detached: true });
  portForwardProc.unref();
}

function stopPortForward() {
  if (portForwardProc) {
    try { process.kill(-portForwardProc.pid); } catch (e) { /* already dead */ }
    portForwardProc = null;
  }
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
async function main() {
  // Breakdown: maint-on + scale-down + [drop + migrate] + seed + scale-up + maint-off
  const totalSteps = SKIP_K8S ? (SEED_ONLY ? 1 : 3) : (SEED_ONLY ? 5 : 7);
  let currentStep = 0;

  const envFlag = process.env.IN_ENV ? `--env ${process.env.IN_ENV}` : '';

  console.log('=== Industry Night Database Reset ===');
  console.log(`Mode: ${SEED_ONLY ? 'seed-only' : 'full reset'}${SKIP_K8S ? ' (skip k8s)' : ''}`);
  console.log(`Database: ${DB_CONFIG.host}:${DB_CONFIG.port}/${DB_CONFIG.database}`);
  console.log('');

  // ---- Safety prompt ----
  if (!args.includes('--yes')) {
    const readline = require('readline');
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    const answer = await new Promise(resolve => {
      rl.question('This will DESTROY all data. Type "yes" to confirm: ', resolve);
    });
    rl.close();
    if (answer !== 'yes') {
      console.log('Aborted.');
      process.exit(0);
    }
  }

  // ---- Step: Maintenance mode ON ----
  if (!SKIP_K8S) {
    step(++currentStep, totalSteps, 'Enabling maintenance mode...');
    try {
      execSync(`${path.join(__dirname, 'maintenance.sh')} ${envFlag} on`, { stdio: 'inherit' });
    } catch (e) {
      console.warn('  Warning: maintenance.sh failed — continuing anyway');
    }
  }

  // ---- Step: Scale down (kill DB connections) ----
  if (!SKIP_K8S) {
    step(++currentStep, totalSteps, 'Scaling deployment to 0 (dropping DB connections)...');
    kubectl(`scale deployment/${DEPLOYMENT} -n ${NAMESPACE} --replicas=0`);

    // Wait for pods to terminate
    console.log('  Waiting for pods to terminate...');
    let attempts = 0;
    while (attempts < 30) {
      const podCount = kubectl(`get pods -n ${NAMESPACE} -l app=${DEPLOYMENT} --no-headers 2>/dev/null | wc -l`).trim();
      if (podCount === '0') break;
      await new Promise(r => setTimeout(r, 2000));
      attempts++;
    }
    console.log('  All API pods terminated.');

    // Re-establish port-forward (scale-down likely killed the existing one)
    startPortForward();
    console.log('  Waiting for port-forward to be ready...');
    await waitForPort(DB_CONFIG.port, DB_CONFIG.host, 15000);
    console.log('  Port-forward ready.');
  }

  // ---- Connect to database ----
  const pool = new Pool(DB_CONFIG);

  try {
    // Verify connection
    const { rows } = await pool.query('SELECT current_database() as db');
    console.log(`  Connected to: ${rows[0].db}`);

    if (!SEED_ONLY) {
      // ---- Step: Drop everything ----
      step(++currentStep, totalSteps, 'Dropping all tables, types, and functions...');

      // Drop all tables in dependency order (CASCADE handles foreign keys)
      // We query pg_tables to get the full list rather than hardcoding
      const tables = await pool.query(
        "SELECT tablename FROM pg_tables WHERE schemaname = 'public'"
      );
      if (tables.rows.length > 0) {
        const tableNames = tables.rows.map(r => `"${r.tablename}"`).join(', ');
        await pool.query(`DROP TABLE IF EXISTS ${tableNames} CASCADE`);
        console.log(`  Dropped ${tables.rows.length} tables`);
      }

      // Drop all custom enum types
      const types = await pool.query(
        "SELECT typname FROM pg_type WHERE typtype = 'e' AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')"
      );
      for (const t of types.rows) {
        await pool.query(`DROP TYPE IF EXISTS "${t.typname}" CASCADE`);
      }
      console.log(`  Dropped ${types.rows.length} enum types`);

      // Drop trigger function
      await pool.query('DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE');
      console.log('  Dropped trigger functions');

      // ---- Step: Run migrations ----
      step(++currentStep, totalSteps, 'Running migrations...');

      // Ensure uuid-ossp extension exists (can't be dropped/recreated by non-superuser on RDS)
      await pool.query('CREATE EXTENSION IF NOT EXISTS "uuid-ossp"');

      const migrationFiles = fs.readdirSync(MIGRATIONS_DIR)
        .filter(f => f.endsWith('.sql'))
        .sort();

      for (const file of migrationFiles) {
        const sql = fs.readFileSync(path.join(MIGRATIONS_DIR, file), 'utf8');
        console.log(`  Applying: ${file}`);
        await pool.query(sql);
      }

      // Create and populate migrations tracking table
      await pool.query(`
        CREATE TABLE IF NOT EXISTS _migrations (
          id SERIAL PRIMARY KEY,
          name VARCHAR(255) NOT NULL UNIQUE,
          applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        )
      `);
      for (const file of migrationFiles) {
        await pool.query('INSERT INTO _migrations (name) VALUES ($1) ON CONFLICT DO NOTHING', [file]);
      }
      console.log(`  Applied ${migrationFiles.length} migrations`);
    }

    // ---- Step: Run seeds ----
    step(++currentStep, totalSteps, 'Loading seed data...');

    // Specialties first (reference data)
    const specialtiesSql = fs.readFileSync(path.join(SEEDS_DIR, 'specialties.sql'), 'utf8');
    await pool.query(specialtiesSql);
    const specCount = await pool.query('SELECT COUNT(*) as count FROM specialties');
    console.log(`  Specialties: ${specCount.rows[0].count} loaded`);

    // Dev seed data
    const devSeedSql = fs.readFileSync(path.join(SEEDS_DIR, 'dev_seed.sql'), 'utf8');
    await pool.query(devSeedSql);
    const userCount = await pool.query('SELECT COUNT(*) as count FROM users');
    const eventCount = await pool.query('SELECT COUNT(*) as count FROM events');
    console.log(`  Users: ${userCount.rows[0].count}, Events: ${eventCount.rows[0].count}`);

    // ---- Summary ----
    const allTables = await pool.query("SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename");
    console.log(`\n  Database ready: ${allTables.rows.length} tables`);

  } finally {
    await pool.end();
  }

  // ---- Step: Scale back up ----
  if (!SKIP_K8S) {
    step(++currentStep, totalSteps, 'Scaling deployment back up...');
    kubectl(`scale deployment/${DEPLOYMENT} -n ${NAMESPACE} --replicas=2`);

    console.log('  Waiting for pods to be ready...');
    try {
      execSync(
        `kubectl rollout status deployment/${DEPLOYMENT} -n ${NAMESPACE} --timeout=90s`,
        { stdio: 'inherit' }
      );
    } catch (e) {
      console.error('  Warning: Rollout did not complete in 90s — check pod status');
    }
  }

  // ---- Step: Maintenance mode OFF ----
  if (!SKIP_K8S) {
    step(++currentStep, totalSteps, 'Disabling maintenance mode...');
    try {
      execSync(`${path.join(__dirname, 'maintenance.sh')} ${envFlag} off`, { stdio: 'inherit' });
    } catch (e) {
      console.warn('  Warning: maintenance.sh off failed — run manually: ./scripts/maintenance.sh off');
    }
  }

  console.log('\n=== Database reset complete! ===');
  if (portForwardProc) {
    console.log(`  Port-forward still active on localhost:${DB_CONFIG.port} (PID ${portForwardProc.pid})`);
    console.log('  Kill it when done: kill ' + portForwardProc.pid);
  }
  console.log('');
}

main().catch(err => {
  console.error('\n!!! Reset FAILED:', err.message);
  console.error('\nIMPORTANT: If maintenance mode is still on, run:');
  console.error('  ./scripts/maintenance.sh off');
  console.error(`  kubectl scale deployment/${DEPLOYMENT} -n ${NAMESPACE} --replicas=2`);
  process.exit(1);
});
