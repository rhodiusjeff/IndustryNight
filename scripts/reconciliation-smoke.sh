#!/bin/bash
set -euo pipefail

# reconciliation-smoke.sh — End-to-end reconciliation test for Posh orders -> IN users/tickets
#
# Runs a full flow against one event and two phones:
# 1) Create admin event with poshEventId
# 2) Send new_order webhook payloads for both phones
# 3) Verify posh_orders are pre-signup (user_id NULL)
# 4) Register/login users (automated devCode OR manual on phone)
# 5) Verify posh_orders linked to users and tickets created
#
# Usage:
#   ./scripts/reconciliation-smoke.sh [--env dev|prod] [--partial-manual]
#
# Required env vars:
#   SMOKE_ADMIN_TOKEN OR (SMOKE_ADMIN_EMAIL + SMOKE_ADMIN_PASSWORD)
# Optional env vars:
#   SMOKE_POSH_SECRET (otherwise read from Secrets Manager key POSH_WEBHOOK_SECRET)
#   SMOKE_ADMIN_TOKEN (Bearer token to skip /admin/auth/login)
#   RECON_PHONE_A (default +15712120927)
#   RECON_PHONE_B (default +19412430946)
#   RECON_EVENT_NAME (default Reconcile Event)
#   RECON_POSH_EVENT_ID (default reconcile-<env>-<timestamp>)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/coop/config.sh"

parse_env_flag "$@"
set -- "${PASSTHROUGH_ARGS[@]+"${PASSTHROUGH_ARGS[@]}"}"
load_environment "$IN_ENV"

PARTIAL_MANUAL=false
RUN_PHONE_A=true
RUN_PHONE_B=true

print_usage() {
  cat <<'EOF'
Usage:
  ./scripts/reconciliation-smoke.sh [--env dev|prod] [--partial-manual] [--only-571|--only-941]

Options:
  --env dev|prod      Target environment (defaults to dev)
  --partial-manual    Pause for manual user registration/login in social app
  --only-571          Run reconciliation flow for RECON_PHONE_A only (default +15712120927)
  --only-941          Run reconciliation flow for RECON_PHONE_B only (default +19412430946)
  --help, -h, -?      Show this help message

Required environment variables:
  SMOKE_ADMIN_TOKEN
  OR
  SMOKE_ADMIN_EMAIL + SMOKE_ADMIN_PASSWORD

Optional environment variables:
  SMOKE_POSH_SECRET
  SMOKE_ADMIN_TOKEN
  RECON_PHONE_A
  RECON_PHONE_B
  RECON_EVENT_NAME
  RECON_POSH_EVENT_ID
EOF
}

for arg in "$@"; do
  case "$arg" in
    --partial-manual) PARTIAL_MANUAL=true ;;
    --only-571) RUN_PHONE_A=true; RUN_PHONE_B=false ;;
    --only-941) RUN_PHONE_A=false; RUN_PHONE_B=true ;;
    --help|-h|-?) print_usage; exit 0 ;;
    *) log_error "Unknown option: $arg"; exit 1 ;;
  esac
done

if [[ "$RUN_PHONE_A" == "false" && "$RUN_PHONE_B" == "false" ]]; then
  log_error "Nothing to run. Choose --only-phone-a or --only-phone-b (or neither for both)."
  exit 1
fi

for cmd in curl jq psql aws; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log_error "$cmd is required"
    exit 1
  fi
done

if [[ -z "${SMOKE_ADMIN_TOKEN:-}" ]]; then
  if [[ -z "${SMOKE_ADMIN_EMAIL:-}" || -z "${SMOKE_ADMIN_PASSWORD:-}" ]]; then
    log_error "Set SMOKE_ADMIN_TOKEN or both SMOKE_ADMIN_EMAIL and SMOKE_ADMIN_PASSWORD"
    exit 1
  fi
fi

BASE_URL="https://${API_HOST}"
PHONE_A="${RECON_PHONE_A:-+15712120927}"
PHONE_B="${RECON_PHONE_B:-+19412430946}"
EVENT_NAME="${RECON_EVENT_NAME:-Reconcile Event}"
VENUE_NAME="Casa Azario"
VENUE_ADDR="3630 Santa Caterina Blvd, Bradenton, FL 34211"
START_TIME="2026-03-27T19:00:00.000Z"
END_TIME="2026-03-28T03:00:00.000Z"
POSH_EVENT_ID="${RECON_POSH_EVENT_ID:-reconcile-${ENV_NAME}-$(date +%s)}"

