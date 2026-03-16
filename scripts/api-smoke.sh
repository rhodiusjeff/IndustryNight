#!/bin/bash
set -euo pipefail

# api-smoke.sh — Fast post-deploy smoke checks for API availability
#
# Usage:
#   ./scripts/api-smoke.sh [--env dev|prod]
#   ./scripts/api-smoke.sh [--env dev|prod] --require-twilio-verify
#
# Optional environment variables for extended checks:
#   SMOKE_TEST_PHONE=+15555550199
#   SMOKE_ADMIN_EMAIL=admin@industrynight.net
#   SMOKE_ADMIN_PASSWORD=secret

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/coop/config.sh"

parse_env_flag "$@"
set -- "${PASSTHROUGH_ARGS[@]+"${PASSTHROUGH_ARGS[@]}"}"
load_environment "$IN_ENV"

REQUIRE_TWILIO_VERIFY=false

print_usage() {
  cat <<'EOF'
Usage:
  ./scripts/api-smoke.sh [--env dev|prod]
  ./scripts/api-smoke.sh [--env dev|prod] --require-twilio-verify

Options:
  --env dev|prod            Target environment (defaults to dev)
  --require-twilio-verify   Fail if /auth/request-code still returns devCode
  --help, -h, -?            Show this help message

Optional environment variables:
  SMOKE_TEST_PHONE          Runs /auth/request-code check when set
  SMOKE_ADMIN_EMAIL         Admin login email for admin endpoint check
  SMOKE_ADMIN_PASSWORD      Admin login password for admin endpoint check
EOF
}

for arg in "$@"; do
  case "$arg" in
    --require-twilio-verify) REQUIRE_TWILIO_VERIFY=true ;;
    --help|-h|-?) print_usage; exit 0 ;;
    *) log_error "Unknown option: $arg"; exit 1 ;;
  esac
done

if ! command -v curl >/dev/null 2>&1; then
  log_error "curl is required"
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  log_error "jq is required"
  exit 1
fi

BASE_URL="https://${API_HOST}"
FAILURES=0

check_json_endpoint() {
  local name="$1"
  local path="$2"
  local body_file
  body_file="$(mktemp)"

  local code
  code=$(curl -sS --connect-timeout 10 --max-time 20 -o "$body_file" -w "%{http_code}" "$BASE_URL$path" || true)

  if [[ "$code" != "200" ]]; then
    log_error "$name failed (HTTP $code)"
    echo "  URL: $BASE_URL$path"
    echo "  Body: $(cat "$body_file" 2>/dev/null || true)"
    FAILURES=$((FAILURES + 1))
    rm -f "$body_file"
    return
  fi

  if ! jq -e . "$body_file" >/dev/null 2>&1; then
    log_error "$name returned non-JSON response"
    FAILURES=$((FAILURES + 1))
    rm -f "$body_file"
    return
  fi

  log_success "$name (HTTP 200)"
  rm -f "$body_file"
}

echo "=== API Smoke Tests ($ENV_NAME) ==="
echo "Base URL: $BASE_URL"
echo ""

check_json_endpoint "Health" "/health"
check_json_endpoint "Specialties" "/specialties"
check_json_endpoint "Markets" "/markets"

if [[ -n "${SMOKE_TEST_PHONE:-}" ]]; then
  echo ""
  log_info "Running auth request-code smoke check..."
  auth_body="$(mktemp)"
  auth_code=$(curl -sS --connect-timeout 10 --max-time 20 \
    -H "Content-Type: application/json" \
    -d "{\"phone\":\"${SMOKE_TEST_PHONE}\"}" \
    -o "$auth_body" -w "%{http_code}" \
    "$BASE_URL/auth/request-code" || true)

  if [[ "$auth_code" != "200" ]]; then
    log_error "Auth request-code failed (HTTP $auth_code)"
    echo "  Body: $(cat "$auth_body" 2>/dev/null || true)"
    FAILURES=$((FAILURES + 1))
  else
    if jq -e '.message == "Verification code sent"' "$auth_body" >/dev/null 2>&1; then
      log_success "Auth request-code (HTTP 200)"
    else
      log_error "Auth request-code returned unexpected payload"
      echo "  Body: $(cat "$auth_body" 2>/dev/null || true)"
      FAILURES=$((FAILURES + 1))
    fi

    if [[ "$REQUIRE_TWILIO_VERIFY" == "true" ]]; then
      if jq -e 'has("devCode")' "$auth_body" >/dev/null 2>&1; then
        log_error "Twilio Verify not active: response still contains devCode"
        FAILURES=$((FAILURES + 1))
      else
        log_success "Twilio Verify mode active (no devCode in response)"
      fi
    fi
  fi

  rm -f "$auth_body"
else
  echo ""
  log_info "Skipping auth smoke check (set SMOKE_TEST_PHONE to enable)"
fi

if [[ -n "${SMOKE_ADMIN_EMAIL:-}" && -n "${SMOKE_ADMIN_PASSWORD:-}" ]]; then
  echo ""
  log_info "Running admin auth/dashboard smoke check..."
  login_body="$(mktemp)"
  login_code=$(curl -sS --connect-timeout 10 --max-time 20 \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"${SMOKE_ADMIN_EMAIL}\",\"password\":\"${SMOKE_ADMIN_PASSWORD}\"}" \
    -o "$login_body" -w "%{http_code}" \
    "$BASE_URL/admin/auth/login" || true)

  if [[ "$login_code" != "200" ]]; then
    log_error "Admin login failed (HTTP $login_code)"
    echo "  Body: $(cat "$login_body" 2>/dev/null || true)"
    FAILURES=$((FAILURES + 1))
  else
    token=$(jq -r '.accessToken // empty' "$login_body")
    if [[ -z "$token" ]]; then
      log_error "Admin login payload missing accessToken"
      FAILURES=$((FAILURES + 1))
    else
      dash_body="$(mktemp)"
      dash_code=$(curl -sS --connect-timeout 10 --max-time 20 \
        -H "Authorization: Bearer $token" \
        -o "$dash_body" -w "%{http_code}" \
        "$BASE_URL/admin/dashboard" || true)

      if [[ "$dash_code" == "200" ]]; then
        log_success "Admin dashboard (HTTP 200)"
      else
        log_error "Admin dashboard failed (HTTP $dash_code)"
        echo "  Body: $(cat "$dash_body" 2>/dev/null || true)"
        FAILURES=$((FAILURES + 1))
      fi

      rm -f "$dash_body"
    fi
  fi

  rm -f "$login_body"
else
  echo ""
  log_info "Skipping admin smoke check (set SMOKE_ADMIN_EMAIL and SMOKE_ADMIN_PASSWORD to enable)"
fi

echo ""
if [[ "$FAILURES" -gt 0 ]]; then
  log_error "Smoke tests failed ($FAILURES failure(s))"
  exit 1
fi

log_success "All smoke tests passed"
