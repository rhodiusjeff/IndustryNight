#!/bin/bash

# Start admin app in development mode (Chrome)

cd "$(dirname "$0")/../packages/admin-app"

echo "Starting Industry Night Admin App..."
echo "App will be available at http://localhost:8080"

# Pass Google Places API key if set in environment
DART_DEFINES=""
if [ -n "$GOOGLE_PLACES_API_KEY" ]; then
  DART_DEFINES="--dart-define=GOOGLE_PLACES_API_KEY=$GOOGLE_PLACES_API_KEY"
  echo "Google Places autocomplete: enabled"
else
  echo "Google Places autocomplete: disabled (set GOOGLE_PLACES_API_KEY to enable)"
fi
echo ""

flutter run -d chrome --web-port 8080 $DART_DEFINES
