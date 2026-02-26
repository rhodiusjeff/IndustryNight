#!/usr/bin/env node
/**
 * seed-admin.js — Create an admin user in the admin_users table
 *
 * USAGE:
 *   node scripts/seed-admin.js --email admin@industrynight.net --name "Admin" --password <password>
 *   node scripts/seed-admin.js --email admin@industrynight.net --name "Admin" --password <password> --skip-k8s
 *
 * PREREQUISITES:
 *   - kubectl port-forward active (or --skip-k8s with local PG)
 *   - DB_PASSWORD env var set (or local PG with no password)
 */

const path = require('path');
const { Pool } = require(require.resolve('pg', { paths: [path.resolve(__dirname, '../packages/api')] }));
const bcrypt = require(require.resolve('bcryptjs', { paths: [path.resolve(__dirname, '../packages/api')] }));

const args = process.argv.slice(2);

function getArg(name) {
  const idx = args.indexOf(`--${name}`);
  if (idx === -1 || idx + 1 >= args.length) return null;
  return args[idx + 1];
}

const email = getArg('email');
const name = getArg('name');
const password = getArg('password');
const skipK8s = args.includes('--skip-k8s');

if (!email || !name || !password) {
  console.error('Usage: node scripts/seed-admin.js --email <email> --name <name> --password <password> [--skip-k8s]');
  console.error('');
  console.error('Options:');
  console.error('  --email       Admin email address');
  console.error('  --name        Admin display name');
  console.error('  --password    Admin password (min 8 characters)');
  console.error('  --skip-k8s    Skip kubectl port-forward (for local PG)');
  process.exit(1);
}

if (password.length < 8) {
  console.error('Error: Password must be at least 8 characters');
  process.exit(1);
}

async function main() {
  const pool = new Pool({
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT || '5432'),
    database: process.env.DB_NAME || 'industrynight',
    user: process.env.DB_USER || 'industrynight',
    password: process.env.DB_PASSWORD || undefined,
    ssl: skipK8s ? false : { rejectUnauthorized: false },
  });

  try {
    console.log(`Creating admin user: ${email}`);

    const passwordHash = await bcrypt.hash(password, 12);

    const result = await pool.query(
      `INSERT INTO admin_users (email, password_hash, name, role)
       VALUES ($1, $2, $3, 'platformAdmin')
       ON CONFLICT (email) DO UPDATE SET
         password_hash = EXCLUDED.password_hash,
         name = EXCLUDED.name,
         updated_at = NOW()
       RETURNING id, email, name, role, is_active, created_at`,
      [email.toLowerCase(), passwordHash, name]
    );

    const admin = result.rows[0];
    console.log('');
    console.log('Admin user created/updated:');
    console.log(`  ID:    ${admin.id}`);
    console.log(`  Email: ${admin.email}`);
    console.log(`  Name:  ${admin.name}`);
    console.log(`  Role:  ${admin.role}`);
    console.log('');
    console.log('Done.');
  } catch (error) {
    console.error('Error creating admin user:', error.message);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

main();
