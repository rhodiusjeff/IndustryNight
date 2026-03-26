#!/bin/zsh
# scripts/b0-babysitter.sh
# Monitors B0 execution agent lanes for red-flag violations.
# Runs as a background process. Fires macOS notifications on violations.
# Usage: ./scripts/b0-babysitter.sh [--interval 60]
# Log: test_logs/b0-babysitter.log

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$PROJECT_ROOT/test_logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/b0-babysitter.log"

INTERVAL=60
while [[ "$#" -gt 0 ]]; do
  case $1 in --interval) INTERVAL="$2"; shift ;; esac
  shift
done

BRANCHES=(
  "feature/B0-react-scaffold-claude"
  "feature/B0-react-scaffold-gpt"
)

# Tracks last-seen SHAs per branch via temp files
SHA_DIR="$LOG_DIR/babysitter-state"
mkdir -p "$SHA_DIR"

get_last_sha() { cat "$SHA_DIR/${1//\//_}" 2>/dev/null || echo ""; }
set_last_sha() { echo "$2" > "$SHA_DIR/${1//\//_}"; }

# Files that must never be touched by execution agents
FORBIDDEN_PATTERNS=(
  "packages/api/"
  "packages/shared/"
  "packages/social-app/"
  "packages/admin-app/"
  "packages/database/"
  "infrastructure/"
  "scripts/run-api.sh"
  "scripts/deploy-api.sh"
  "scripts/deploy-admin.sh"
  "scripts/migrate.js"
  "scripts/db-reset.js"
  "scripts/seed-admin.js"
  "scripts/pf-db.sh"
  "scripts/closeout-test.sh"
  ".env.local"
)

# Patterns that must never appear in committed playwright.config.ts
HARDCODE_PAT="localhost:363"

notify() {
  local title="$1"
  local msg="$2"
  osascript -e "display notification \"$msg\" with title \"$title\" sound name \"Basso\"" 2>/dev/null || true
}

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

check_branch() {
  local branch="$1"
  local lane="${branch##*-}"  # claude or gpt
  local tip
  tip=$(git rev-parse "origin/$branch" 2>/dev/null) || return
  local prev
  prev=$(get_last_sha "$branch")

  if [ "$tip" = "$prev" ]; then return; fi
  set_last_sha "$branch" "$tip"

  # Get list of commits since last check (or all commits on branch vs integration)
  local base
  if [ -z "$prev" ]; then
    base=$(git merge-base origin/integration "origin/$branch" 2>/dev/null || echo "")
  else
    base="$prev"
  fi
  [ -z "$base" ] && return

  local commits
  commits=$(git log --oneline "$base".."origin/$branch" 2>/dev/null) || return
  [ -z "$commits" ] && return

  log "[$lane] New commits detected:"
  echo "$commits" | while read -r line; do log "  $line"; done

  # Check each new commit's changed files
  local changed_files
  changed_files=$(git diff --name-only "$base" "origin/$branch" 2>/dev/null) || return

  local violations=()

  # 1. Forbidden file patterns
  for pat in "${FORBIDDEN_PATTERNS[@]}"; do
    if echo "$changed_files" | grep -q "$pat"; then
      violations+=("FORBIDDEN FILE TOUCHED: $pat")
    fi
  done

  # 2. .env.local tracked anywhere (belt-and-suspenders)
  if echo "$changed_files" | grep -qE "(^|/)\.env\.local$"; then
    violations+=(".env.local COMMITTED — credentials may be exposed")
  fi

  # 3. Hardcoded port in playwright.config.ts
  if echo "$changed_files" | grep -q "playwright.config"; then
    local pw_content
    pw_content=$(git show "origin/$branch:packages/react-admin/playwright.config.ts" 2>/dev/null) || true
    if echo "$pw_content" | grep -q "$HARDCODE_PAT"; then
      violations+=("playwright.config.ts has hardcoded $HARDCODE_PAT — must use PLAYWRIGHT_BASE_URL")
    fi
  fi

  # 4. PORT hardcoded in run-react-admin.sh (should be ${PORT:-3630})
  if echo "$changed_files" | grep -q "run-react-admin.sh"; then
    local run_content
    run_content=$(git show "origin/$branch:scripts/run-react-admin.sh" 2>/dev/null) || true
    # GPT lane committing PORT=3631 in the run script is a violation
    if echo "$run_content" | grep -qE "PORT=363[1-9]"; then
      violations+=("run-react-admin.sh has hardcoded non-canonical PORT — must default to 3630")
    fi
  fi

  # 5. Direct integration branch push (should not happen, but catch if somehow origin/integration moved)
  local integration_tip
  integration_tip=$(git rev-parse origin/integration 2>/dev/null) || true
  if [ "$tip" = "$integration_tip" ] && [ "$branch" != "integration" ]; then
    violations+=("CRITICAL: branch tip matches integration HEAD — possible direct push to integration")
  fi

  if [ ${#violations[@]} -gt 0 ]; then
    log "[$lane] ❌ VIOLATIONS FOUND:"
    for v in "${violations[@]}"; do
      log "  ⚠️  $v"
    done
    local summary="${violations[*]}"
    notify "B0 Babysitter — $lane lane VIOLATION" "$summary"
  else
    local commit_count
    commit_count=$(echo "$commits" | wc -l | tr -d ' ')
    log "[$lane] ✅ Clean — $commit_count new commits, no violations"
  fi

  # Log full changed file list for audit
  log "[$lane] Files changed in this batch:"
  echo "$changed_files" | while read -r f; do log "  $f"; done
}

log "═══════════════════════════════════════════════════"
log "B0 Babysitter started — checking every ${INTERVAL}s"
log "Watching: ${BRANCHES[*]}"
log "Log: $LOG_FILE"
log "═══════════════════════════════════════════════════"
notify "B0 Babysitter" "Monitoring claude + gpt lanes. Violations will alert here."

cd "$PROJECT_ROOT"

while true; do
  git fetch origin --quiet 2>/dev/null || log "WARN: git fetch failed — network issue?"
  for branch in "${BRANCHES[@]}"; do
    check_branch "$branch"
  done
  sleep "$INTERVAL"
done
