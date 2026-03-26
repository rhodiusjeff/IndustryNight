#!/bin/bash
# Standalone test runner for packages/react-admin/
# Usage: ./scripts/test-react-admin.sh LANE_ID [--port 3630] [--local-only] [--skip-build] [--env dev|prod]

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REACT_ADMIN_DIR="$PROJECT_ROOT/packages/react-admin"
API_DIR="$PROJECT_ROOT/packages/api"
LOG_DIR="$PROJECT_ROOT/test_logs"
mkdir -p "$LOG_DIR"

LANE_ID="${1:-B0}"
if [[ $# -gt 0 ]]; then
  shift
fi

PORT=3630
LOCAL_ONLY=false
SKIP_BUILD=false
ENV="dev"
LOCAL_API_PID=""
REACT_ADMIN_PID=""
PG_CONTAINER="pg-react-admin-test"
PG_PORT="${PG_PORT:-55432}"

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --port)
      PORT="$2"
      shift
      ;;
    --local-only)
      LOCAL_ONLY=true
      ;;
    --skip-build)
      SKIP_BUILD=true
      ;;
    --env)
      ENV="$2"
      shift
      ;;
    *)
      echo "Unknown argument: $1"
      exit 1
      ;;
  esac
  shift
done

TIMESTAMP=$(date +"%Y-%m-%d_%H%M%S")
LOG_FILE="$LOG_DIR/${LANE_ID}_react-admin_${TIMESTAMP}.log"
exec > >(tee -a "$LOG_FILE") 2>&1

PASS=0
FAIL=0
OVERALL_FAIL=false

phase() {
  echo
  echo "========================================"
  echo "  Phase $1 - $2"
  echo "========================================"
}

ok() {
  echo "[PASS] $1"
  PASS=$((PASS + 1))
}

fail() {
  echo "[FAIL] $1"
  FAIL=$((FAIL + 1))
  OVERALL_FAIL=true
}

cleanup() {
  if [[ -n "$REACT_ADMIN_PID" ]]; then
    kill "$REACT_ADMIN_PID" 2>/dev/null || true
  fi
  if [[ -n "$LOCAL_API_PID" ]]; then
    kill "$LOCAL_API_PID" 2>/dev/null || true
  fi
  docker rm -f "$PG_CONTAINER" 2>/dev/null || true
  lsof -ti tcp:"$PORT" | xargs kill -9 2>/dev/null || true
  lsof -ti tcp:3000 | xargs kill -9 2>/dev/null || true
}
trap cleanup EXIT

phase 1 "TypeScript type check"
cd "$REACT_ADMIN_DIR"
if npm run type-check; then ok "type-check"; else fail "type-check"; fi

phase 2 "Unit tests (Vitest)"
if npm test -- --run; then ok "unit tests"; else fail "unit tests"; fi

phase 3 "Local E2E (Docker PG + local API + React admin port $PORT)"

if [[ ! -d "$API_DIR/node_modules" ]]; then
  echo "[INFO] Installing API dependencies..."
  cd "$API_DIR"
  npm install
fi

if [[ ! -d "$REACT_ADMIN_DIR/node_modules" ]]; then
  echo "[INFO] Installing React admin dependencies..."
  cd "$REACT_ADMIN_DIR"
  npm install
fi

echo "[INFO] Starting Docker PG..."
docker rm -f "$PG_CONTAINER" 2>/dev/null || true
docker run -d --name "$PG_CONTAINER" -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=industrynight -e POSTGRES_HOST_AUTH_METHOD=trust -p "$PG_PORT":5432 postgres:15
sleep 5

echo "[INFO] Applying migrations..."
DB_HOST=localhost DB_PORT="$PG_PORT" DB_NAME=industrynight DB_USER=postgres DB_PASSWORD=postgres DB_SSL=false \
  node "$PROJECT_ROOT/scripts/migrate.js" --skip-k8s

echo "[INFO] Seeding admin account for E2E..."
DB_HOST=localhost DB_PORT="$PG_PORT" DB_NAME=industrynight DB_USER=postgres DB_PASSWORD=postgres DB_SSL=false \
  node "$PROJECT_ROOT/scripts/seed-smoke-admin.js" --create --email "smoke-admin@industrynight.test" --password "smoke-admin-password" --skip-k8s

echo "[INFO] Starting local API on port 3000..."
lsof -ti tcp:3000 | xargs kill -9 2>/dev/null || true
cd "$API_DIR"
DB_HOST=localhost DB_PORT="$PG_PORT" DB_NAME=industrynight DB_USER=postgres DB_PASSWORD=postgres DB_SSL=false JWT_SECRET=test-secret-for-local-e2e-run-1234567890123456 \
  npm run dev &
LOCAL_API_PID=$!
sleep 8

echo "[INFO] Starting React admin on port $PORT (local API)..."
cd "$REACT_ADMIN_DIR"
NEXT_PUBLIC_API_URL=http://localhost:3000 PORT="$PORT" npm run dev &
REACT_ADMIN_PID=$!
sleep 10

echo "[INFO] Running Playwright E2E (local)..."
PLAYWRIGHT_BASE_URL="http://localhost:$PORT" \
TEST_ADMIN_EMAIL="${TEST_ADMIN_EMAIL:-smoke-admin@industrynight.test}" \
TEST_ADMIN_PASSWORD="${TEST_ADMIN_PASSWORD:-smoke-admin-password}" \
npx playwright test
if [[ $? -eq 0 ]]; then ok "local E2E"; else fail "local E2E"; fi

if [[ "$OVERALL_FAIL" == true ]]; then
  echo
  echo "SANITY GATE FAILED - local checks did not pass. Skipping AWS phases."
  echo "  RESULT: $PASS passed, $FAIL failed"
  echo "  Log: $LOG_FILE"
  exit 1
fi

cleanup
LOCAL_API_PID=""
REACT_ADMIN_PID=""

if [[ "$LOCAL_ONLY" == true ]]; then
  echo "[SKIP] Phase 4 - AWS E2E skipped (--local-only)"
else
  phase 4 "AWS E2E (React admin -> dev/prod API)"

  if [[ "$ENV" == "prod" ]]; then
    AWS_API_URL="https://api.industrynight.net"
  else
    AWS_API_URL="https://dev-api.industrynight.net"
  fi

  cd "$REACT_ADMIN_DIR"
  NEXT_PUBLIC_API_URL="$AWS_API_URL" PORT="$PORT" npm run dev &
  REACT_ADMIN_PID=$!
  sleep 10

  PLAYWRIGHT_BASE_URL="http://localhost:$PORT" \
  TEST_ADMIN_EMAIL="${TEST_ADMIN_EMAIL:-}" \
  TEST_ADMIN_PASSWORD="${TEST_ADMIN_PASSWORD:-}" \
  npx playwright test
  if [[ $? -eq 0 ]]; then ok "AWS E2E"; else fail "AWS E2E"; fi
fi

if [[ "$SKIP_BUILD" == true ]]; then
  echo "[SKIP] Phase 5 - build skipped"
else
  phase 5 "Production build check"
  cd "$REACT_ADMIN_DIR"
  if npm run build; then ok "build"; else fail "build"; fi
fi

echo
echo "========================================"
echo "  RESULT: $PASS passed, $FAIL failed"
echo "  Log: $LOG_FILE"
echo "========================================"

[[ "$FAIL" -eq 0 ]]
