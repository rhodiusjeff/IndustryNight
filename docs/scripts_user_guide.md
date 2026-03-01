# Scripts User Guide

Operational scripts for developing, debugging, and managing the Industry Night platform.

## Quick Reference

| Script | Purpose | Key flags |
|--------|---------|-----------|
| `deploy-api.sh` | Build & deploy API to EKS | `--skip-build`, `--status` |
| `pf-db.sh` | DB tunnel: localhost:5432 → db-proxy → RDS | `start`, `stop`, `status` |
| `db-reset.js` | Full DB reset + migrations | `--skip-k8s`, `--seed-only`, `--yes` |
| `db-scrub-user.js` | Delete users by phone | `--skip-k8s`, `--yes` |
| `migrate.js` | Apply pending DB migrations | `--skip-k8s`, `--dry-run`, `--status` |
| `seed-admin.js` | Create or reset an admin user | `--skip-k8s` |
| `maintenance.sh` | ALB maintenance mode toggle | `on`, `off`, `status` |
| `setup-local.sh` | Init local dev environment | (none) |
| `run-api.sh` | Start API dev server | (none) |
| `run-mobile.sh` | Start **social app** on simulator/device | (none) |
| `run-admin-app.sh` | Start **admin app** in Chrome | (none) |
| `debug-api.sh` | Remote Node.js debugging on EKS | `enable`, `disable` |
| `generate-exec-brief.py` | Regenerate PowerPoint executive brief | (none) |
| `generate-exec-summary.py` | Regenerate markdown executive summary | (none) |

---

## Development

### setup-local.sh

One-time local dev environment setup. Checks prerequisites (flutter, node, npm, dart), installs dependencies for all packages, generates `build_runner` code, and creates the API `.env` file.

```bash
./scripts/setup-local.sh
```

### run-api.sh

Starts the Express API server in development mode (`npm run dev`).

```bash
./scripts/run-api.sh
# API available at http://localhost:3000
```

**Requires:** Node.js, `packages/api/.env` with at least `JWT_SECRET`

### run-mobile.sh

Starts the Flutter **social app** (iOS/Android) on a connected simulator or device.

```bash
open -a Simulator          # Start iOS Simulator first
./scripts/run-mobile.sh
```

### run-admin-app.sh

Starts the Flutter **admin app** in Chrome at port 8080. Connects to `https://api.industrynight.net` (production API) — no local API or DB tunnel required.

```bash
./scripts/run-admin-app.sh
# Admin available at http://localhost:8080
```

### Typical local dev workflow

```bash
# Terminal 1
./scripts/run-api.sh

# Terminal 2 — social app
./scripts/run-mobile.sh

# Terminal 3 — admin app (web)
./scripts/run-admin-app.sh
```

---

## Deployment

### deploy-api.sh

Builds the API Docker image, pushes to ECR, and performs a rolling restart on EKS.

```bash
./scripts/deploy-api.sh              # Full: build → push → rollout
./scripts/deploy-api.sh --skip-build # Push existing image + rollout only
./scripts/deploy-api.sh --status     # Check current deployment status
```

**Requires:** Docker running, `AWS_PROFILE=industrynight-admin` configured, kubectl connected to EKS

**What happens:**
1. Authenticates with ECR
2. Builds `linux/amd64` Docker image from `packages/api/`
3. Pushes to `047593684855.dkr.ecr.us-east-1.amazonaws.com/industrynight-api:latest`
4. Restarts the deployment and waits for rollout to complete

### maintenance.sh

Toggles maintenance mode at the ALB level. When enabled, the ALB returns a 503 JSON response to all requests without reaching backend pods.

```bash
./scripts/maintenance.sh on       # Enable (ALB returns 503)
./scripts/maintenance.sh off      # Disable (resume normal traffic)
./scripts/maintenance.sh status   # Check current state
```

---

## Database

### pf-db.sh

Opens and closes the kubectl port-forward tunnel to the RDS database via the `db-proxy` pod. Use this when you need a persistent DB connection for ad-hoc work — running `psql`, resetting admin credentials with `seed-admin.js`, etc.

```bash
./scripts/pf-db.sh start    # Open tunnel: localhost:5432 → db-proxy → RDS
./scripts/pf-db.sh stop     # Close tunnel and free port 5432
./scripts/pf-db.sh status   # Is the tunnel open?
```

**Note:** `db-reset.js`, `db-scrub-user.js`, `migrate.js`, and `seed-admin.js` all manage their own port-forward internally — you do not need to run `pf-db.sh` before those scripts.

### migrate.js

Applies pending database migrations from `packages/database/migrations/`. Tracks applied migrations in the `_migrations` table — safe to re-run (skips already-applied files).

```bash
DB_PASSWORD=xxx node scripts/migrate.js              # Apply pending migrations (with k8s tunnel)
DB_PASSWORD=xxx node scripts/migrate.js --skip-k8s   # Local DB
DB_PASSWORD=xxx node scripts/migrate.js --status      # Show applied/pending migrations
DB_PASSWORD=xxx node scripts/migrate.js --dry-run     # Show what would be applied
```

**Requires:** `DB_PASSWORD` env var. Auto-starts `kubectl port-forward` to `db-proxy` unless `--skip-k8s`.

**Important:** Always run migrations before deploying API code that depends on new schema:
```bash
DB_PASSWORD=xxx node scripts/migrate.js
./scripts/deploy-api.sh
```

### seed-admin.js

Creates or resets an admin user in the `admin_users` table. Uses upsert — running it again with the same email updates the password and name without creating a duplicate.

