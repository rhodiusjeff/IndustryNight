#!/bin/bash

# Start mobile app in development mode
# Usage: ./scripts/run-mobile.sh [--env dev|prod]

cd "$(dirname "$0")/../packages/social-app"

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

echo "Starting Industry Night Social App..."
echo "API: $API_URL"
echo ""

# Check for connected devices
DEVICES=$(flutter devices --machine 2>/dev/null | grep -c '"id"')

if [ "$DEVICES" -eq 0 ]; then
    echo "No devices found. Please connect a device or start an emulator."
    echo ""
    echo "Available options:"
    echo "  - Connect a physical device via USB"
    echo "  - Start iOS Simulator: open -a Simulator"
    echo "  - Start Android Emulator from Android Studio"
    exit 1
fi

flutter run --dart-define=API_BASE_URL="$API_URL"
