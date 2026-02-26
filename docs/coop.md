# COOP — Continuity of Operations Plan

Scripts for managing Industry Night's AWS infrastructure lifecycle: tear down to save costs, rebuild from scratch, and backup/restore database data.

## Quick Reference

```bash
# Check what's running and what it costs
./scripts/coop/coop.sh status

# Export database, then tear down EKS + RDS (~$160/mo → ~$3/mo)
./scripts/coop/coop.sh teardown

# Rebuild everything and restore data
./scripts/coop/coop.sh rebuild --import backups/2026-02-25_143000

# Export database only
./scripts/coop/coop.sh export

# Import database only
./scripts/coop/coop.sh import backups/2026-02-25_143000
```

## Prerequisites

Install these tools before using COOP scripts:

| Tool | Purpose | Install |
|------|---------|---------|
| `aws` | AWS CLI | `brew install awscli` |
| `eksctl` | EKS cluster management | `brew install eksctl` |
| `kubectl` | Kubernetes control | `brew install kubectl` |
| `helm` | ALB controller install (rebuild only) | `brew install helm` |
| `psql` | PostgreSQL client | `brew install libpq` |
| `pg_dump` / `pg_restore` | Database backup/restore | Included with `libpq` |
| `python3` | JSON parsing in scripts | Pre-installed on macOS |

You also need the `industrynight-admin` AWS CLI profile configured:
```bash
aws configure --profile industrynight-admin
```

## Commands

### `status` — Check Infrastructure State

```bash
./scripts/coop/coop.sh status
```

Shows the status of every AWS resource with color coding:
- **Green** — Running / Available
- **Yellow** — Stopped / Degraded
- **Red** — Missing / Deleted

Includes a cost summary at the bottom telling you whether you're in RUNNING (~$160/mo), HIBERNATED (~$3/mo), or MIXED state.

Safe to run anytime — read-only, changes nothing.

### `teardown` — Spin Down to Save Costs

```bash
./scripts/coop/coop.sh teardown [--yes] [--skip-rds-snapshot]
```

Does two things in sequence:
1. **Exports** the database to a timestamped backup in `backups/`
2. **Tears down** EKS cluster and RDS instance

**What gets deleted:**
- EKS cluster (control plane, node groups, VPC, NAT gateways, ALB)
- RDS PostgreSQL instance (creates a final snapshot by default)

**What gets preserved (~$3/mo):**
- S3 buckets (user assets, web admin app)
- ECR repository (container images)
- Secrets Manager (database credentials)
- Route 53 hosted zone (DNS)
- ACM certificate (SSL/TLS)

**Options:**
- `--yes` — Skip confirmation prompts
- `--skip-rds-snapshot` — Don't create an RDS snapshot before deleting (faster, but no AWS-side backup)

**How long it takes:** 15-20 minutes (most of that is EKS cluster deletion).

**Output:** Creates a teardown manifest at `backups/teardown_TIMESTAMP.log` recording every action taken and verifying preserved resources.

### `rebuild` — Recreate Infrastructure from Scratch

```bash
./scripts/coop/coop.sh rebuild [--yes] [--import backups/YYYY-MM-DD_HHMMSS]
```

Recreates everything that was torn down:

1. Verifies preserved resources still exist (fails fast if ECR or Secrets Manager are missing)
2. Creates EKS cluster from `infrastructure/eks/cluster.yaml`
3. Installs AWS Load Balancer Controller via Helm
4. Creates new RDS instance (discovers VPC/subnets from the new cluster)
5. Updates Secrets Manager with the new RDS endpoint
6. Applies all Kubernetes manifests (namespace, secrets, deployment, service, ingress)
7. Creates the `db-proxy` pod for database access
8. Runs database migrations (tracks applied migrations in `_migrations` table)
9. Loads specialties seed data
10. Deploys API from the latest ECR image
11. Verifies health endpoint

**Options:**
- `--yes` — Skip confirmation prompts
- `--import <dir>` — After rebuild, import data from a backup directory

**How long it takes:** 20-30 minutes (EKS creation is ~15-20 min, RDS is ~5-10 min).

**After rebuild, you may need to:**
- Update the Route 53 A/ALIAS record for `api.industrynight.net` to point to the new ALB DNS name (printed in the output)
- Build and push a new API image if ECR is empty: `./scripts/deploy-api.sh`

### `export` — Backup Database

```bash
./scripts/coop/coop.sh export [--yes]
```

Creates a timestamped backup directory:
```
backups/2026-02-25_143000/
  full_dump.custom        # pg_dump binary format (fastest restore)
  full_dump.sql           # Plain SQL (human-readable)
  tables/                 # Per-table INSERT scripts
    00_specialties.sql
    01_venues.sql
    02_users.sql
    ...
  metadata.json           # Timestamp, row counts, PG version
```

