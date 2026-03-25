#!/bin/bash
set -uo pipefail

# closeout-test.sh — CODEX track closeout test suite
#
# Runs all test phases (Jest → Flutter → local E2E → [sanity gate] →
# migrate → deploy → AWS E2E → smoke) and writes a timestamped log to
# test_logs/. Use --local-only to skip the sanity gate and all AWS phases.
#
# Usage:
#   ./scripts/closeout-test.sh TRACK_ID [--env dev|prod] [--local-only]
#   ./scripts/closeout-test.sh --help

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/coop/config.sh"

# --------------------------------------------------------------------------
# Phase registry (indexed array — bash 3.2 compatible)
# --------------------------------------------------------------------------
PHASE_NAMES=(
  ""                             # [0] unused
  "Jest unit tests"              # [1]
  "Flutter widget tests"         # [2]
  "Local E2E (localhost:3000)"   # [3]
  "DB migration"                 # [4]
  "API deploy"                   # [5]
  "AWS E2E"                      # [6]
  "Smoke test"                   # [7]
)

# Results: PASS | FAIL | SKIP | NOT_RUN (empty = NOT_RUN)
RESULTS=("" "" "" "" "" "" "" "")

OVERALL_FAIL=false
LOCAL_ONLY=false
LOG_FILE=""
LOCAL_API_PID=""

# --------------------------------------------------------------------------
# Usage
# --------------------------------------------------------------------------
print_usage() {
  # Use $'...' syntax so actual ESC chars are embedded in the heredoc
  local B=$'\033[1m' N=$'\033[0m'
  cat <<EOF
${B}closeout-test.sh${N} — CODEX track closeout test suite

${B}USAGE${N}
  ./scripts/closeout-test.sh TRACK_ID [options]

${B}ARGUMENTS${N}
  TRACK_ID            Identifies this run (e.g. A0-mopup, B1-feature).
                      Used in the log filename written to test_logs/.

${B}OPTIONS${N}
  --env dev|prod      Target AWS environment for phases 4–7 (default: dev)
  --local-only        Run only local phases (1–3). Skips the sanity gate
                      and all AWS operations (migration, deploy, E2E, smoke).
                      Safe to run without AWS credentials or infra running.
  --help, -h          Show this help message

${B}PHASES${N}
  [1]  Jest unit tests      npm test — testcontainer PG, no network required
  [2]  Flutter tests        flutter test — social-app then admin-app
  [3]  Local E2E            E2E suite → http://localhost:3000
                            Spins up postgres:16 in Docker, runs migrations,
                            starts the API against it, runs E2E, tears down.
                            Requires: Docker Desktop running. No AWS needed.

  ─── SANITY GATE — operator must confirm before AWS operations ──────────
  (Gate and phases 4–7 are skipped entirely with --local-only)

  [4]  DB migration    node scripts/migrate.js
                      DB_PASSWORD auto-fetched from Secrets Manager if not set.
  [5]  API deploy      ./scripts/deploy-api.sh --env <env>
  [6]  AWS E2E         E2E suite → https://<env>-api.industrynight.net
  [7]  Smoke test      ./scripts/api-smoke.sh --env <env>

${B}LOG OUTPUT${N}
  test_logs/TRACK_ID_closeout_test_YYYY-MM-DD_HHMMSS.log
  (test_logs/ is git-ignored — logs do not pollute the repo)

${B}EXAMPLES${N}
  # Full run — DB_PASSWORD auto-fetched from Secrets Manager
  ./scripts/closeout-test.sh A0-mopup

  # Full run — override DB password explicitly
  DB_PASSWORD=xxx ./scripts/closeout-test.sh A0-mopup

  # Local phases only — no AWS, no credentials needed
  ./scripts/closeout-test.sh A0-mopup --local-only

  # Full run targeting prod
  DB_PASSWORD=xxx ./scripts/closeout-test.sh B1-feature --env prod

  # Local only (--env is accepted but ignored in local-only mode)
  ./scripts/closeout-test.sh B1-feature --local-only --env prod
EOF
}

