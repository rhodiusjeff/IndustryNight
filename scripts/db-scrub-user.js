#!/usr/bin/env node
/**
 * db-scrub-user.js — Delete specific users and all associated data by phone number
 *
 * WHAT THIS DOES:
 *   1. Looks up each phone number in the users table
 *   2. Shows a preview of the user and related record counts
 *   3. Deletes verification_codes, then the user row (CASCADE handles the rest)
 *
 * CASCADE deletes: tickets, connections, posts, post_comments, post_likes,
 *   data_export_requests, analytics_influence
 * SET NULL: audit_log.actor_id (audit trail preserved, actor removed)
 *
 * USAGE:
 *   node scripts/db-scrub-user.js +15555550199
 *   node scripts/db-scrub-user.js +15555550199 +15555550200
 *   node scripts/db-scrub-user.js --yes +15555550199
 *   node scripts/db-scrub-user.js --skip-k8s +15555550199
 *
 * PREREQUISITES:
 *   - DB_PASSWORD environment variable set
 *   - kubectl port-forward to db-proxy active (or use without --skip-k8s)
 */

const path = require('path');
const { spawn } = require('child_process');
const net = require('net');

const { Pool } = require(require.resolve('pg', { paths: [path.resolve(__dirname, '../packages/api')] }));

// ---------------------------------------------------------------------------
// Parse arguments (before config so usage shows without DB_PASSWORD)
// ---------------------------------------------------------------------------
const rawArgs = process.argv.slice(2);
const phoneArgs = [];
let SKIP_K8S = false;
let AUTO_YES = false;
let TARGET_ENV = process.env.IN_ENV || 'dev';

for (let i = 0; i < rawArgs.length; i++) {
  const arg = rawArgs[i];
  if (arg === '--skip-k8s') {
    SKIP_K8S = true;
    continue;
  }
  if (arg === '--yes') {
    AUTO_YES = true;
    continue;
  }
  if (arg === '--env') {
    const envValue = rawArgs[i + 1];
    if (!envValue || envValue.startsWith('--')) {
      console.error('ERROR: --env requires a value: dev or prod');
      process.exit(1);
    }
    if (envValue !== 'dev' && envValue !== 'prod') {
      console.error(`ERROR: invalid --env value: ${envValue} (expected dev or prod)`);
      process.exit(1);
    }
    TARGET_ENV = envValue;
    i += 1;
    continue;
  }
  if (arg.startsWith('--')) {
    console.error(`ERROR: unknown flag: ${arg}`);
    process.exit(1);
  }
  phoneArgs.push(arg);
}

if (phoneArgs.length === 0) {
  console.error('Usage: node scripts/db-scrub-user.js [--yes] [--skip-k8s] [--env dev|prod] <phone> [<phone> ...]');
  console.error('');
  console.error('Examples:');
  console.error('  node scripts/db-scrub-user.js +15555550199');
  console.error('  node scripts/db-scrub-user.js --yes +15555550199 +15555550200');
  console.error('  node scripts/db-scrub-user.js --env dev --yes +15555550199');
  process.exit(1);
}

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

const NAMESPACE = process.env.IN_NAMESPACE || (TARGET_ENV === 'prod' ? 'industrynight' : 'industrynight-dev');
const AWS_PROFILE = process.env.IN_AWS_PROFILE || process.env.AWS_PROFILE || 'industrynight-admin';

// Normalize phone numbers to E.164
function normalizePhone(phone) {
  const digits = phone.replace(/[^\d]/g, '');
  if (digits.length === 10) return `+1${digits}`;
  if (digits.length === 11 && digits.startsWith('1')) return `+${digits}`;
  if (phone.startsWith('+')) return phone;
  return `+${digits}`;
}

// ---------------------------------------------------------------------------
// Port-forward helpers (same as db-reset.js)
// ---------------------------------------------------------------------------
let portForwardProc = null;

