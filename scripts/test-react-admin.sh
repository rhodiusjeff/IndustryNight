#!/bin/bash
# scripts/test-react-admin.sh
# Standalone test runner for packages/react-admin/
# Usage: ./scripts/test-react-admin.sh LANE_ID [--port 3630] [--local-only] [--skip-build] [--env dev|prod]

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REACT_ADMIN_DIR="$PROJECT_ROOT/packages/react-admin"
API_DIR="$PROJECT_ROOT/packages/api"
LOG_DIR="$PROJECT_ROOT/test_logs"
mkdir -p "$LOG_DIR"

LANE_ID="${1:-B0}"; shift 2>/dev/null || true
PORT=3630
LOCAL_ONLY=false
SKIP_BUILD=false
ENV="dev"
LOCAL_API_PID=""
PG_CONTAINER="pg-react-admin-test"

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --port)       PORT="$2"; shift ;;
    --local-only) LOCAL_ONLY=true ;;
    --skip-build) SKIP_BUILD=true ;;
    --env)        ENV="$2"; shift ;;
  esac
  shift
done

TIMESTAMP=$(date +"%Y-%m-%d_%H%M%S")
LOG_FILE="$LOG_DIR/${LANE_ID}_react-admin_${TIMESTAMP}.log"
exec > >(tee -a "$LOG_FILE") 2>&1

PASS=0; FAIL=0; OVERALL_FAIL=false
phase() { echo; echo "════════════════════════════════"; echo "  Phase $1 — $2"; echo "════════════════════════════════"; }
ok()    { echo "[PASS] $1"; PASS=$((PASS+1)); }
fail()  { echo "[FAIL] $1"; FAIL=$((FAIL+1)); OVERALL_FAIL=true; }

cleanup() {
  [ -n "$LOCAL_API_PID" ] && kill "$LOCAL_API_PID" 2>/dev/null || true
  docker rm -f "$PG_CONTAINER" 2>/dev/null || true
  # Kill any React admin dev server started by this script
  lsof -ti tcp:"$PORT" | xargs kill -9 2>/dev/null || true
}
trap cleanup EXIT

# ── Phase 1: Type check ──────────────────────────────────────────────────────
phase 1 "TypeScript type check"
cd "$REACT_ADMIN_DIR"
if npm run type-check; then ok "type-check"; else fail "type-check"; fi

# ── Phase 2: Unit tests ───────────────────────────────────────────────────────
phase 2 "Unit tests (Vitest)"
cd "$REACT_ADMIN_DIR"
if npm test -- --run; then ok "unit tests"; else fail "unit tests"; fi

# ── Phase 3: Local E2E ────────────────────────────────────────────────────────
phase 3 "Local E2E (Docker PG + local API + React admin port $PORT)"

echo "[INFO] Starting Docker PG..."
docker rm -f "$PG_CONTAINER" 2>/dev/null || true
docker run -d --name "$PG_CONTAINER" \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=industrynight \
  -p 5432:5432 postgres:15
sleep 4

echo "[INFO] Applying migrations..."
DB_HOST=localhost DB_PORT=5432 DB_NAME=industrynight DB_USER=postgres \
DB_PASSWORD=postgres DB_SSL=false node "$PROJECT_ROOT/scripts/migrate.js" --skip-k8s

echo "[INFO] Starting local API on port 3000..."
cd "$API_DIR"
DB_HOST=localhost DB_PORT=5432 DB_NAME=industrynight DB_USER=postgres \
DB_PASSWORD=postgres DB_SSL=false JWT_SECRET=test-secret-for-local-e2e-run \
ENABLE_MAGIC_TEST_PREFIX=true \
npm run dev &
LOCAL_API_PID=$!
sleep 5

echo "[INFO] Starting React admin on port $PORT (local API)..."
cd "$REACT_ADMIN_DIR"
NEXT_PUBLIC_API_URL=http://localhost:3000 PORT=$PORT npm run dev &
sleep 8

echo "[INFO] Running Playwright E2E (local)..."
PLAYWRIGHT_BASE_URL="http://localhost:$PORT" \
TEST_ADMIN_EMAIL="${TEST_ADMIN_EMAIL:-}" \
TEST_ADMIN_PASSWORD="${TEST_ADMIN_PASSWORD:-}" \
npx playwright test
if [ $? -eq 0 ]; then ok "local E2E"; else fail "local E2E"; fi

# Sanity gate — stop before AWS if local failed
if [ "$OVERALL_FAIL" = true ]; then
  echo
  echo "❌ SANITY GATE FAILED — local E2E did not pass. Skipping AWS phases."
  echo "  RESULT: $PASS passed, $FAIL failed"
  echo "  Log: $LOG_FILE"
  exit 1
fi

cleanup
LOCAL_API_PID=""

# ── Phase 4: AWS E2E ──────────────────────────────────────────────────────────
if [ "$LOCAL_ONLY" = true ]; then
  echo "[SKIP] Phase 4 — AWS E2E skipped (--local-only)"
else
  phase 4 "AWS E2E (React admin → dev API at dev-api.industrynight.net)"

  if [ "$ENV" = "prod" ]; then
    AWS_API_URL="https://api.industrynight.net"
  else
    AWS_API_URL="https://dev-api.industrynight.net"
  fi

  echo "[INFO] Starting React admin on port $PORT (AWS API: $AWS_API_URL)..."
  cd "$REACT_ADMIN_DIR"
  NEXT_PUBLIC_API_URL="$AWS_API_URL" PORT=$PORT npm run dev &
  sleep 8

  echo "[INFO] Running Playwright E2E (AWS)..."
  PLAYWRIGHT_BASE_URL="http://localhost:$PORT" \
  TEST_ADMIN_EMAIL="${TEST_ADMIN_EMAIL:-}" \
  TEST_ADMIN_PASSWORD="${TEST_ADMIN_PASSWORD:-}" \
  npx playwright test
  if [ $? -eq 0 ]; then ok "AWS E2E"; else fail "AWS E2E"; fi
fi

# ── Phase 5: Build check ──────────────────────────────────────────────────────
if [ "$SKIP_BUILD" = true ]; then
  echo "[SKIP] Phase 5 — build skipped"
else
  phase 5 "Production build check"
  cd "$REACT_ADMIN_DIR"
  if npm run build; then ok "build"; else fail "build"; fi
fi

echo
echo "══════════════════════════════════════════"
echo "  RESULT: $PASS passed, $FAIL failed"
echo "  Log: $LOG_FILE"
echo "══════════════════════════════════════════"
[ "$FAIL" -eq 0 ]