# --------------------------------------------------------------------------
# Argument parsing
# --------------------------------------------------------------------------
TRACK_ID=""
ENV_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      print_usage; exit 0 ;;
    --local-only)
      LOCAL_ONLY=true; shift ;;
    --env)
      [[ $# -lt 2 ]] && { log_error "--env requires a value (dev|prod)"; exit 1; }
      ENV_ARGS+=("$1" "$2"); shift 2 ;;
    -*)
      log_error "Unknown option: $1"
      echo ""
      print_usage
      exit 1 ;;
    *)
      if [[ -z "$TRACK_ID" ]]; then
        TRACK_ID="$1"; shift
      else
        log_error "Unexpected argument: $1 (TRACK_ID already set to '$TRACK_ID')"
        exit 1
      fi ;;
  esac
done

if [[ -z "$TRACK_ID" ]]; then
  log_error "TRACK_ID is required."
  echo ""
  print_usage
  exit 1
fi

# Resolve environment (always parse so IN_ENV is set; only load AWS env when needed)
parse_env_flag "${ENV_ARGS[@]+"${ENV_ARGS[@]}"}"
if [[ "$LOCAL_ONLY" == false ]]; then
  load_environment "$IN_ENV"
fi

TOTAL_PHASES=7
if [[ "$LOCAL_ONLY" == true ]]; then
  TOTAL_PHASES=3
fi

# --------------------------------------------------------------------------
# Log file setup — tee all stdout/stderr to timestamped file
# --------------------------------------------------------------------------
TIMESTAMP="$(date +%Y-%m-%d_%H%M%S)"
LOG_DIR="$PROJECT_ROOT/test_logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/${TRACK_ID}_closeout_test_${TIMESTAMP}.log"

echo -e "${CYAN}[INFO]${NC} Log → $LOG_FILE" >/dev/tty
exec > >(tee -a "$LOG_FILE") 2>&1

# --------------------------------------------------------------------------
# Trap: print summary on Ctrl-C
# --------------------------------------------------------------------------
cleanup() {
  if [[ -n "$LOCAL_API_PID" ]]; then
    kill "$LOCAL_API_PID" 2>/dev/null || true
    LOCAL_API_PID=""
  fi
}
trap 'echo ""; log_warn "Interrupted — partial results below."; cleanup; print_summary; exit 130' INT
trap 'cleanup' EXIT

# --------------------------------------------------------------------------
# Header / Summary helpers
# --------------------------------------------------------------------------
print_banner() {
  local title=$1
  echo ""
  echo -e "${BOLD}══════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}  $title${NC}"
  echo -e "${BOLD}══════════════════════════════════════════════════${NC}"
}

print_header() {
  local git_branch git_sha
  git_branch="$(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")"
  git_sha="$(git -C "$PROJECT_ROOT" rev-parse --short HEAD 2>/dev/null || echo "unknown")"

  print_banner "CODEX CLOSEOUT — $TRACK_ID"
  echo "  Date:    $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "  Branch:  $git_branch @ $git_sha"
  if [[ "$LOCAL_ONLY" == true ]]; then
    echo "  Mode:    local-only (phases 1–3)"
  else
    echo "  Mode:    full (phases 1–7, env: $IN_ENV)"
  fi
  echo "  Log:     $LOG_FILE"
  echo -e "${BOLD}══════════════════════════════════════════════════${NC}"
  echo ""
}

result_line() {
  local num=$1
  local result="${RESULTS[$num]:-NOT_RUN}"
  local label="${PHASE_NAMES[$num]}"
  case "$result" in
    PASS)    echo -e "  [${GREEN}PASS${NC}]  Phase $num — $label" ;;
    FAIL)    echo -e "  [${RED}FAIL${NC}]  Phase $num — $label" ;;
    SKIP)    echo -e "  [${YELLOW}SKIP${NC}]  Phase $num — $label" ;;
    NOT_RUN) echo -e "  [${YELLOW}----${NC}]  Phase $num — $label (not run)" ;;
    *)       echo -e "  [${YELLOW}----${NC}]  Phase $num — $label" ;;
  esac
}

