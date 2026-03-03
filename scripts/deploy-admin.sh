#!/bin/bash
set -euo pipefail

# deploy-admin.sh — Build and deploy the Admin web app to S3/CloudFront
#
# Usage:
#   ./scripts/deploy-admin.sh              # Build and deploy
#   ./scripts/deploy-admin.sh --skip-build # Deploy existing build only
#   ./scripts/deploy-admin.sh --status     # Check CloudFront distribution status

AWS_PROFILE=industrynight-admin
REGION=us-east-1
S3_BUCKET=industrynight-web-admin
CF_DISTRIBUTION_ID=E196TNDGV555BI
ADMIN_DIR="$(cd "$(dirname "$0")/../packages/admin-app" && pwd)"
BUILD_DIR="$ADMIN_DIR/build/web"

SKIP_BUILD=false
STATUS_ONLY=false

for arg in "$@"; do
  case $arg in
    --skip-build) SKIP_BUILD=true ;;
    --status) STATUS_ONLY=true ;;
    *) echo "Unknown option: $arg"; exit 1 ;;
  esac
done

# Status check only
if [ "$STATUS_ONLY" = true ]; then
  echo "=== Admin App Status ==="
  echo ""
  echo "CloudFront Distribution: $CF_DISTRIBUTION_ID"
  AWS_PROFILE=$AWS_PROFILE aws cloudfront get-distribution \
    --id "$CF_DISTRIBUTION_ID" \
    --query 'Distribution.{Status:Status,DomainName:DomainName,LastModified:LastModifiedTime}' \
    --output table
  echo ""
  echo "S3 Bucket:"
  AWS_PROFILE=$AWS_PROFILE aws s3 ls "s3://$S3_BUCKET/" --summarize --human-readable | tail -2
  exit 0
fi

echo "=== Industry Night Admin Deploy ==="
echo ""

# Step 1: Build
if [ "$SKIP_BUILD" = false ]; then
  echo "[1/3] Building Flutter web app..."
  cd "$ADMIN_DIR"
  flutter build web --release
  cd - > /dev/null
  echo ""
else
  echo "[1/3] Skipping build (--skip-build)"
  if [ ! -d "$BUILD_DIR" ]; then
    echo "ERROR: No build found at $BUILD_DIR. Run without --skip-build first."
    exit 1
  fi
  echo ""
fi

# Step 2: Sync to S3
echo "[2/3] Syncing to S3..."
AWS_PROFILE=$AWS_PROFILE aws s3 sync "$BUILD_DIR" "s3://$S3_BUCKET/" --delete
echo ""

# Step 3: Invalidate CloudFront cache
echo "[3/3] Invalidating CloudFront cache..."
INVALIDATION_ID=$(AWS_PROFILE=$AWS_PROFILE aws cloudfront create-invalidation \
  --distribution-id "$CF_DISTRIBUTION_ID" \
  --paths "/*" \
  --query 'Invalidation.Id' --output text)
echo "  Invalidation: $INVALIDATION_ID (propagating...)"
echo ""

# Verify
echo "=== Deploy complete ==="
echo ""
echo "  S3 Bucket:     s3://$S3_BUCKET"
echo "  CloudFront:    $CF_DISTRIBUTION_ID"
echo "  URL:           https://admin.industrynight.net"
echo ""
echo "  Cache invalidation takes 1-2 minutes to propagate."
echo "  Hard-refresh (Cmd+Shift+R) if you see stale content."
