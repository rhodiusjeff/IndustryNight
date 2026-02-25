#!/bin/bash

# Local Development Setup Script
# Run this once to set up your development environment

set -e

echo "Setting up Industry Night development environment..."

# Check prerequisites
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo "Error: $1 is not installed. Please install it first."
        exit 1
    fi
}

echo "Checking prerequisites..."
check_command flutter
check_command node
check_command npm
check_command dart

# Check versions
echo ""
echo "Versions:"
flutter --version | head -n 1
node --version
npm --version

# Install Flutter dependencies
echo ""
echo "Installing Flutter package dependencies..."
cd packages/shared && flutter pub get && cd ../..
cd packages/mobile-app && flutter pub get && cd ../..
cd packages/web-app && flutter pub get && cd ../..

# Generate JSON serialization code
echo ""
echo "Running build_runner for code generation..."
cd packages/shared && dart run build_runner build --delete-conflicting-outputs && cd ../..

# Install API dependencies
echo ""
echo "Installing API dependencies..."
cd packages/api
npm install
cd ../..

# Create .env file for API if it doesn't exist
if [ ! -f packages/api/.env ]; then
    echo ""
    echo "Creating API .env file..."
    cat > packages/api/.env << 'EOF'
NODE_ENV=development
PORT=3000

# Database (update these for your local setup)
DB_HOST=localhost
DB_PORT=5432
DB_NAME=industrynight
DB_USER=postgres
DB_PASSWORD=postgres

# JWT (generate your own secret in production)
JWT_SECRET=development-secret-key-change-in-production
JWT_ACCESS_EXPIRY=15m
JWT_REFRESH_EXPIRY=7d

# AWS (optional for local development)
AWS_REGION=us-east-1
# AWS_ACCESS_KEY_ID=
# AWS_SECRET_ACCESS_KEY=
# S3_BUCKET=
# SES_FROM_EMAIL=

# Twilio (optional for local development - codes will be logged)
# TWILIO_ACCOUNT_SID=
# TWILIO_AUTH_TOKEN=
# TWILIO_PHONE_NUMBER=

# Posh webhook
# POSH_WEBHOOK_SECRET=

# CORS
CORS_ORIGINS=http://localhost:3000,http://localhost:8080
EOF
    echo "Created packages/api/.env - please update with your settings"
fi

# Make database scripts executable
chmod +x packages/database/scripts/*.sh

echo ""
echo "=========================================="
echo "Setup complete!"
echo ""
echo "Next steps:"
echo "1. Set up PostgreSQL and create the 'industrynight' database"
echo "2. Update packages/api/.env with your database credentials"
echo "3. Run database migrations: cd packages/database && ./scripts/migrate.sh"
echo "4. (Optional) Load seed data: cd packages/database && psql -d industrynight -f seeds/dev_seed.sql"
echo ""
echo "To start development:"
echo "  API:    ./scripts/run-api.sh"
echo "  Mobile: ./scripts/run-mobile.sh"
echo "  Web:    ./scripts/run-web.sh"
echo "=========================================="
