#!/bin/bash

# Database migration script
# Runs all migrations in order

set -e

# Configuration
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-industrynight}"
DB_USER="${DB_USER:-postgres}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIGRATIONS_DIR="$SCRIPT_DIR/../migrations"

echo "Running migrations for database: $DB_NAME"

# Create migrations tracking table if it doesn't exist
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<EOF
CREATE TABLE IF NOT EXISTS _migrations (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE,
    applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
EOF

# Run each migration file in order
for migration in "$MIGRATIONS_DIR"/*.sql; do
    filename=$(basename "$migration")

    # Check if already applied
    applied=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM _migrations WHERE name = '$filename';")

    if [ "$applied" -eq 0 ]; then
        echo "Applying migration: $filename"
        psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$migration"
        psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "INSERT INTO _migrations (name) VALUES ('$filename');"
        echo "Applied: $filename"
    else
        echo "Skipping (already applied): $filename"
    fi
done

echo "Migrations complete!"
