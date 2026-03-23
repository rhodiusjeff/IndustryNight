#!/bin/bash
set -euo pipefail

# rotate-db-password.sh — Rotate RDS master DB password and update Secrets Manager
#
# Usage:
#   ./scripts/rotate-db-password.sh [--env dev|prod] [--yes] [--no-copy]
#
# Behavior:
# - Generates a new strong password
# - Applies it to the target RDS instance (master user password)
# - Waits for instance to become available
# - Updates Secrets Manager entry for the same environment
# - Copies new password to clipboard by default (macOS)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/coop/config.sh"

parse_env_flag "$@"
set -- "${PASSTHROUGH_ARGS[@]+"${PASSTHROUGH_ARGS[@]}"}"
load_environment "$IN_ENV"

SKIP_CONFIRM=false
COPY_TO_CLIPBOARD=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes)
      SKIP_CONFIRM=true
      shift
      ;;
    --no-copy)
      COPY_TO_CLIPBOARD=false
      shift
      ;;
    *)
      echo "Usage: $0 [--env dev|prod] [--yes] [--no-copy]"
      exit 1
      ;;
  esac
done

check_aws_credentials

confirm_destructive "Rotate ${ENV_NAME} database password for RDS instance ${RDS_INSTANCE}."

tmp_dir=$(mktemp -d)
chmod 700 "$tmp_dir"
rds_request_file="$tmp_dir/rds-modify.json"
secret_update_file="$tmp_dir/secret-update.json"

cleanup() {
  rm -rf "$tmp_dir"
  unset new_password current_secret_json
}
trap cleanup EXIT

log_info "Generating new password..."
new_password=$(python3 - <<'PY'
import secrets
import string
chars = string.ascii_letters + string.digits
# Use alphanumerics to avoid provider/quoting edge cases.
print(''.join(secrets.choice(chars) for _ in range(40)))
PY
)

if [[ -z "$new_password" ]]; then
  log_error "Failed to generate password"
  exit 1
fi

log_step 1 4 "Applying new password to RDS instance"
NEW_PASSWORD="$new_password" RDS_INSTANCE="$RDS_INSTANCE" RDS_REQUEST_FILE="$rds_request_file" python3 - <<'PY'
import json
import os

payload = {
  "DBInstanceIdentifier": os.environ["RDS_INSTANCE"],
  "MasterUserPassword": os.environ["NEW_PASSWORD"],
  "ApplyImmediately": True,
}

with open(os.environ["RDS_REQUEST_FILE"], "w", encoding="utf-8") as f:
  json.dump(payload, f, separators=(",", ":"))
PY

aws_cmd rds modify-db-instance --cli-input-json "file://$rds_request_file" >/dev/null

log_info "Waiting for RDS instance to become available..."
aws_cmd rds wait db-instance-available --db-instance-identifier "$RDS_INSTANCE"
log_success "RDS password rotation applied"

log_step 2 4 "Updating Secrets Manager entry"
current_secret_json=$(aws_cmd secretsmanager get-secret-value \
  --secret-id "$SECRETS_ID" \
  --query 'SecretString' \
  --output text)

NEW_PASSWORD="$new_password" SECRETS_ID="$SECRETS_ID" SECRET_UPDATE_FILE="$secret_update_file" python3 - <<'PY' <<<"$current_secret_json"
import json
import os
import sys

obj = json.load(sys.stdin)
obj['password'] = os.environ['NEW_PASSWORD']

payload = {
  'SecretId': os.environ['SECRETS_ID'],
  'SecretString': json.dumps(obj, separators=(',', ':')),
}

with open(os.environ['SECRET_UPDATE_FILE'], 'w', encoding='utf-8') as f:
  json.dump(payload, f, separators=(',', ':'))
PY

aws_cmd secretsmanager update-secret --cli-input-json "file://$secret_update_file" >/dev/null
log_success "Secrets Manager updated: $SECRETS_ID"

log_step 3 4 "Clipboard handling"
if [[ "$COPY_TO_CLIPBOARD" == "true" ]]; then
  if command -v pbcopy >/dev/null 2>&1; then
    printf %s "$new_password" | pbcopy
    log_success "New password copied to clipboard"
  else
    log_warn "pbcopy not found; skipping clipboard copy"
  fi
else
  log_info "Skipping clipboard copy (--no-copy)"
fi

log_step 4 4 "Done"
log_success "Password rotation complete for ${ENV_NAME} (${RDS_INSTANCE})"
log_warn "Restart/redeploy services that cache DB credentials if needed."
