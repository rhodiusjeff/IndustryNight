#!/bin/bash

# Database reset script
# WARNING: This will destroy all data! Use only in development.

set -e

# Configuration
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-industrynight}"
DB_USER="${DB_USER:-postgres}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEEDS_DIR="$SCRIPT_DIR/../seeds"

echo "WARNING: This will destroy all data in database: $DB_NAME"
read -p "Are you sure? (type 'yes' to confirm): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

echo "Dropping and recreating database..."

# Drop and recreate database
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres <<EOF
DROP DATABASE IF EXISTS $DB_NAME;
CREATE DATABASE $DB_NAME;
EOF

echo "Database recreated."

# Run migrations
echo "Running migrations..."
"$SCRIPT_DIR/migrate.sh"

# Run seed data
echo "Loading seed data..."
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$SEEDS_DIR/dev_seed.sql"

echo "Database reset complete!"
