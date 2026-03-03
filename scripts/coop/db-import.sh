#!/bin/bash
set -euo pipefail

# db-import.sh — Import database from a backup directory
#
# Modes:
#   --full     pg_restore from full_dump.custom (drops and recreates objects)
#   --tables   Execute per-table INSERT files (FK checks disabled during import)
#
# Usage:
#   ./scripts/coop/db-import.sh <backup-dir> --full     # Restore from full dump
#   ./scripts/coop/db-import.sh <backup-dir> --tables   # Per-table INSERT restore
#   ./scripts/coop/db-import.sh <backup-dir>            # Defaults to --full
#
# Options:
#   --run-migrations  Run migration SQL before importing (for empty databases)
#   --yes             Skip confirmation prompts

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Parse args
BACKUP_DIR=""
IMPORT_MODE="full"
RUN_MIGRATIONS=false
SKIP_CONFIRM=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --full) IMPORT_MODE="full"; shift ;;
    --tables) IMPORT_MODE="tables"; shift ;;
    --run-migrations) RUN_MIGRATIONS=true; shift ;;
    --yes) SKIP_CONFIRM=true; shift ;;
    *)
      if [[ -z "$BACKUP_DIR" ]]; then
        BACKUP_DIR="$1"
      else
        log_error "Unknown argument: $1"
        exit 1
      fi
      shift
      ;;
  esac
done

# Resolve relative paths
if [[ -n "$BACKUP_DIR" && "${BACKUP_DIR:0:1}" != "/" ]]; then
  BACKUP_DIR="$PROJECT_ROOT/$BACKUP_DIR"
fi

# Validate
if [[ -z "$BACKUP_DIR" || ! -d "$BACKUP_DIR" ]]; then
  log_error "Backup directory not found: ${BACKUP_DIR:-<none>}"
  echo "Usage: $0 <backup-dir> [--full|--tables] [--run-migrations] [--yes]"
  exit 1
fi

if [[ "$IMPORT_MODE" == "full" && ! -f "$BACKUP_DIR/full_dump.custom" ]]; then
  log_error "Full dump not found: $BACKUP_DIR/full_dump.custom"
  echo "Use --tables mode to import from per-table SQL files instead."
  exit 1
fi

if [[ "$IMPORT_MODE" == "tables" && ! -d "$BACKUP_DIR/tables" ]]; then
  log_error "Tables directory not found: $BACKUP_DIR/tables/"
  exit 1
fi

TOTAL_STEPS=5
CURRENT_STEP=0

echo -e "${BOLD}=== Database Import ===${NC}"
echo "  Source: $BACKUP_DIR"
echo "  Mode:   $IMPORT_MODE"
if [[ -f "$BACKUP_DIR/metadata.json" ]]; then
  BACKUP_TS=$(python3 -c "import json; m=json.load(open('$BACKUP_DIR/metadata.json')); print(m.get('timestamp','unknown'))" 2>/dev/null || echo "unknown")
  echo "  Backup: $BACKUP_TS"
fi
echo ""

confirm_destructive "This will overwrite data in the $RDS_DB_NAME database."

# Step 1: Prerequisites
log_step $((++CURRENT_STEP)) $TOTAL_STEPS "Checking prerequisites..."
check_prerequisites
check_aws_credentials

# Step 2: Connect
log_step $((++CURRENT_STEP)) $TOTAL_STEPS "Establishing database connection..."
DB_PASSWORD=$(get_db_password)
export PGPASSWORD="$DB_PASSWORD"
DB_HOST="localhost"
DB_PORT="5432"
DB_USER="$RDS_MASTER_USER"
DB_NAME="$RDS_DB_NAME"

start_port_forward "$DB_PORT"
trap 'stop_port_forward; unset PGPASSWORD' EXIT

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1" &>/dev/null
log_success "Database connection verified"

# Step 3: Optionally run migrations
if [[ "$RUN_MIGRATIONS" == "true" ]]; then
  log_step $((++CURRENT_STEP)) $TOTAL_STEPS "Running migrations..."

  psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
    -c 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp"' &>/dev/null

  for migration_file in "$PROJECT_ROOT/$MIGRATIONS_DIR"/*.sql; do
    [[ -f "$migration_file" ]] || continue
    FILENAME=$(basename "$migration_file")
    log_info "  Applying: $FILENAME"
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
      -f "$migration_file" &>/dev/null
  done
  log_success "Migrations applied"
else
  log_step $((++CURRENT_STEP)) $TOTAL_STEPS "Skipping migrations (not requested)"
fi

# Step 4: Import data
log_step $((++CURRENT_STEP)) $TOTAL_STEPS "Importing data ($IMPORT_MODE mode)..."

if [[ "$IMPORT_MODE" == "full" ]]; then
  log_info "Running pg_restore..."
  pg_restore -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
    --clean \
    --if-exists \
    --no-owner \
    --no-privileges \
    "$BACKUP_DIR/full_dump.custom" 2>&1 | tail -10 || true
  log_success "pg_restore complete"

else
  log_info "Importing per-table INSERT files..."

  # Disable FK constraint checks during import
  psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
    -c "SET session_replication_role = 'replica';" &>/dev/null

  # Import files in sorted order (00_, 01_, 02_, ...)
  for sql_file in "$BACKUP_DIR/tables/"*.sql; do
    [[ -f "$sql_file" ]] || continue
    FILENAME=$(basename "$sql_file")
    log_info "  Importing: $FILENAME"
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
      -f "$sql_file" &>/dev/null || log_warn "  Failed: $FILENAME (continuing)"
  done

  # Re-enable FK constraint checks
  psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
    -c "SET session_replication_role = 'origin';" &>/dev/null

  log_success "Table import complete"
fi

# Step 5: Verify
log_step $((++CURRENT_STEP)) $TOTAL_STEPS "Verifying import..."

echo ""
echo "  Table row counts after import:"
for table in $ALL_TABLES_ORDERED; do
  ROW_COUNT=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
    -t -A -c "SELECT COUNT(*) FROM $table" 2>/dev/null || echo "?")
  ROW_COUNT=$(echo "$ROW_COUNT" | tr -d '[:space:]')
  printf "    %-40s %s rows\n" "$table" "$ROW_COUNT"
done

echo ""
echo -e "${BOLD}=== Import Complete ===${NC}"