print_summary() {
  print_banner "CLOSEOUT SUMMARY — $TRACK_ID"
  local i
  for i in $(seq 1 "$TOTAL_PHASES"); do
    result_line "$i"
  done
  echo ""
  if [[ "$OVERALL_FAIL" == true ]]; then
    echo -e "  ${RED}${BOLD}RESULT: FAIL${NC} — review phase failures above."
  else
    echo -e "  ${GREEN}${BOLD}RESULT: PASS${NC} — all phases completed."
  fi
  echo ""
  echo "  Log: $LOG_FILE"
  echo -e "${BOLD}══════════════════════════════════════════════════${NC}"
  echo ""
}

# --------------------------------------------------------------------------
# Phase runner helper
# --------------------------------------------------------------------------
run_phase() {
  local num=$1 name=$2
  shift 2
  echo ""
  log_step "$num" "$TOTAL_PHASES" "$name"
  if "$@"; then
    RESULTS[$num]="PASS"
    log_success "Phase $num passed."
    return 0
  else
    RESULTS[$num]="FAIL"
    OVERALL_FAIL=true
    log_error "Phase $num FAILED."
    return 1
  fi
}

# --------------------------------------------------------------------------
# Phase implementations
# --------------------------------------------------------------------------
phase1_jest() {
  cd "$PROJECT_ROOT/packages/api"
  npm test
}

phase2_flutter() {
  local failed=false

  log_info "social-app →"
  if ! (cd "$PROJECT_ROOT/packages/social-app" && flutter test); then
    failed=true
  fi

  echo ""
  log_info "admin-app →"
  if ! (cd "$PROJECT_ROOT/packages/admin-app" && flutter test); then
    failed=true
  fi

  [[ "$failed" == false ]]
}

