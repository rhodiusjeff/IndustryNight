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
 *
 * After creating the admin user, the email + password are automatically
 * saved to Secrets Manager under the SMOKE_ADMIN_EMAIL and
 * SMOKE_ADMIN_PASSWORD keys. This keeps the closeout smoke test in sync
 * across fresh environments without any manual follow-up.
 *
 * The Secrets Manager secret is chosen by IN_ENV (dev → industrynight/database-dev,
 * prod → industrynight/database). Set IN_ENV before running for prod, or let
 * it default to dev. Use --skip-secrets to opt out entirely.
 */

const path = require('path');
const { execSync } = require('child_process');
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
const skipSecrets = args.includes('--skip-secrets');

if (!email || !name || !password) {
  console.error('Usage: node scripts/seed-admin.js --email <email> --name <name> --password <password> [--skip-k8s] [--skip-secrets]');
  console.error('');
  console.error('Options:');
  console.error('  --email          Admin email address');
  console.error('  --name           Admin display name');
  console.error('  --password       Admin password (min 8 characters)');
  console.error('  --skip-k8s       Skip kubectl port-forward (for local PG)');
  console.error('  --skip-secrets   Skip Secrets Manager update (local dev without AWS)');
  process.exit(1);
}

/**
 * Write SMOKE_ADMIN_EMAIL and SMOKE_ADMIN_PASSWORD into the Secrets Manager
 * secret for the current environment. Best-effort — warns on failure.
 */
async function syncSecretsManager(adminEmail, adminPassword) {
  const env = process.env.IN_ENV || 'dev';
  const secretId = env === 'prod' ? 'industrynight/database' : 'industrynight/database-dev';
  const awsProfile = process.env.IN_AWS_PROFILE || 'industrynight-admin';

  try {
    console.log(`Syncing smoke credentials to Secrets Manager (${secretId})...`);
    const raw = execSync(
      `aws secretsmanager get-secret-value --secret-id '${secretId}' --query SecretString --output text --profile '${awsProfile}'`,
      { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] }
    );
    const current = JSON.parse(raw);
    current.SMOKE_ADMIN_EMAIL = adminEmail;
    current.SMOKE_ADMIN_PASSWORD = adminPassword;
    execSync(
      `aws secretsmanager update-secret --secret-id '${secretId}' --secret-string '${JSON.stringify(current).replace(/'/g, "'\"'\"'")}' --profile '${awsProfile}'`,
      { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] }
    );
    console.log('  Smoke credentials saved to Secrets Manager.');
  } catch (err) {
    console.warn(`[WARN] Could not update Secrets Manager — smoke test creds may be stale.`);
    console.warn(`[WARN] ${err.message.split('\n')[0]}`);
    console.warn(`[WARN] Re-run manually: aws secretsmanager update-secret --secret-id '${secretId}' ...`);
  }
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
    if (!skipSecrets) {
      await syncSecretsManager(admin.email, password);
    }
    console.log('Done.');
  } catch (error) {
    console.error('Error creating admin user:', error.message);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

main();
