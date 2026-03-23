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

log_info "Generating new password..."
new_password=$(python3 - <<'PY'
import secrets
import string
chars = string.ascii_letters + string.digits + "!@#%^*()-_=+"
# Keep shell/JSON-friendly while still strong
print(''.join(secrets.choice(chars) for _ in range(40)))
PY
)

if [[ -z "$new_password" ]]; then
  log_error "Failed to generate password"
  exit 1
fi

log_step 1 4 "Applying new password to RDS instance"
aws_cmd rds modify-db-instance \
  --db-instance-identifier "$RDS_INSTANCE" \
  --master-user-password "$new_password" \
  --apply-immediately \
  >/dev/null

log_info "Waiting for RDS instance to become available..."
aws_cmd rds wait db-instance-available --db-instance-identifier "$RDS_INSTANCE"
log_success "RDS password rotation applied"

log_step 2 4 "Updating Secrets Manager entry"
current_secret_json=$(aws_cmd secretsmanager get-secret-value \
  --secret-id "$SECRETS_ID" \
  --query 'SecretString' \
  --output text)

updated_secret_json=$(python3 - <<'PY' "$current_secret_json" "$new_password"
import json
import sys
obj = json.loads(sys.argv[1])
obj['password'] = sys.argv[2]
print(json.dumps(obj, separators=(',',':')))
PY
)

aws_cmd secretsmanager update-secret \
  --secret-id "$SECRETS_ID" \
  --secret-string "$updated_secret_json" \
  >/dev/null
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

unset new_password
unset current_secret_json
unset updated_secret_json
