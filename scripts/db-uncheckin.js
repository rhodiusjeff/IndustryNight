#!/usr/bin/env node
/**
 * db-uncheckin.js — Reset check-in status for development/testing
 *
 * WHAT THIS DOES:
 *   1. Finds the user by phone number (or all users with --all)
 *   2. Sets their ticket status back to 'purchased' and clears checked_in_at
 *   3. Decrements attendee_count on affected events
 *
 * USAGE:
 *   node scripts/db-uncheckin.js +15555550199
 *   node scripts/db-uncheckin.js +15555550199 --event <event-id>
 *   node scripts/db-uncheckin.js --all
 *   node scripts/db-uncheckin.js --skip-k8s +15555550199
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
const positionalArgs = rawArgs.filter(a => !a.startsWith('--'));

const SKIP_K8S = flags.includes('--skip-k8s');
const ALL_USERS = flags.includes('--all');

// Parse --event <id>
let EVENT_ID = null;
const eventFlagIdx = rawArgs.indexOf('--event');
if (eventFlagIdx !== -1 && rawArgs[eventFlagIdx + 1]) {
  EVENT_ID = rawArgs[eventFlagIdx + 1];
}

const phoneArgs = positionalArgs.filter(a => a !== EVENT_ID);

if (!ALL_USERS && phoneArgs.length === 0) {
  console.error('Usage: node scripts/db-uncheckin.js [--skip-k8s] [--event <event-id>] <phone>');
  console.error('       node scripts/db-uncheckin.js [--skip-k8s] --all');
  console.error('');
  console.error('Examples:');
  console.error('  node scripts/db-uncheckin.js +15555550199');
  console.error('  node scripts/db-uncheckin.js +15555550199 --event abc-123');
  console.error('  node scripts/db-uncheckin.js --all');
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

const NAMESPACE = 'industrynight';

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
  console.log('=== Industry Night: Uncheckin ===');
  console.log(`Database: ${DB_CONFIG.host}:${DB_CONFIG.port}/${DB_CONFIG.database}`);

  if (ALL_USERS) {
    console.log('Mode: ALL users');
  } else {
    console.log(`Phone(s): ${phoneArgs.map(normalizePhone).join(', ')}`);
  }
  if (EVENT_ID) {
    console.log(`Event: ${EVENT_ID}`);
  }
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

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      let whereClause;
      let params;

      if (ALL_USERS) {
        if (EVENT_ID) {
          whereClause = "WHERE status = 'checkedIn' AND event_id = $1";
          params = [EVENT_ID];
        } else {
          whereClause = "WHERE status = 'checkedIn'";
          params = [];
        }
      } else {
        // Look up user IDs from phone numbers
        const phones = phoneArgs.map(normalizePhone);
        const userIds = [];

        for (const phone of phones) {
          const { rows } = await client.query(
            'SELECT id, name, phone FROM users WHERE phone = $1',
            [phone]
          );
          if (rows.length === 0) {
            console.log(`  NOT FOUND: ${phone} — skipping`);
            continue;
          }
          console.log(`  Found: ${rows[0].phone} (${rows[0].name || 'no name'}, id: ${rows[0].id.substring(0, 8)}…)`);
          userIds.push(rows[0].id);
        }

        if (userIds.length === 0) {
          console.log('\nNo users found.');
          await client.query('ROLLBACK');
          return;
        }

        const placeholders = userIds.map((_, i) => `$${i + 1}`).join(', ');
        if (EVENT_ID) {
          whereClause = `WHERE status = 'checkedIn' AND user_id IN (${placeholders}) AND event_id = $${userIds.length + 1}`;
          params = [...userIds, EVENT_ID];
        } else {
          whereClause = `WHERE status = 'checkedIn' AND user_id IN (${placeholders})`;
          params = userIds;
        }
      }

      // Qualify status with t. for the JOIN query (events also has a status column)
      const joinWhereClause = whereClause.replace(/\bstatus\b/g, 't.status');

      // Find affected tickets before updating
      const { rows: affectedTickets } = await client.query(
        `SELECT t.id, t.event_id, e.name as event_name
         FROM tickets t
         JOIN events e ON e.id = t.event_id
         ${joinWhereClause}`,
        params
      );

      if (affectedTickets.length === 0) {
        console.log('\nNo checked-in tickets found to reset.');
        await client.query('ROLLBACK');
        return;
      }

      console.log(`\nResetting ${affectedTickets.length} checked-in ticket(s):`);
      for (const t of affectedTickets) {
        console.log(`  - ${t.event_name} (ticket: ${t.id.substring(0, 8)}…)`);
      }

      // Reset tickets to purchased (no alias needed — single table UPDATE)
      const { rowCount } = await client.query(
        `UPDATE tickets SET status = 'purchased', checked_in_at = NULL ${whereClause}`,
        params
      );

      // Decrement attendee_count for each affected event
      const eventIds = [...new Set(affectedTickets.map(t => t.event_id))];
      for (const eventId of eventIds) {
        const ticketsForEvent = affectedTickets.filter(t => t.event_id === eventId).length;
        await client.query(
          'UPDATE events SET attendee_count = GREATEST(attendee_count - $1, 0) WHERE id = $2',
          [ticketsForEvent, eventId]
        );
      }

      await client.query('COMMIT');

      console.log(`\nReset ${rowCount} ticket(s) to 'purchased'.`);
      console.log('Decremented attendee_count for affected events.');
      console.log('\n=== Uncheckin complete ===');
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
  console.error('\n!!! Uncheckin FAILED:', err.message);
  process.exit(1);
});
