#!/bin/bash

# Start API in development mode

cd "$(dirname "$0")/../packages/api"

echo "Starting Industry Night API..."
echo "API will be available at http://localhost:3000"
echo ""

npm run dev
