#!/bin/bash
set -euo pipefail

# copy-db-password.sh — Copy DB password from Secrets Manager to clipboard
#
# Usage:
#   ./scripts/copy-db-password.sh [--env dev|prod]
#
# Notes:
# - Copies the password only; does not print it to stdout.
# - Requires pbcopy (macOS).

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/coop/config.sh"

parse_env_flag "$@"
set -- "${PASSTHROUGH_ARGS[@]+"${PASSTHROUGH_ARGS[@]}"}"
load_environment "$IN_ENV"

usage() {
  cat <<EOF
Usage: $0 [--env dev|prod]

Copies DB password from Secrets Manager to clipboard for the selected environment.
Defaults to --env dev.
EOF
}

if [[ $# -gt 0 ]]; then
  usage
  exit 1
fi

if ! command -v pbcopy >/dev/null 2>&1; then
  log_error "pbcopy not found (this script currently supports macOS clipboard only)."
  exit 1
fi

check_aws_credentials

secret_json=$(aws_cmd secretsmanager get-secret-value \
  --secret-id "$SECRETS_ID" \
  --query 'SecretString' \
  --output text)

db_password=$(echo "$secret_json" | python3 -c "import json,sys; o=json.load(sys.stdin); print(o.get('password') or o.get('DB_PASSWORD') or o.get('db_password') or '')")

if [[ -z "$db_password" ]]; then
  log_error "Could not find password key in secret $SECRETS_ID"
  exit 1
fi

printf %s "$db_password" | pbcopy

unset db_password
unset secret_json

log_success "Copied ${ENV_NAME} DB password to clipboard from $SECRETS_ID"