**Two backup formats:**
- `full_dump.custom` — Binary format for `pg_restore`. Fast, handles all types and constraints natively. Use `--full` when importing.
- `tables/*.sql` — Individual SQL INSERT files per table, ordered by foreign key dependencies. Human-readable, allows selective table restore. Use `--tables` when importing.

Requires the EKS cluster to be running (needs `db-proxy` pod for port-forward).

### `import` — Restore Database

```bash
./scripts/coop/coop.sh import <backup-dir> [--full|--tables] [--run-migrations] [--yes]
```

Restores data from a backup directory. Two modes:

**`--full` (default)** — Uses `pg_restore` from `full_dump.custom`:
```bash
./scripts/coop/coop.sh import backups/2026-02-25_143000 --full
```
- Drops and recreates all database objects
- Fastest and most complete restore
- Use this for full recovery

**`--tables`** — Runs per-table INSERT files in FK order:
```bash
./scripts/coop/coop.sh import backups/2026-02-25_143000 --tables
```
- Disables FK checks during import, re-enables after
- Useful for selective data restore or importing into an empty schema
- Combine with `--run-migrations` if the database has no schema yet

**`--run-migrations`** — Runs migration SQL files before importing:
```bash
./scripts/coop/coop.sh import backups/2026-02-25_143000 --tables --run-migrations
```
Use this when importing into a completely empty database (e.g., after a fresh RDS creation without using `rebuild`).

If you run `import` with no backup directory, it lists available backups.

## Typical Workflows

### Pausing Development (Save Money)

```bash
# 1. Check current state
./scripts/coop/coop.sh status

# 2. Tear down (exports data automatically)
./scripts/coop/coop.sh teardown

# 3. Verify hibernation
./scripts/coop/coop.sh status
# Should show: HIBERNATED — ~$3/month
```

### Resuming Development

```bash
# 1. Find your most recent backup
ls backups/

# 2. Rebuild and restore data
./scripts/coop/coop.sh rebuild --import backups/2026-02-25_143000

# 3. Verify everything is healthy
./scripts/coop/coop.sh status

# 4. Update Route 53 if needed (new ALB gets a new DNS name)
```

### Just Backing Up Before a Risky Change

```bash
# Export current state
./scripts/coop/coop.sh export

# Do your risky thing...

# If it went wrong, restore
./scripts/coop/coop.sh import backups/2026-02-25_143000
```

## Files

```
scripts/coop/
  coop.sh              Controller — single entry point for all commands
  config.sh            Shared constants (AWS IDs, table ordering) and helpers
  infra-status.sh      Resource status checker
  db-export.sh         Database export (pg_dump + per-table INSERTs)
  db-import.sh         Database import (pg_restore or per-table)
  infra-teardown.sh    EKS + RDS teardown
  infra-rebuild.sh     Full infrastructure rebuild

backups/               Created by export/teardown (git-ignored)
  YYYY-MM-DD_HHMMSS/   Timestamped database backups
  teardown_*.log        Teardown manifest logs
```

## Configuration

All AWS resource identifiers are centralized in `scripts/coop/config.sh`. If any resource ID changes (e.g., after manually recreating an S3 bucket with a different name), update it there.

Key values:
- AWS Profile: `industrynight-admin`
- Region: `us-east-1`
- EKS Cluster: `industrynight-prod`
- RDS Instance: `industrynight-db`
- ECR Repo: `industrynight-api`
- S3 Buckets: `industrynight-assets-prod`, `industrynight-web-admin`

## Troubleshooting

**`Port-forward failed to become ready`**
The `db-proxy` pod may not be running. Check: `kubectl get pods -n industrynight`. If missing, the rebuild script creates it automatically.

**`AWS credentials are not valid`**
Run `aws configure --profile industrynight-admin` or check that your credentials haven't expired.

**`pg_restore errors during import`**
`pg_restore` with `--clean --if-exists` may emit warnings about objects that don't exist yet. These are normal and non-fatal. Check the row counts printed after import to verify data integrity.

**`ALB not yet provisioned after rebuild`**
The ALB controller takes a few minutes to provision a new load balancer after the ingress is created. Wait 2-3 minutes and check: `kubectl get ingress -n industrynight`.

**`Health check returned HTTP 000`**
The ALB target group needs time to register and pass health checks. Wait 2-5 minutes and retry: `curl https://api.industrynight.net/health`.

**RDS auto-restarts after 7 days**
If you stop RDS instead of deleting it, AWS automatically restarts it after 7 days. The COOP teardown deletes RDS entirely (with a final snapshot) to avoid this.