```bash
# With EKS running (auto-manages port-forward)
DB_PASSWORD=xxx node scripts/seed-admin.js \
  --email admin@industrynight.net \
  --name "Admin" \
  --password <yourpassword>

# Local PostgreSQL only (no k8s tunnel)
DB_PASSWORD=xxx node scripts/seed-admin.js \
  --email admin@industrynight.net \
  --name "Admin" \
  --password <yourpassword> \
  --skip-k8s
```

**Requires:** `DB_PASSWORD` env var. Auto-starts `kubectl port-forward` to `db-proxy` unless `--skip-k8s`.

### db-reset.js

Full database reset: drops all tables and types, re-runs migrations, and loads seed data. Production-safe: automatically enables maintenance mode and scales the API to 0 before touching the database.

```bash
DB_PASSWORD=xxx node scripts/db-reset.js              # Full reset with k8s safety
DB_PASSWORD=xxx node scripts/db-reset.js --skip-k8s   # DB-only (local dev)
DB_PASSWORD=xxx node scripts/db-reset.js --seed-only   # Re-seed without dropping
DB_PASSWORD=xxx node scripts/db-reset.js --yes         # Skip confirmation
```

**Requires:** `DB_PASSWORD` env var. Auto-starts `kubectl port-forward` to `db-proxy` unless `--skip-k8s`.

**Optional env vars:** `DB_HOST` (localhost), `DB_PORT` (5432), `DB_NAME` (industrynight), `DB_USER` (industrynight)

**Production workflow:**
1. Enables maintenance mode
2. Scales API deployment to 0
3. Drops all tables and enum types
4. Runs `packages/database/migrations/*.sql`
5. Runs `packages/database/seeds/specialties.sql` and `dev_seed.sql`
6. Scales API back up
7. Disables maintenance mode

### db-scrub-user.js

Deletes specific users by phone number and all associated data. Shows a preview of the user and related record counts before confirming deletion.

```bash
DB_PASSWORD=xxx node scripts/db-scrub-user.js +15551234567
DB_PASSWORD=xxx node scripts/db-scrub-user.js +15551234567 +15559876543   # Multiple users
DB_PASSWORD=xxx node scripts/db-scrub-user.js --yes +15551234567          # Skip confirmation
DB_PASSWORD=xxx node scripts/db-scrub-user.js --skip-k8s +15551234567    # Local DB
```

**Phone normalization:** Accepts 10-digit (`5551234567`), 11-digit (`15551234567`), or E.164 (`+15551234567`).

**What gets deleted:**
- `verification_codes` (by phone, deleted first)
- `users` row (CASCADE handles: tickets, connections, posts, comments, likes, data exports, analytics)
- `audit_log` entries: actor_id is SET NULL (audit trail preserved, actor reference removed)

---

## Debugging

### debug-api.sh

Enables remote Node.js debugging on the EKS API pod. Scales to 1 replica, injects `--inspect=0.0.0.0:9229`, and starts a port-forward.

```bash
./scripts/debug-api.sh enable    # Start debug session
./scripts/debug-api.sh disable   # End session, restore normal operation
```

**Enable mode:**
1. Scales deployment to 1 replica
2. Injects `--inspect=0.0.0.0:9229` into the container command
3. Waits for rollout
4. Starts `kubectl port-forward` on port 9229 (blocks)

**Disable mode:**
1. Removes the inspect flag
2. Scales back to 2 replicas
3. Kills the port-forward process

**VS Code launch.json:**
```json
{
  "type": "node",
  "request": "attach",
  "name": "Attach to EKS",
  "address": "localhost",
  "port": 9229
}
```

---

## Reporting

### generate-exec-brief.py

Regenerates the 13-slide PowerPoint executive brief at `docs/Industry Night - Executive Brief.pptx`. Dark theme, purple accents, widescreen (16:9).

```bash
python3 -m venv /tmp/pptx-env && source /tmp/pptx-env/bin/activate && pip install python-pptx
python3 scripts/generate-exec-brief.py
```

Edit data values directly in the script before regenerating — see CLAUDE.md for which fields to update for a weekly brief.

### generate-exec-summary.py

Regenerates the companion markdown executive summary at `docs/executive-brief.md`.

```bash
python3 scripts/generate-exec-summary.py
```

---

## Common Workflows

### Launch the admin app locally

The admin app talks to the production API (`https://api.industrynight.net`) — no local API or DB tunnel needed.

```bash
./scripts/run-admin-app.sh
# Opens at http://localhost:8080
```

### Set up admin credentials, then launch the admin app

```bash
# 1. Set your DB password (from AWS Secrets Manager or your notes)
export DB_PASSWORD=xxx

# 2. Create or reset the admin user (script manages port-forward automatically)
node scripts/seed-admin.js \
  --email admin@industrynight.net \
  --name "Admin" \
  --password <yourpassword>

# 3. Launch the admin app
./scripts/run-admin-app.sh
# Login at http://localhost:8080 with the credentials above
```

### Deploy a backend fix

```bash
# Edit code in packages/api/
# If schema changed, run migrations first:
DB_PASSWORD=xxx node scripts/migrate.js
./scripts/deploy-api.sh
```

### Reset a test user between test cycles

```bash
DB_PASSWORD=xxx node scripts/db-scrub-user.js +15712120927
```

### Full database reset (staging/prod)

```bash
DB_PASSWORD=xxx node scripts/db-reset.js
# Automatically handles: maintenance on → scale down → reset → scale up → maintenance off
```

### Debug a production issue

```bash
./scripts/debug-api.sh enable
# Attach VS Code debugger, reproduce the issue, inspect state
# Ctrl+C when done
./scripts/debug-api.sh disable
```

### Ad-hoc database access (psql or other tools)

```bash
./scripts/pf-db.sh start
psql -h localhost -U industrynight -d industrynight
# ... do your work ...
./scripts/pf-db.sh stop
```
