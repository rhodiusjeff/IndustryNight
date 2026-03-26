#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REACT_ADMIN_DIR="$PROJECT_ROOT/packages/react-admin"
ENV="dev"
PORT="${PORT:-3630}"

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --env)
      ENV="$2"
      shift
      ;;
    *)
      echo "Unknown parameter: $1"
      exit 1
      ;;
  esac
  shift
done

if [[ "$ENV" == "prod" ]]; then
  API_URL="https://api.industrynight.net"
else
  API_URL="http://localhost:3000"
fi

ENV_FILE="$REACT_ADMIN_DIR/.env.local"
TEMPLATE_FILE="$REACT_ADMIN_DIR/.env.local.template"

if [[ ! -f "$ENV_FILE" && -f "$TEMPLATE_FILE" ]]; then
  echo "Creating .env.local from template..."
  cp "$TEMPLATE_FILE" "$ENV_FILE"
fi

if [[ -f "$ENV_FILE" ]]; then
  # Keep .env.local in sync with requested environment.
  grep -v '^NEXT_PUBLIC_API_URL=' "$ENV_FILE" | grep -v '^NEXT_PUBLIC_APP_ENV=' > "$ENV_FILE.tmp" || true
  {
    cat "$ENV_FILE.tmp"
    echo "NEXT_PUBLIC_API_URL=$API_URL"
    echo "NEXT_PUBLIC_APP_ENV=$ENV"
  } > "$ENV_FILE"
  rm -f "$ENV_FILE.tmp"
fi

echo "Starting React Admin on http://localhost:$PORT (env: $ENV)"
cd "$REACT_ADMIN_DIR"
PORT="$PORT" npm run dev
