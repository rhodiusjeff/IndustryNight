#!/usr/bin/env node
/**
 * seed-smoke-admin.js — Create or delete the ephemeral smoke-test admin account
 *
 * Used by closeout-test.sh to provision a short-lived admin account before
 * phase-7 smoke checks and clean it up immediately after (success or failure).
 * The account is never left behind — it is deleted even if the smoke phase fails
 * because closeout-test.sh wires teardown into its EXIT trap.
 *
 * USAGE:
 *   node scripts/seed-smoke-admin.js --create --email <email> --password <pw> [--skip-k8s]
 *   node scripts/seed-smoke-admin.js --delete --email <email> [--skip-k8s]
 *
 * ENVIRONMENT:
 *   DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD, DB_SSL
 *   IN_NAMESPACE    (kubectl namespace; default: industrynight)
 *   IN_AWS_PROFILE  (kubectl env; default: industrynight-admin)
 */

'use strict';

const net  = require('net');
const path = require('path');
const { spawn } = require('child_process');

const { Pool } = require(
  require.resolve('pg', { paths: [path.resolve(__dirname, '../packages/api')] })
);
const bcrypt = require(
  require.resolve('bcryptjs', { paths: [path.resolve(__dirname, '../packages/api')] })
);

// --------------------------------------------------------------------------
// Arg parsing
// --------------------------------------------------------------------------

const args = process.argv.slice(2);

function getArg(name) {
  const idx = args.indexOf(`--${name}`);
  if (idx === -1 || idx + 1 >= args.length) return null;
  return args[idx + 1];
}

const ACTION   = args.includes('--create') ? 'create'
               : args.includes('--delete') ? 'delete'
               : null;
const EMAIL    = getArg('email');
const PASSWORD = getArg('password');
const SKIP_K8S = args.includes('--skip-k8s');

if (!ACTION || !EMAIL || (ACTION === 'create' && !PASSWORD)) {
  console.error('Usage:');
  console.error('  node scripts/seed-smoke-admin.js --create --email <email> --password <pw> [--skip-k8s]');
  console.error('  node scripts/seed-smoke-admin.js --delete --email <email> [--skip-k8s]');
  process.exit(1);
}

if (!process.env.DB_PASSWORD) {
  console.error('ERROR: DB_PASSWORD environment variable is required.');
  process.exit(1);
}

// --------------------------------------------------------------------------
// DB config
// --------------------------------------------------------------------------

const DB_PORT = parseInt(process.env.DB_PORT || '5432');

const DB_CONFIG = {
  host:     process.env.DB_HOST || 'localhost',
  port:     DB_PORT,
  database: process.env.DB_NAME || 'industrynight',
  user:     process.env.DB_USER || 'industrynight',
  password: process.env.DB_PASSWORD,
  ssl: (process.env.DB_SSL === 'false' || SKIP_K8S) ? false : { rejectUnauthorized: false },
};

const NAMESPACE   = process.env.IN_NAMESPACE   || 'industrynight';
const AWS_PROFILE = process.env.IN_AWS_PROFILE || 'industrynight-admin';

// --------------------------------------------------------------------------
// Port-forward helpers (same pattern as migrate.js)
// --------------------------------------------------------------------------

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
  if (await isPortOpen(DB_PORT)) {
    console.log('  Port-forward already open, using existing tunnel.');
    return;
  }
  console.log('  Starting kubectl port-forward...');
  pfProcess = spawn(
    'kubectl',
    ['port-forward', 'pod/db-proxy', `${DB_PORT}:5432`, '-n', NAMESPACE],
    { env: { ...process.env, AWS_PROFILE }, stdio: 'ignore' }
  );
  pfProcess.on('error', err => { throw new Error(`kubectl failed: ${err.message}`); });
  await waitForPort(DB_PORT);
  console.log('  Tunnel ready.');
}

function stopPortForward() {
  if (pfProcess) {
    pfProcess.kill();
    pfProcess = null;
  }
}

// --------------------------------------------------------------------------
// Main
// --------------------------------------------------------------------------

async function main() {
  if (!SKIP_K8S) {
    await startPortForward();
  }

  const pool = new Pool(DB_CONFIG);

  try {
    if (ACTION === 'create') {
      const hash = await bcrypt.hash(PASSWORD, 12);
      await pool.query(
        `INSERT INTO admin_users (email, password_hash, name, role)
         VALUES ($1, $2, 'Smoke Test', 'platformAdmin')
         ON CONFLICT (email) DO UPDATE SET
           password_hash = EXCLUDED.password_hash,
           updated_at    = NOW()`,
        [EMAIL.toLowerCase(), hash]
      );
      console.log(`  Smoke admin created: ${EMAIL}`);
    } else {
      const res = await pool.query(
        'DELETE FROM admin_users WHERE email = $1 RETURNING id',
        [EMAIL.toLowerCase()]
      );
      if (res.rowCount > 0) {
        console.log(`  Smoke admin deleted: ${EMAIL}`);
      } else {
        console.log(`  Smoke admin not found (already deleted?): ${EMAIL}`);
      }
    }
  } finally {
    await pool.end();
    stopPortForward();
  }
}

main().catch(err => {
  console.error(`seed-smoke-admin: ${err.message}`);
  stopPortForward();
  process.exit(1);
});
