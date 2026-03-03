#!/bin/bash

# Start admin app in development mode (Chrome)
# Usage: ./scripts/run-admin-app.sh [--env dev|prod]

cd "$(dirname "$0")/../packages/admin-app"

# Default to dev API
API_URL="https://dev-api.industrynight.net"

# Parse --env flag
while [[ $# -gt 0 ]]; do
  case $1 in
    --env)
      if [ "$2" = "prod" ]; then
        API_URL="https://api.industrynight.net"
        echo "** Using PRODUCTION API **"
      fi
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

echo "Starting Industry Night Admin App..."
echo "API: $API_URL"
echo "App will be available at http://localhost:8080"

DART_DEFINES="--dart-define=API_BASE_URL=$API_URL"

# Pass Google Places API key if set in environment
if [ -n "$GOOGLE_PLACES_API_KEY" ]; then
  DART_DEFINES="$DART_DEFINES --dart-define=GOOGLE_PLACES_API_KEY=$GOOGLE_PLACES_API_KEY"
  echo "Google Places autocomplete: enabled"
else
  echo "Google Places autocomplete: disabled (set GOOGLE_PLACES_API_KEY to enable)"
fi
echo ""

flutter run -d chrome --web-port 8080 $DART_DEFINES