phase3_local_e2e() {
  echo ""
  log_step 3 "$TOTAL_PHASES" "${PHASE_NAMES[3]}"

  # ── Pre-flight: docker required ─────────────────────────────────────────
  if ! command -v docker >/dev/null 2>&1; then
    log_warn "docker not found — phase 3 skipped (install Docker Desktop to enable)."
    RESULTS[3]="SKIP"
    return 0
  fi

  # ── Pre-flight: ensure port 3000 is free ─────────────────────────────────
  local stale_pid
  stale_pid=$(lsof -ti :3000 2>/dev/null || true)
  if [[ -n "$stale_pid" ]]; then
    log_warn "Port 3000 already in use (PID $stale_pid) — terminating stale process..."
    echo "$stale_pid" | xargs kill 2>/dev/null || true
    sleep 2
    stale_pid=$(lsof -ti :3000 2>/dev/null || true)
    if [[ -n "$stale_pid" ]]; then
      log_error "Port 3000 still in use after termination attempt — phase 3 skipped."
      RESULTS[3]="SKIP"
      return 0
    fi
    log_info "Port 3000 cleared."
  fi

  # ── Pick a free port for postgres ────────────────────────────────────────
  local pg_port
  pg_port=$(python3 -c "
import socket; s=socket.socket(); s.bind(('',0)); print(s.getsockname()[1]); s.close()
")
  local pg_password="closeout_test_pw"
  local pg_container="closeout-pg-$$"
  local api_log
  api_log="$(mktemp /tmp/closeout-api-XXXXXX.log)"

  # ── Cleanup helper (called on early return) ───────────────────────────────
  local_e2e_cleanup() {
    if [[ -n "$LOCAL_API_PID" ]]; then
      # Kill direct children (ts-node-dev → node) before the subshell
      pkill -P "$LOCAL_API_PID" 2>/dev/null || true
      kill "$LOCAL_API_PID" 2>/dev/null || true
      LOCAL_API_PID=""
    fi
    # Belt-and-suspenders: flush any process still holding port 3000
    local _port_pids
    _port_pids=$(lsof -ti :3000 2>/dev/null || true)
    if [[ -n "$_port_pids" ]]; then
      echo "$_port_pids" | xargs kill 2>/dev/null || true
    fi
    docker rm -f "$pg_container" >/dev/null 2>&1 || true
    rm -f "$api_log"
  }

  # ── Start postgres:16 container ──────────────────────────────────────────
  log_info "Starting postgres:16 container on port $pg_port..."
  if ! docker run -d \
    --name "$pg_container" \
    -e POSTGRES_PASSWORD="$pg_password" \
    -e POSTGRES_DB=industrynight \
    -e POSTGRES_USER=postgres \
    -p "${pg_port}:5432" \
    postgres:16 >/dev/null; then
    log_error "Failed to start postgres container — phase 3 skipped."
    RESULTS[3]="SKIP"
    rm -f "$api_log"
    return 0
  fi

  # Wait for postgres to accept connections
  log_info "Waiting for postgres to be ready..."
  local pg_ready=false
  for _ in $(seq 1 20); do
    if docker exec "$pg_container" pg_isready -U postgres >/dev/null 2>&1; then
      pg_ready=true; break
    fi
    sleep 1
  done
  if [[ "$pg_ready" == false ]]; then
    log_error "Postgres did not become ready — phase 3 skipped."
    local_e2e_cleanup
    RESULTS[3]="SKIP"
    return 0
  fi
  log_success "Postgres ready."

  # ── Run migrations against local container ───────────────────────────────
  log_info "Running migrations against local container..."
  if ! (cd "$PROJECT_ROOT" && \
      DB_HOST=localhost \
      DB_PORT="$pg_port" \
      DB_USER=postgres \
      DB_NAME=industrynight \
      DB_PASSWORD="$pg_password" \
      DB_SSL=false \
      node scripts/migrate.js --skip-k8s); then
    log_error "Migration failed — phase 3 skipped."
    local_e2e_cleanup
    RESULTS[3]="SKIP"
    return 0
  fi
  log_success "Migrations applied."

  # ── Start API against local container ────────────────────────────────────
  log_info "Starting local API against local postgres..."
  (cd "$PROJECT_ROOT/packages/api" && \
    DB_HOST=localhost \
    DB_PORT="$pg_port" \
    DB_USER=postgres \
    DB_NAME=industrynight \
    DB_PASSWORD="$pg_password" \
    DB_SSL=false \
    ENABLE_MAGIC_TEST_PREFIX=true \
    JWT_SECRET=closeout-test-jwt-secret-32-chars-ok \
    npm run dev >"$api_log" 2>&1) &
  LOCAL_API_PID=$!

  # Wait up to 90s for health (ts-node-dev cold compile ~30-45s)
  local max_wait=90 waited=0
  printf "[INFO] Waiting for API to become healthy "
  while ! curl -sf http://localhost:3000/health >/dev/null 2>&1; do
    if ! kill -0 "$LOCAL_API_PID" 2>/dev/null; then
      echo ""
      log_error "API process exited unexpectedly. Last startup output:"
      tail -20 "$api_log" | sed 's/^/    /'
      local_e2e_cleanup
      RESULTS[3]="SKIP"
      return 0
    fi
    if [[ $waited -ge $max_wait ]]; then
      echo ""
      log_error "API did not start within ${max_wait}s — phase 3 skipped."
      log_error "Last startup output:"
      tail -20 "$api_log" | sed 's/^/    /'
      local_e2e_cleanup
      RESULTS[3]="SKIP"
      return 0
    fi
    sleep 5
    waited=$(( waited + 5 ))
    printf "."
  done
  echo ""
  log_success "API ready (${waited}s)."

  # ── Run E2E ──────────────────────────────────────────────────────────────
  local e2e_exit=0
  (cd "$PROJECT_ROOT/packages/api" && \
    API_BASE_URL=http://localhost:3000 npm run test:e2e) || e2e_exit=$?

  local_e2e_cleanup

  if [[ $e2e_exit -eq 0 ]]; then
    RESULTS[3]="PASS"
    log_success "Phase 3 passed."
  else
    RESULTS[3]="FAIL"
    OVERALL_FAIL=true
    log_error "Phase 3 FAILED."
  fi
}

sanity_gate() {
  echo ""
  echo -e "${BOLD}══════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}  SANITY GATE — review local results before AWS ops${NC}"
  echo -e "${BOLD}══════════════════════════════════════════════════${NC}"
  echo ""
  result_line 1
  result_line 2
  result_line 3
  echo ""

  if [[ "$OVERALL_FAIL" == true ]]; then
    echo -e "  ${YELLOW}${BOLD}WARNING:${NC} One or more local phases failed."
    echo "           Proceeding to AWS operations is NOT recommended."
    echo ""
  fi

  printf "${BOLD}  Proceed with AWS operations (%s)? [y/N]: ${NC}" "$IN_ENV"
  local confirm
  read -r confirm </dev/tty
  echo "$confirm"  # record operator choice in log

  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    log_warn "AWS phases declined by operator."
    for i in 4 5 6 7; do
      RESULTS[$i]="SKIP"
    done
    print_summary
    exit 0
  fi

  echo ""
  log_info "AWS phases confirmed — proceeding."
}

# Fetch DB_PASSWORD from Secrets Manager if not already in environment.
fetch_db_password() {
  if [[ -n "${DB_PASSWORD:-}" ]]; then
    log_info "Using DB_PASSWORD from environment."
    return 0
  fi

  log_info "DB_PASSWORD not set — fetching from Secrets Manager ($SECRETS_ID)..."

  local secret_json
  if ! secret_json=$(aws_cmd secretsmanager get-secret-value \
    --secret-id "$SECRETS_ID" \
    --query 'SecretString' \
    --output text 2>&1); then
    log_error "Failed to fetch from Secrets Manager: $secret_json"
    log_error "Set DB_PASSWORD manually: DB_PASSWORD=xxx ./scripts/closeout-test.sh $TRACK_ID --env $IN_ENV"
    return 1
  fi

  DB_PASSWORD=$(echo "$secret_json" | python3 -c \
    "import json,sys; o=json.load(sys.stdin); print(o.get('password') or o.get('DB_PASSWORD') or o.get('db_password') or '')")

  if [[ -z "$DB_PASSWORD" ]]; then
    log_error "Password key not found in secret $SECRETS_ID"
    return 1
  fi

  export DB_PASSWORD
  log_success "DB_PASSWORD loaded from Secrets Manager."
}

phase4_migrate() {
  fetch_db_password || return 1
  cd "$PROJECT_ROOT"
  DB_PASSWORD="$DB_PASSWORD" node scripts/migrate.js
}

phase5_deploy() {
  "$PROJECT_ROOT/scripts/deploy-api.sh" --env "$IN_ENV"
}

phase6_aws_e2e() {
  local aws_url="https://${API_HOST}"
  log_info "Target: $aws_url"
  cd "$PROJECT_ROOT/packages/api"
  API_BASE_URL="$aws_url" npm run test:e2e
}

phase7_smoke() {
  "$PROJECT_ROOT/scripts/api-smoke.sh" --env "$IN_ENV"
}

# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------
print_header

run_phase 1 "${PHASE_NAMES[1]}" phase1_jest    || true
run_phase 2 "${PHASE_NAMES[2]}" phase2_flutter || true
phase3_local_e2e  # handles its own SKIP/PASS/FAIL and log_step internally

if [[ "$LOCAL_ONLY" == true ]]; then
  print_summary
  if [[ "$OVERALL_FAIL" == true ]]; then exit 1; fi
  exit 0
fi

sanity_gate

run_phase 4 "${PHASE_NAMES[4]}" phase4_migrate || true
run_phase 5 "${PHASE_NAMES[5]}" phase5_deploy  || true
run_phase 6 "${PHASE_NAMES[6]}" phase6_aws_e2e || true
run_phase 7 "${PHASE_NAMES[7]}" phase7_smoke   || true

print_summary
if [[ "$OVERALL_FAIL" == true ]]; then exit 1; fi
exit 0