SECRET_JSON="$(aws --profile "$AWS_PROFILE" --region "$AWS_REGION" secretsmanager get-secret-value --secret-id "$SECRETS_ID" --query SecretString --output text)"
SMOKE_POSH_SECRET="${SMOKE_POSH_SECRET:-$(echo "$SECRET_JSON" | jq -r '.POSH_WEBHOOK_SECRET // empty')}"
DB_PASSWORD="$(echo "$SECRET_JSON" | jq -r '.password')"

if [[ -z "$SMOKE_POSH_SECRET" ]]; then
  log_error "SMOKE_POSH_SECRET is empty and Secrets Manager key POSH_WEBHOOK_SECRET is missing"
  exit 1
fi

if [[ -z "$DB_PASSWORD" || "$DB_PASSWORD" == "null" ]]; then
  log_error "Could not read DB password from Secrets Manager"
  exit 1
fi

FAILURES=0

db_scalar() {
  local sql="$1"
  PGPASSWORD="$DB_PASSWORD" psql -q -h localhost -p 5432 -U industrynight -d industrynight -t -A -c "$sql" | tr -d '\r' | sed 's/[[:space:]]*$//'
}

phone_logged_in_since() {
  local phone="$1"
  local since_iso="$2"
  local digits
  digits="$(echo "$phone" | tr -cd '0-9')"
  local local_digits="$digits"
  if [[ "${#digits}" -gt 10 ]]; then
    local_digits="${digits: -10}"
  fi

  db_scalar "SELECT COUNT(*) FROM users WHERE regexp_replace(phone, '[^0-9]', '', 'g') IN ('$digits', '$local_digits', ('1' || '$local_digits')) AND last_login_at IS NOT NULL AND last_login_at >= '$since_iso'::timestamptz;"
}

post_json() {
  local path="$1"
  local payload="$2"
  local auth_header="${3:-}"

  if [[ -n "$auth_header" ]]; then
    curl -sS --connect-timeout 10 --max-time 30 \
      -H "Content-Type: application/json" \
      -H "$auth_header" \
      -d "$payload" \
      "$BASE_URL$path"
  else
    curl -sS --connect-timeout 10 --max-time 30 \
      -H "Content-Type: application/json" \
      -d "$payload" \
      "$BASE_URL$path"
  fi
}

require_equals() {
  local label="$1"
  local actual="$2"
  local expected="$3"
  if [[ "$actual" == "$expected" ]]; then
    log_success "$label = $actual"
  else
    log_error "$label expected $expected, got $actual"
    FAILURES=$((FAILURES + 1))
  fi
}

manual_pause() {
  local prompt="$1"
  echo ""
  log_warn "$prompt"
  read -r -p "Press Enter to continue..." _
}

manual_reconcile_phone() {
  local phone="$1"
  local order_num="$2"
  local label="$3"

  local linked="0"
  local attempt
  for attempt in 1 2 3; do
    local attempt_started_at
    attempt_started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    if [[ "$attempt" -eq 1 ]]; then
      manual_pause "Complete full OTP login in the social app for $phone (log out first if already signed in)"
    else
      manual_pause "Retry $attempt/3: complete full OTP login for $phone, then return here"
    fi

    local recent_logins
    recent_logins="$(phone_logged_in_since "$phone" "$attempt_started_at")"
    if [[ "$recent_logins" == "0" ]]; then
      log_warn "No new login detected for $phone after pressing Enter; skipping long wait and prompting retry."
      continue
    fi

    if wait_for_linked_order "$order_num" 90; then
      linked="1"
      break
    fi

    log_warn "No link detected for $phone after attempt $attempt"
    print_link_debug "$order_num" "$phone"
  done

  if [[ "$linked" != "1" ]]; then
    log_warn "Manual $label flow did not link after retries. Attempting automated verify-code fallback (dev mode only)."
    automated_signup "$phone"
    if wait_for_linked_order "$order_num" 20; then
      linked="1"
    fi
  fi
}

wait_for_linked_order() {
  local order_num="$1"
  local timeout_seconds="${2:-90}"
  local elapsed=0

  log_info "Checking linkage for order $order_num (timeout ${timeout_seconds}s)..."

  while [[ "$elapsed" -lt "$timeout_seconds" ]]; do
    local linked
    linked=$(db_scalar "SELECT COUNT(*) FROM posh_orders WHERE order_number = '$order_num' AND user_id IS NOT NULL;")
    if [[ "$linked" == "1" ]]; then
      log_success "Order $order_num is now linked"
      return 0
    fi

    if [[ "$elapsed" -gt 0 && $((elapsed % 10)) -eq 0 ]]; then
      local remaining=$((timeout_seconds - elapsed))
      log_info "Still waiting for order linkage... ${remaining}s remaining"
    fi

    sleep 2
    elapsed=$((elapsed + 2))
  done

  log_warn "Timed out waiting for order $order_num to link"

  return 1
}