function isPortOpen(port, host) {
  return new Promise(resolve => {
    const sock = net.connect(port, host);
    sock.once('connect', () => { sock.destroy(); resolve(true); });
    sock.once('error', () => { sock.destroy(); resolve(false); });
  });
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

async function startPortForward() {
  if (await isPortOpen(DB_CONFIG.port, DB_CONFIG.host)) {
    console.log('  Port-forward already open, using existing tunnel.');
    return;
  }

  console.log('  Starting kubectl port-forward to db-proxy...');
  portForwardProc = spawn('kubectl', [
    'port-forward', 'pod/db-proxy', `${DB_CONFIG.port}:5432`, '-n', NAMESPACE
  ], {
    stdio: 'ignore',
    env: { ...process.env, AWS_PROFILE },
  });
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
  const phones = phoneArgs.map(normalizePhone);

  console.log('=== Industry Night: Scrub Users ===');
  console.log(`Environment: ${TARGET_ENV} (namespace: ${NAMESPACE})`);
  console.log(`Database:    ${DB_CONFIG.host}:${DB_CONFIG.port}/${DB_CONFIG.database}`);
  console.log(`Phones:   ${phones.join(', ')}`);
  console.log('');

  // Set up port-forward if needed
  if (!SKIP_K8S) {
    await startPortForward();
    console.log('  Waiting for port-forward to be ready...');
    await waitForPort(DB_CONFIG.port, DB_CONFIG.host, 15000);
    console.log('  Port-forward ready.');
    console.log('');
  }

  const pool = new Pool(DB_CONFIG);

  try {
    // Verify connection
    const { rows: dbCheck } = await pool.query('SELECT current_database() as db');
    console.log(`Connected to: ${dbCheck[0].db}\n`);

    // ---- Step 1: Lookup users ----
    const usersToDelete = [];

    for (const phone of phones) {
      const { rows } = await pool.query(
        'SELECT id, phone, name, email, role, created_at FROM users WHERE phone = $1',
        [phone]
      );

      if (rows.length === 0) {
        console.log(`  NOT FOUND: ${phone} — skipping`);
        continue;
      }

      const user = rows[0];

      // Count related records
      const counts = {};
      const countQueries = [
        ['tickets', 'SELECT COUNT(*)::int as n FROM tickets WHERE user_id = $1'],
        ['connections', 'SELECT COUNT(*)::int as n FROM connections WHERE user_a_id = $1 OR user_b_id = $1'],
        ['posts', 'SELECT COUNT(*)::int as n FROM posts WHERE author_id = $1'],
        ['comments', 'SELECT COUNT(*)::int as n FROM post_comments WHERE author_id = $1'],
        ['likes', 'SELECT COUNT(*)::int as n FROM post_likes WHERE user_id = $1'],
        ['audit_log entries', 'SELECT COUNT(*)::int as n FROM audit_log WHERE actor_id = $1'],
      ];

      for (const [label, sql] of countQueries) {
        const result = await pool.query(sql, [user.id]);
        counts[label] = result.rows[0].n;
      }

      // Check for pending verification codes
      const vcResult = await pool.query(
        'SELECT COUNT(*)::int as n FROM verification_codes WHERE phone = $1',
        [phone]
      );
      counts['verification_codes'] = vcResult.rows[0].n;

      // Display preview
      const created = user.created_at.toISOString().split('T')[0];
      console.log(`  ${user.phone} (id: ${user.id.substring(0, 8)}…, name: ${user.name || 'null'}, role: ${user.role}, created: ${created})`);
      for (const [label, count] of Object.entries(counts)) {
        if (label === 'audit_log entries') {
          console.log(`    ${label.padEnd(20)} ${count} (will SET NULL, not delete)`);
        } else {
          console.log(`    ${label.padEnd(20)} ${count}`);
        }
      }
      console.log('');

      usersToDelete.push({ user, phone, counts });
    }

    if (usersToDelete.length === 0) {
      console.log('\nNo users found to delete.');
      return;
    }

    // ---- Step 2: Confirm ----
    if (!AUTO_YES) {
      const readline = require('readline');
      const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
      const answer = await new Promise(resolve => {
        rl.question(`Delete ${usersToDelete.length} user(s) and all associated data? Type "yes" to confirm: `, resolve);
      });
      rl.close();
      if (answer !== 'yes') {
        console.log('Aborted.');
        return;
      }
      console.log('');
    }

    // ---- Step 3: Delete in a transaction ----
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      for (const { user, phone } of usersToDelete) {
        // Delete verification codes for this phone
        const vcDel = await client.query('DELETE FROM verification_codes WHERE phone = $1', [phone]);
        // Delete user (CASCADE handles everything else)
        const userDel = await client.query('DELETE FROM users WHERE id = $1', [user.id]);

        console.log(`  Deleted: ${phone} (${vcDel.rowCount} verification code(s), user + cascaded data)`);
      }

      await client.query('COMMIT');
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }

    // ---- Step 4: Verify ----
    console.log('\nVerification:');
    for (const { phone } of usersToDelete) {
      const check = await pool.query('SELECT COUNT(*)::int as n FROM users WHERE phone = $1', [phone]);
      const status = check.rows[0].n === 0 ? 'CONFIRMED DELETED' : 'STILL EXISTS (!)';
      console.log(`  ${phone}: ${status}`);
    }

    console.log('\n=== Scrub complete ===');
  } finally {
    await pool.end();
    stopPortForward();
  }
}

main().catch(err => {
  console.error('\n!!! Scrub FAILED:', err.message);
  process.exit(1);
});
