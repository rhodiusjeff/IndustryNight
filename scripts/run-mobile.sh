#!/bin/bash

# Start mobile app in development mode

cd "$(dirname "$0")/../packages/mobile-app"

echo "Starting Industry Night Mobile App..."
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

flutter run
