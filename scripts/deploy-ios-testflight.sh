#!/bin/bash
set -euo pipefail

# deploy-ios-testflight.sh — Run iOS Fastlane lanes from repo root
#
# Usage:
#   ./scripts/deploy-ios-testflight.sh                # default: beta
#   ./scripts/deploy-ios-testflight.sh --preflight
#   ./scripts/deploy-ios-testflight.sh --beta
#   ./scripts/deploy-ios-testflight.sh --env-file /path/to/.env
#
# Notes:
# - Expects Fastlane config under packages/social-app/ios/fastlane/
# - Defaults to loading env vars from packages/social-app/ios/fastlane/.env when present

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
IOS_DIR="$PROJECT_ROOT/packages/social-app/ios"
DEFAULT_ENV_FILE="$IOS_DIR/fastlane/.env"

LANE="beta"
ENV_FILE="$DEFAULT_ENV_FILE"
SKIP_ENV_LOAD=false

print_usage() {
  cat <<'EOF'
Usage:
  ./scripts/deploy-ios-testflight.sh
  ./scripts/deploy-ios-testflight.sh --preflight
  ./scripts/deploy-ios-testflight.sh --beta
  ./scripts/deploy-ios-testflight.sh --env-file <path>
  ./scripts/deploy-ios-testflight.sh --no-env-file

Options:
  --preflight         Run fastlane ios preflight
  --beta              Run fastlane ios beta (default)
  --env-file <path>   Load env vars from file before running lane
  --no-env-file       Do not auto-load any env file
  --help, -h, -?      Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --preflight)
      LANE="preflight"
      shift
      ;;
    --beta)
      LANE="beta"
      shift
      ;;
    --env-file)
      if [[ $# -lt 2 ]]; then
        echo "ERROR: --env-file requires a path"
        exit 1
      fi
      ENV_FILE="$2"
      shift 2
      ;;
    --no-env-file)
      SKIP_ENV_LOAD=true
      shift
      ;;
    --help|-h|-?)
      print_usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown option: $1"
      print_usage
      exit 1
      ;;
  esac
done

if [[ ! -d "$IOS_DIR" ]]; then
  echo "ERROR: iOS directory not found: $IOS_DIR"
  exit 1
fi

if [[ "$SKIP_ENV_LOAD" == false && -f "$ENV_FILE" ]]; then
  echo "Loading env vars from: $ENV_FILE"
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip blank lines and comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

    # Parse KEY=VALUE pairs without evaluating shell expressions
    if [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
      key="${BASH_REMATCH[1]}"
      value="${BASH_REMATCH[2]}"

      # Trim leading/trailing whitespace from value
      value="${value#${value%%[![:space:]]*}}"
      value="${value%${value##*[![:space:]]}}"

      # Strip surrounding single/double quotes if present
      if [[ "$value" =~ ^\".*\"$ || "$value" =~ ^\'.*\'$ ]]; then
        value="${value:1:${#value}-2}"
      fi

      export "$key=$value"
    fi
  done < "$ENV_FILE"
elif [[ "$SKIP_ENV_LOAD" == false ]]; then
  echo "No env file found at: $ENV_FILE (continuing with current shell env)"
fi

if ! command -v bundle >/dev/null 2>&1; then
  echo "ERROR: bundler is not installed. Install with: gem install bundler"
  exit 1
fi

if [[ "$LANE" == "beta" ]]; then
  required=(APP_STORE_CONNECT_KEY_ID APP_STORE_CONNECT_ISSUER_ID APP_STORE_CONNECT_KEY_FILEPATH)
  for key in "${required[@]}"; do
    if [[ -z "${!key:-}" ]]; then
      echo "ERROR: Missing required environment variable: $key"
      exit 1
    fi
  done
fi

echo "Running Fastlane lane: ios $LANE"
cd "$IOS_DIR"
bundle install
bundle exec fastlane ios "$LANE"
