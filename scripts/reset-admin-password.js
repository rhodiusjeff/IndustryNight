#!/usr/bin/env node
/**
 * reset-admin-password.js — Update an existing admin user's password
 *
 * USAGE:
 *   node scripts/reset-admin-password.js --email <email> --password <new-password> [--skip-k8s]
 *
 * ENVIRONMENT:
 *   DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD, DB_SSL
 *
 * EXAMPLES:
 *   # Local Docker PG (B0 test environment)
 *   DB_HOST=localhost DB_PORT=5432 DB_NAME=industrynight DB_USER=postgres \
 *   DB_PASSWORD=postgres DB_SSL=false \
 *   node scripts/reset-admin-password.js --email admin@industrynight.net --password newpass123 --skip-k8s
 *
 *   # AWS dev (through port-forward tunnel)
 *   DB_PASSWORD=xxx node scripts/reset-admin-password.js --email admin@industrynight.net --password newpass123
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

const args = process.argv.slice(2);

function getArg(name) {
  const idx = args.indexOf(`--${name}`);
  if (idx === -1 || idx + 1 >= args.length) return null;
  return args[idx + 1];
}

const EMAIL    = getArg('email');
const PASSWORD = getArg('password');
const SKIP_K8S = args.includes('--skip-k8s');

if (args.includes('--help') || args.includes('-h') || (!EMAIL && !PASSWORD)) {
  console.log(`
Usage:
  node scripts/reset-admin-password.js --email <email> --password <new-password> [--skip-k8s]

Arguments:
  --email      Email address of the existing admin user (required)
  --password   New password, minimum 8 characters (required)
  --skip-k8s   Skip kubectl port-forward setup (use for local Docker PG)
  --help       Show this help message

Environment variables:
  DB_PASSWORD  Database password (required)
  DB_HOST      Database host (default: localhost)
  DB_PORT      Database port (default: 5432)
  DB_NAME      Database name (default: industrynight)
  DB_USER      Database user (default: industrynight)
  DB_SSL       Set to "false" to disable SSL (use for local Docker PG)

Examples:
  # Local Docker PG (B0 test environment)
  DB_HOST=localhost DB_PORT=5432 DB_NAME=industrynight DB_USER=postgres \\
  DB_PASSWORD=postgres DB_SSL=false \\
  node scripts/reset-admin-password.js \\
    --email admin@industrynight.net --password newpass123 --skip-k8s

  # AWS dev (through port-forward tunnel)
  DB_PASSWORD=xxx node scripts/reset-admin-password.js \\
    --email admin@industrynight.net --password newpass123

Notes:
  - Fails explicitly if the email does not exist (use seed-admin.js to create new users)
  - Password is bcrypt-hashed with cost factor 12
`);
  process.exit(0);
}

if (!EMAIL || !PASSWORD) {
  console.error('Error: --email and --password are required.');
  console.error('Run with --help for usage.');
  process.exit(1);
}

if (PASSWORD.length < 8) {
  console.error('Error: Password must be at least 8 characters');
  process.exit(1);
}

if (!process.env.DB_PASSWORD) {
  console.error('ERROR: DB_PASSWORD environment variable is required.');
  process.exit(1);
}

const DB_PORT = parseInt(process.env.DB_PORT || '5432');

const DB_CONFIG = {
  host:     process.env.DB_HOST || 'localhost',
  port:     DB_PORT,
  database: process.env.DB_NAME || 'industrynight',
  user:     process.env.DB_USER || 'industrynight',
  password: process.env.DB_PASSWORD,
  ssl: process.env.DB_SSL === 'false' ? false : { rejectUnauthorized: false },
};

const NAMESPACE   = process.env.IN_NAMESPACE   || 'industrynight';
const AWS_PROFILE = process.env.IN_AWS_PROFILE || 'industrynight-admin';

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
  if (pfProcess) { pfProcess.kill(); pfProcess = null; }
}

async function main() {
  if (!SKIP_K8S) {
    await startPortForward();
  }

  const pool = new Pool(DB_CONFIG);

  try {
    const existing = await pool.query(
      'SELECT id, email, name, role FROM admin_users WHERE email = $1',
      [EMAIL.toLowerCase()]
    );

    if (existing.rowCount === 0) {
      console.error(`Error: No admin user found with email: ${EMAIL}`);
      console.error('  Use seed-admin.js to create a new admin user.');
      process.exit(1);
    }

    const admin = existing.rows[0];
    const hash = await bcrypt.hash(PASSWORD, 12);

    await pool.query(
      'UPDATE admin_users SET password_hash = $1, updated_at = NOW() WHERE email = $2',
      [hash, EMAIL.toLowerCase()]
    );

    console.log(`Password updated for: ${admin.email} (${admin.name}, ${admin.role})`);
  } finally {
    await pool.end();
    stopPortForward();
  }
}

main().catch(err => {
  console.error(`reset-admin-password: ${err.message}`);
  stopPortForward();
  process.exit(1);
});