print_link_debug() {
  local order_num="$1"
  local phone="$2"
  local digits
  digits="$(echo "$phone" | tr -cd '0-9')"
  local local_digits="$digits"
  if [[ "${#digits}" -gt 10 ]]; then
    local_digits="${digits: -10}"
  fi

  log_info "Debug for order $order_num (phone $phone):"
  db_scalar "SELECT json_build_object('order_number', order_number, 'account_phone', account_phone, 'account_phone_digits', regexp_replace(COALESCE(account_phone,''), '[^0-9]', '', 'g'), 'user_id', user_id, 'event_id', event_id)::text FROM posh_orders WHERE order_number = '$order_num';" || true
  db_scalar "SELECT json_build_object('id', id, 'phone', phone, 'phone_digits', regexp_replace(phone, '[^0-9]', '', 'g'), 'last_login_at', last_login_at)::text FROM users WHERE regexp_replace(phone, '[^0-9]', '', 'g') IN ('$digits', '$local_digits', ('1' || '$local_digits')) ORDER BY last_login_at DESC NULLS LAST LIMIT 5;" || true
}

ADMIN_TOKEN="${SMOKE_ADMIN_TOKEN:-}"
if [[ -z "$ADMIN_TOKEN" ]]; then
  admin_login_payload="$(jq -nc --arg email "$SMOKE_ADMIN_EMAIL" --arg password "$SMOKE_ADMIN_PASSWORD" '{email:$email,password:$password}')"
  login_resp="$(post_json "/admin/auth/login" "$admin_login_payload")"
  ADMIN_TOKEN="$(echo "$login_resp" | jq -r '.accessToken // empty')"
  if [[ -z "$ADMIN_TOKEN" ]]; then
    login_error="$(echo "$login_resp" | jq -r '.error // .message // "unknown"')"
    if [[ "$login_error" == "Too many login attempts, please try again later" ]]; then
      log_error "Admin login rate limited (429). Provide SMOKE_ADMIN_TOKEN to bypass login during cooldown."
    fi
    log_error "Admin login failed: $(echo "$login_resp" | jq -c '.')"
    exit 1
  fi
else
  log_info "Using provided SMOKE_ADMIN_TOKEN; skipping admin login"
fi

create_event_payload="$(jq -nc \
  --arg name "$EVENT_NAME" \
  --arg venueName "$VENUE_NAME" \
  --arg venueAddress "$VENUE_ADDR" \
  --arg startTime "$START_TIME" \
  --arg endTime "$END_TIME" \
  --arg description "Reconciliation smoke test event" \
  --arg poshEventId "$POSH_EVENT_ID" \
  '{name:$name,venueName:$venueName,venueAddress:$venueAddress,startTime:$startTime,endTime:$endTime,description:$description,poshEventId:$poshEventId}')"
create_event_resp="$(post_json "/admin/events" "$create_event_payload" "Authorization: Bearer $ADMIN_TOKEN")"
EVENT_ID="$(echo "$create_event_resp" | jq -r '.event.id // empty')"
if [[ -z "$EVENT_ID" ]]; then
  log_error "Event creation failed: $(echo "$create_event_resp" | jq -c '.')"
  exit 1
fi

log_success "Created test event $EVENT_ID (poshEventId=$POSH_EVENT_ID)"

# Force-publish reconciliation smoke events so they appear in UI event lists.
# We do this via DB because the admin publish gate requires images.
event_status=$(db_scalar "UPDATE events SET status = 'published' WHERE id = '$EVENT_ID' RETURNING status;")
require_equals "Reconciliation event status" "$event_status" "published"

ORDER_A="recon-${ENV_NAME}-a-$(date +%s)"
ORDER_B="recon-${ENV_NAME}-b-$(date +%s)"
NOW_ISO="$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"

