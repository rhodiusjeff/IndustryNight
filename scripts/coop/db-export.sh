#!/bin/bash
set -euo pipefail

# db-export.sh — Export database to local backups
#
# Creates a timestamped backup with:
#   - full_dump.custom   — pg_dump custom format (for pg_restore)
#   - full_dump.sql      — pg_dump plain SQL (human-readable)
#   - tables/            — Per-table INSERT scripts (FK-ordered, selective restore)
#   - metadata.json      — Timestamp, row counts, database version
#
# Usage:
#   ./scripts/coop/db-export.sh [--env dev|prod] [--yes]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"

parse_env_flag "$@"
set -- "${PASSTHROUGH_ARGS[@]+"${PASSTHROUGH_ARGS[@]}"}"
load_environment "$IN_ENV"

# Parse args
SKIP_CONFIRM=false
for arg in "$@"; do
  case $arg in
    --yes) SKIP_CONFIRM=true ;;
    *) log_error "Unknown option: $arg"; exit 1 ;;
  esac
done

TOTAL_STEPS=6
CURRENT_STEP=0

env_color=$CYAN
[[ "$ENV_NAME" == "prod" ]] && env_color=$RED

echo -e "${BOLD}=== Database Export ===${NC}"
ENV_UPPER=$(echo "$ENV_NAME" | tr '[:lower:]' '[:upper:]')
echo -e "  Environment: ${env_color}${ENV_UPPER}${NC} ($ENV_LABEL)"
echo ""

# Step 1: Prerequisites
log_step $((++CURRENT_STEP)) $TOTAL_STEPS "Checking prerequisites..."
check_prerequisites
check_aws_credentials

# Step 2: Get DB credentials
log_step $((++CURRENT_STEP)) $TOTAL_STEPS "Retrieving database credentials..."
DB_PASSWORD=$(get_db_password)
export PGPASSWORD="$DB_PASSWORD"
DB_HOST="localhost"
DB_PORT="5432"
DB_USER="$RDS_MASTER_USER"
DB_NAME="$RDS_DB_NAME"
log_success "Credentials retrieved"

# Step 3: Establish port-forward
log_step $((++CURRENT_STEP)) $TOTAL_STEPS "Establishing database connection..."
start_port_forward "$DB_PORT"

# Clean up on exit
trap 'stop_port_forward; unset PGPASSWORD' EXIT

# Verify connection
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1" &>/dev/null
log_success "Database connection verified"

# Step 4: Create backup directory
log_step $((++CURRENT_STEP)) $TOTAL_STEPS "Creating backup directory..."
TIMESTAMP=$(create_timestamp)
mkdir -p "$BACKUPS_PATH"
BACKUP_DIR="$BACKUPS_PATH/$TIMESTAMP"
mkdir -p "$BACKUP_DIR/tables"
log_success "Created: $BACKUP_DIR"

# Step 5: Full pg_dump (both formats)
log_step $((++CURRENT_STEP)) $TOTAL_STEPS "Running full database dump..."

# Custom format (compressed, supports pg_restore)
log_info "  Exporting custom format (full_dump.custom)..."
pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
  --format=custom \
  --file="$BACKUP_DIR/full_dump.custom" 2>/dev/null

# Plain SQL format (human-readable, portable)
log_info "  Exporting plain SQL (full_dump.sql)..."
pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
  --format=plain \
  --no-owner \
  --no-privileges \
  --file="$BACKUP_DIR/full_dump.sql" 2>/dev/null

log_success "Full dump complete"

# Step 6: Per-table INSERT exports (FK-ordered)
log_step $((++CURRENT_STEP)) $TOTAL_STEPS "Exporting per-table INSERT scripts..."

TABLE_INDEX=0
for table in $ALL_TABLES_ORDERED; do
  PADDED=$(printf "%02d" $TABLE_INDEX)
  TABLE_FILE="$BACKUP_DIR/tables/${PADDED}_${table}.sql"

  ROW_COUNT=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
    -t -A -c "SELECT COUNT(*) FROM $table" 2>/dev/null || echo "0")
  ROW_COUNT=$(echo "$ROW_COUNT" | tr -d '[:space:]')

  log_info "  $table ($ROW_COUNT rows)"

  # Header
  cat > "$TABLE_FILE" << HEADER
-- Table: $table
-- Exported: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
-- Rows: $ROW_COUNT

-- Disable triggers during import for performance
ALTER TABLE $table DISABLE TRIGGER ALL;

HEADER

  # Export as INSERT statements with column names
  if [[ "$ROW_COUNT" -gt 0 ]]; then
    pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
      --table="$table" \
      --data-only \
      --column-inserts \
      --no-owner \
      --no-privileges \
      >> "$TABLE_FILE" 2>/dev/null
  fi

  # Footer: re-enable triggers
  cat >> "$TABLE_FILE" << FOOTER

-- Re-enable triggers
ALTER TABLE $table ENABLE TRIGGER ALL;
FOOTER

  TABLE_INDEX=$((TABLE_INDEX + 1))
done
log_success "Exported $TABLE_INDEX tables"

# Generate metadata.json
log_info "Writing metadata..."

PG_VERSION=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
  -t -A -c "SHOW server_version" 2>/dev/null | tr -d '[:space:]')

{
  echo "{"
  echo "  \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\","
  echo "  \"environment\": \"$ENV_NAME\","
  echo "  \"database\": \"$DB_NAME\","
  echo "  \"postgres_version\": \"$PG_VERSION\","
  echo "  \"tables\": {"

  FIRST=true
  for table in $ALL_TABLES_ORDERED; do
    ROW_COUNT=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
      -t -A -c "SELECT COUNT(*) FROM $table" 2>/dev/null || echo "0")
    ROW_COUNT=$(echo "$ROW_COUNT" | tr -d '[:space:]')
    if [[ "$FIRST" == "true" ]]; then
      FIRST=false
    else
      echo ","
    fi
    printf "    \"%s\": %s" "$table" "$ROW_COUNT"
  done
  echo ""
  echo "  }"
  echo "}"
} > "$BACKUP_DIR/metadata.json"

# Summary
echo ""
echo -e "${BOLD}=== Export Complete ===${NC}"
echo "  Location:   $BACKUP_DIR"
echo "  Full dump:  full_dump.custom ($(du -h "$BACKUP_DIR/full_dump.custom" | cut -f1))"
echo "  SQL dump:   full_dump.sql ($(du -h "$BACKUP_DIR/full_dump.sql" | cut -f1))"
echo "  Tables:     $TABLE_INDEX files in tables/"
echo "  Metadata:   metadata.json"
echo ""
RELATIVE_BACKUP="$BACKUPS_DIR/$BACKUPS_SUBDIR/$TIMESTAMP"
echo "  To restore (full):   ./scripts/coop/coop.sh --env $ENV_NAME import $RELATIVE_BACKUP --full"
echo "  To restore (tables): ./scripts/coop/coop.sh --env $ENV_NAME import $RELATIVE_BACKUP --tables"
