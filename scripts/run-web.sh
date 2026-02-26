#!/bin/bash

# Start web app in development mode

cd "$(dirname "$0")/../packages/admin-app"

echo "Starting Industry Night Admin App..."
echo "App will be available at http://localhost:8080"
echo ""

flutter run -d chrome --web-port 8080