webhook_new_order() {
  local phone="$1"
  local order_num="$2"
  local payload
  payload=$(cat <<EOF
{"type":"new_order","account_first_name":"Recon","account_last_name":"Test","account_email":"recon+${order_num}@example.com","account_phone":"${phone}","account_instagram":"","event_name":"${EVENT_NAME}","event_start":"${START_TIME}","event_end":"${END_TIME}","event_id":"${POSH_EVENT_ID}","items":[{"item_id":"600000000000000000000001","name":"Recon Ticket","price":10}],"date_purchased":"${NOW_ISO}","promo_code":"RECON","subtotal":10,"total":11,"tracking_link":"recon-track","order_number":"${order_num}","update_date":"${NOW_ISO}","cancelled":false,"refunded":false,"disputed":false,"partialRefund":0,"custom_fields":[{"type":"input","answer":"A","prompt":"Q"}],"isInPersonOrder":false}
EOF
)

  local code
  code=$(curl -sS --connect-timeout 10 --max-time 30 -o /dev/null -w "%{http_code}" \
    -H "Content-Type: application/json" \
    -H "Posh-Secret: $SMOKE_POSH_SECRET" \
    -d "$payload" \
    "$BASE_URL/webhook/posh" || true)
  require_equals "Webhook new_order ($phone)" "$code" "200"
}

ORDER_NUMBERS=()
if [[ "$RUN_PHONE_A" == "true" ]]; then
  webhook_new_order "$PHONE_A" "$ORDER_A"
  ORDER_NUMBERS+=("'$ORDER_A'")
fi
if [[ "$RUN_PHONE_B" == "true" ]]; then
  webhook_new_order "$PHONE_B" "$ORDER_B"
  ORDER_NUMBERS+=("'$ORDER_B'")
fi

ORDERS_IN_CLAUSE="$(IFS=,; echo "${ORDER_NUMBERS[*]}")"
expected_unlinked="${#ORDER_NUMBERS[@]}"
pre_signup_unlinked=$(db_scalar "SELECT COUNT(*) FROM posh_orders WHERE order_number IN ($ORDERS_IN_CLAUSE) AND user_id IS NULL;")
require_equals "Pre-signup unlinked posh_orders" "$pre_signup_unlinked" "$expected_unlinked"

automated_signup() {
  local phone="$1"

  request_payload="$(jq -nc --arg phone "$phone" '{phone:$phone}')"
  request_resp="$(post_json "/auth/request-code" "$request_payload")"
  dev_code="$(echo "$request_resp" | jq -r '.devCode // empty')"
  if [[ -z "$dev_code" ]]; then
    log_error "No devCode returned for $phone. Use --partial-manual when Twilio Verify is active."
    FAILURES=$((FAILURES + 1))
    return
  fi

  verify_payload="$(jq -nc --arg phone "$phone" --arg code "$dev_code" '{phone:$phone,code:$code}')"
  verify_resp="$(post_json "/auth/verify-code" "$verify_payload")"
  verify_token="$(echo "$verify_resp" | jq -r '.accessToken // empty')"
  if [[ -z "$verify_token" ]]; then
    log_error "verify-code failed for $phone: $(echo "$verify_resp" | jq -c '.')"
    FAILURES=$((FAILURES + 1))
    return
  fi
  log_success "Automated verify-code succeeded for $phone"
}

run_phone_flow() {
  local phone="$1"
  local order_num="$2"
  local label="$3"

  if [[ "$PARTIAL_MANUAL" == "true" ]]; then
    manual_reconcile_phone "$phone" "$order_num" "$label"
  else
    automated_signup "$phone"
  fi

  local linked
  linked=$(db_scalar "SELECT COUNT(*) FROM posh_orders WHERE order_number = '$order_num' AND user_id IS NOT NULL;")
  require_equals "Order $label linked to user" "$linked" "1"

  if [[ "$linked" != "1" ]]; then
    print_link_debug "$order_num" "$phone"
  fi

  local tickets
  tickets=$(db_scalar "SELECT COUNT(*) FROM tickets t JOIN posh_orders p ON p.user_id = t.user_id AND p.event_id = t.event_id WHERE p.order_number = '$order_num' AND t.status NOT IN ('cancelled','refunded');")
  require_equals "Order $label active tickets" "$tickets" "1"
}

if [[ "$RUN_PHONE_A" == "true" ]]; then
  run_phone_flow "$PHONE_A" "$ORDER_A" "A"
fi

if [[ "$RUN_PHONE_A" == "true" && "$RUN_PHONE_B" == "true" ]]; then
  log_info "Phone A verification is complete. Ensure you fully log out before signing in as $PHONE_B"
fi

if [[ "$RUN_PHONE_B" == "true" ]]; then
  run_phone_flow "$PHONE_B" "$ORDER_B" "B"
fi

echo ""
if [[ "$FAILURES" -gt 0 ]]; then
  log_error "Reconciliation smoke failed ($FAILURES failure(s))"
  exit 1
fi

log_success "Reconciliation smoke passed"
log_info "Event ID: $EVENT_ID"
log_info "Posh Event ID: $POSH_EVENT_ID"
log_info "Order numbers: $ORDER_A, $ORDER_B"
