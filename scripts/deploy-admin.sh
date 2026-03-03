#!/bin/bash
set -euo pipefail

# deploy-admin.sh — Build and deploy the Admin web app to S3/CloudFront
#
# Usage:
#   ./scripts/deploy-admin.sh [--env dev|prod]              # Build and deploy
#   ./scripts/deploy-admin.sh [--env dev|prod] --skip-build # Deploy existing build only
#   ./scripts/deploy-admin.sh [--env dev|prod] --status     # Check CloudFront distribution status

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/coop/config.sh"

parse_env_flag "$@"
set -- "${PASSTHROUGH_ARGS[@]+"${PASSTHROUGH_ARGS[@]}"}"
load_environment "$IN_ENV"

ADMIN_DIR="$PROJECT_ROOT/packages/admin-app"
BUILD_DIR="$ADMIN_DIR/build/web"

SKIP_BUILD=false
STATUS_ONLY=false

for arg in "$@"; do
  case $arg in
    --skip-build) SKIP_BUILD=true ;;
    --status) STATUS_ONLY=true ;;
    *) log_error "Unknown option: $arg"; exit 1 ;;
  esac
done

# Status check only
if [ "$STATUS_ONLY" = true ]; then
  echo "=== Admin App Status ($ENV_NAME) ==="
  echo ""
  echo "CloudFront Distribution: $CF_DISTRIBUTION_ID"
  if [[ -n "$CF_DISTRIBUTION_ID" ]]; then
    aws_cmd cloudfront get-distribution \
      --id "$CF_DISTRIBUTION_ID" \
      --query 'Distribution.{Status:Status,DomainName:DomainName,LastModified:LastModifiedTime}' \
      --output table
  else
    echo "  (not configured)"
  fi
  echo ""
  echo "S3 Bucket: $S3_WEB_BUCKET"
  aws_cmd s3 ls "s3://$S3_WEB_BUCKET/" --summarize --human-readable 2>/dev/null | tail -2 || echo "  (bucket not found)"
  exit 0
fi

env_color=$CYAN
[[ "$ENV_NAME" == "prod" ]] && env_color=$RED

echo -e "${BOLD}=== Industry Night Admin Deploy ===${NC}"
ENV_UPPER=$(echo "$ENV_NAME" | tr '[:lower:]' '[:upper:]')
echo -e "  Environment: ${env_color}${ENV_UPPER}${NC} ($ENV_LABEL)"
echo "  S3 Bucket:   $S3_WEB_BUCKET"
echo "  CloudFront:  ${CF_DISTRIBUTION_ID:-not configured}"
echo "  URL:         https://$ADMIN_HOST"
echo ""

# Step 1: Build
if [ "$SKIP_BUILD" = false ]; then
  echo "[1/3] Building Flutter web app..."
  cd "$ADMIN_DIR"
  flutter build web --release \
    --dart-define=API_BASE_URL="https://$API_HOST"
  cd - > /dev/null
  echo ""
else
  echo "[1/3] Skipping build (--skip-build)"
  if [ ! -d "$BUILD_DIR" ]; then
    log_error "No build found at $BUILD_DIR. Run without --skip-build first."
    exit 1
  fi
  echo ""
fi

# Step 2: Sync to S3
echo "[2/3] Syncing to S3..."
aws_cmd s3 sync "$BUILD_DIR" "s3://$S3_WEB_BUCKET/" --delete
echo ""

# Step 3: Invalidate CloudFront cache
echo "[3/3] Invalidating CloudFront cache..."
if [[ -n "$CF_DISTRIBUTION_ID" ]]; then
  INVALIDATION_ID=$(aws_cmd cloudfront create-invalidation \
    --distribution-id "$CF_DISTRIBUTION_ID" \
    --paths "/*" \
    --query 'Invalidation.Id' --output text)
  echo "  Invalidation: $INVALIDATION_ID (propagating...)"
else
  log_warn "No CloudFront distribution ID configured. Skipping invalidation."
fi
echo ""

# Verify
echo "=== Deploy complete ==="
echo ""
echo "  S3 Bucket:     s3://$S3_WEB_BUCKET"
echo "  CloudFront:    ${CF_DISTRIBUTION_ID:-not configured}"
echo "  URL:           https://$ADMIN_HOST"
echo ""
echo "  Cache invalidation takes 1-2 minutes to propagate."
echo "  Hard-refresh (Cmd+Shift+R) if you see stale content."
