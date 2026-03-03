#!/usr/bin/env node
/**
 * db-unconnect.js — Delete connections for development/testing
 *
 * WHAT THIS DOES:
 *   - One phone:  Deletes ALL connections for that user
 *   - Two phones: Deletes only the connection between those two users
 *
 * USAGE:
 *   node scripts/db-unconnect.js +15555550199                        # all connections
 *   node scripts/db-unconnect.js +15555550199 +15555550200           # between two users
 *   node scripts/db-unconnect.js --skip-k8s +15555550199
 *
 * PREREQUISITES:
 *   - DB_PASSWORD environment variable set
 *   - kubectl port-forward to db-proxy active (or use without --skip-k8s)
 */

const path = require('path');
const { execSync, spawn } = require('child_process');
const net = require('net');

const { Pool } = require(require.resolve('pg', { paths: [path.resolve(__dirname, '../packages/api')] }));

// ---------------------------------------------------------------------------
// Parse arguments
// ---------------------------------------------------------------------------
const rawArgs = process.argv.slice(2);
const flags = rawArgs.filter(a => a.startsWith('--'));
const phoneArgs = rawArgs.filter(a => !a.startsWith('--'));

const SKIP_K8S = flags.includes('--skip-k8s');

if (phoneArgs.length === 0 || phoneArgs.length > 2) {
  console.error('Usage: node scripts/db-unconnect.js [--skip-k8s] <phone> [<phone2>]');
  console.error('');
  console.error('Examples:');
  console.error('  node scripts/db-unconnect.js +15555550199              # delete all connections for user');
  console.error('  node scripts/db-unconnect.js +15555550199 +15555550200 # delete connection between two users');
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

const NAMESPACE = process.env.IN_NAMESPACE || 'industrynight';

function normalizePhone(phone) {
  const digits = phone.replace(/[^\d]/g, '');
  if (digits.length === 10) return `+1${digits}`;
  if (digits.length === 11 && digits.startsWith('1')) return `+${digits}`;
  if (phone.startsWith('+')) return phone;
  return `+${digits}`;
}

// ---------------------------------------------------------------------------
// Port-forward helpers
// ---------------------------------------------------------------------------
let portForwardProc = null;

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

function startPortForward() {
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
  const phones = phoneArgs.map(normalizePhone);

  console.log('=== Industry Night: Unconnect ===');
  console.log(`Database: ${DB_CONFIG.host}:${DB_CONFIG.port}/${DB_CONFIG.database}`);
  console.log(`Phone(s): ${phones.join(', ')}`);
  console.log(`Mode: ${phones.length === 1 ? 'Delete ALL connections for user' : 'Delete connection between two users'}`);
  console.log('');

  // Set up port-forward if needed
  if (!SKIP_K8S) {
    startPortForward();
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

    // Look up users
    const users = [];
    for (const phone of phones) {
      const { rows } = await pool.query(
        'SELECT id, name, phone FROM users WHERE phone = $1',
        [phone]
      );
      if (rows.length === 0) {
        console.log(`  NOT FOUND: ${phone}`);
        console.log('\nCannot proceed — user not found.');
        return;
      }
      console.log(`  Found: ${rows[0].phone} (${rows[0].name || 'no name'}, id: ${rows[0].id.substring(0, 8)}…)`);
      users.push(rows[0]);
    }
    console.log('');

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      let result;

      if (users.length === 1) {
        // Delete ALL connections for this user
        const userId = users[0].id;

        // Show what will be deleted
        const { rows: connections } = await client.query(
          `SELECT c.id, c.created_at,
                  CASE WHEN c.user_a_id = $1 THEN ub.name ELSE ua.name END AS other_name,
                  CASE WHEN c.user_a_id = $1 THEN ub.phone ELSE ua.phone END AS other_phone
           FROM connections c
           JOIN users ua ON ua.id = c.user_a_id
           JOIN users ub ON ub.id = c.user_b_id
           WHERE c.user_a_id = $1 OR c.user_b_id = $1`,
          [userId]
        );

        if (connections.length === 0) {
          console.log('No connections found for this user.');
          await client.query('ROLLBACK');
          return;
        }

        console.log(`Deleting ${connections.length} connection(s):`);
        for (const c of connections) {
          console.log(`  - ${c.other_name || 'unknown'} (${c.other_phone}) — ${c.created_at.toISOString().split('T')[0]}`);
        }

        result = await client.query(
          'DELETE FROM connections WHERE user_a_id = $1 OR user_b_id = $1',
          [userId]
        );
      } else {
        // Delete connection between two specific users
        const [userA, userB] = users;

        // Connections use canonical ordering (LEAST/GREATEST)
        const ids = [userA.id, userB.id].sort();

        const { rows: connections } = await client.query(
          'SELECT id, created_at FROM connections WHERE user_a_id = $1 AND user_b_id = $2',
          ids
        );

        if (connections.length === 0) {
          console.log(`No connection found between ${userA.phone} and ${userB.phone}.`);
          await client.query('ROLLBACK');
          return;
        }

        console.log(`Deleting connection between ${userA.name || userA.phone} and ${userB.name || userB.phone}`);
        console.log(`  Created: ${connections[0].created_at.toISOString().split('T')[0]}`);

        result = await client.query(
          'DELETE FROM connections WHERE user_a_id = $1 AND user_b_id = $2',
          ids
        );
      }

      await client.query('COMMIT');

      console.log(`\nDeleted ${result.rowCount} connection(s).`);
      console.log('\n=== Unconnect complete ===');
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  } finally {
    await pool.end();
    stopPortForward();
  }
}

main().catch(err => {
  console.error('\n!!! Unconnect FAILED:', err.message);
  process.exit(1);
});
