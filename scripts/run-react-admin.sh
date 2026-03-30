#!/bin/bash
# scripts/run-react-admin.sh
# Start React Admin in development mode
# Usage: ./scripts/run-react-admin.sh [--env local|dev|prod]
#   local  → http://localhost:3000  (local API, default)
#   dev    → https://dev-api.industrynight.net
#   prod   → https://api.industrynight.net

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REACT_ADMIN_DIR="$SCRIPT_DIR/../packages/react-admin"
ENV="local"
PORT=${PORT:-3630}  # Allow PORT env override for lane testing; default 3630

# Parse flags
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --env) ENV="$2"; shift ;;
    *) echo "Unknown parameter: $1"; exit 1 ;;
  esac
  shift
done

# Set API URL based on environment
if [ "$ENV" = "prod" ]; then
  API_URL="https://api.industrynight.net"
elif [ "$ENV" = "dev" ]; then
  API_URL="https://dev-api.industrynight.net"
else
  API_URL="http://localhost:3000"
fi

# Bootstrap .env.local from template if it doesn't exist
ENV_FILE="$REACT_ADMIN_DIR/.env.local"
TEMPLATE_FILE="$REACT_ADMIN_DIR/.env.local.template"
if [ ! -f "$ENV_FILE" ] && [ -f "$TEMPLATE_FILE" ]; then
  echo "Creating .env.local from template..."
  cp "$TEMPLATE_FILE" "$ENV_FILE"
  sed -i.bak "s|NEXT_PUBLIC_API_URL=.*|NEXT_PUBLIC_API_URL=$API_URL|" "$ENV_FILE" && rm -f "$ENV_FILE.bak"
  sed -i.bak "s|NEXT_PUBLIC_APP_ENV=.*|NEXT_PUBLIC_APP_ENV=$ENV|" "$ENV_FILE" && rm -f "$ENV_FILE.bak"
  echo ".env.local created. Edit it if needed, then re-run."
fi

echo "Starting React Admin on http://localhost:$PORT (env: $ENV)"
cd "$REACT_ADMIN_DIR" && PORT=$PORT npm run dev
