#!/bin/bash
set -euo pipefail

# deploy-api.sh — Build, push, and roll out the API to EKS
#
# Usage:
#   ./scripts/deploy-api.sh              # Build, push, rolling restart
#   ./scripts/deploy-api.sh --skip-build # Push existing image and restart only
#   ./scripts/deploy-api.sh --status     # Just check rollout status

AWS_PROFILE=industrynight-admin
REGION=us-east-1
ACCOUNT=047593684855
REPO="${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com/industrynight-api"
TAG=latest
NAMESPACE=industrynight
DEPLOYMENT=industrynight-api
API_DIR="$(cd "$(dirname "$0")/../packages/api" && pwd)"

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
  echo "=== Deployment Status ==="
  AWS_PROFILE=$AWS_PROFILE kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE
  echo ""
  AWS_PROFILE=$AWS_PROFILE kubectl get pods -n $NAMESPACE -l app=$DEPLOYMENT
  exit 0
fi

echo "=== Industry Night API Deploy ==="
echo ""

# Step 1: ECR login
echo "[1/4] Authenticating with ECR..."
AWS_PROFILE=$AWS_PROFILE aws ecr get-login-password --region $REGION | \
  docker login --username AWS --password-stdin "${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com"
echo ""

# Step 2: Build
if [ "$SKIP_BUILD" = false ]; then
  echo "[2/4] Building Docker image..."
  docker build --platform linux/amd64 -t "${REPO}:${TAG}" "$API_DIR"
  echo ""
else
  echo "[2/4] Skipping build (--skip-build)"
  echo ""
fi

# Step 3: Push
echo "[3/4] Pushing to ECR..."
docker push "${REPO}:${TAG}"
echo ""

# Step 4: Rollout
echo "[4/4] Rolling out..."
AWS_PROFILE=$AWS_PROFILE kubectl rollout restart deployment/$DEPLOYMENT -n $NAMESPACE
AWS_PROFILE=$AWS_PROFILE kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE
echo ""

# Verify
echo "=== Deploy complete ==="
AWS_PROFILE=$AWS_PROFILE kubectl get pods -n $NAMESPACE -l app=$DEPLOYMENT
