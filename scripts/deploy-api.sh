#!/bin/bash
set -euo pipefail

# deploy-api.sh — Build, push, and roll out the API to EKS
#
# Usage:
#   ./scripts/deploy-api.sh [--env dev|prod]              # Build, push, rolling restart
#   ./scripts/deploy-api.sh [--env dev|prod] --skip-build # Push existing image and restart only
#   ./scripts/deploy-api.sh [--env dev|prod] --status     # Just check rollout status

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/coop/config.sh"

parse_env_flag "$@"
set -- "${PASSTHROUGH_ARGS[@]+"${PASSTHROUGH_ARGS[@]}"}"
load_environment "$IN_ENV"

API_DIR="$PROJECT_ROOT/packages/api"

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
  echo "=== Deployment Status ($ENV_NAME) ==="
  kube_cmd rollout status deployment/$K8S_DEPLOYMENT -n $K8S_NAMESPACE
  echo ""
  kube_cmd get pods -n $K8S_NAMESPACE -l app=$K8S_DEPLOYMENT
  exit 0
fi

# Safety: warn if deploying to prod from non-master branch
if [[ "$ENV_NAME" == "prod" ]]; then
  CURRENT_BRANCH=$(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
  if [[ "$CURRENT_BRANCH" != "master" ]]; then
    log_warn "Deploying to PRODUCTION from branch '$CURRENT_BRANCH' (not master)"
    read -p "Continue? (y/N): " answer
    if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
      echo "Aborted."
      exit 0
    fi
  fi
fi

env_color=$CYAN
[[ "$ENV_NAME" == "prod" ]] && env_color=$RED

echo -e "${BOLD}=== Industry Night API Deploy ===${NC}"
ENV_UPPER=$(echo "$ENV_NAME" | tr '[:lower:]' '[:upper:]')
echo -e "  Environment: ${env_color}${ENV_UPPER}${NC} ($ENV_LABEL)"
echo "  Image:       $ECR_IMAGE"
echo "  Namespace:   $K8S_NAMESPACE"
echo ""

# Step 1: ECR login
echo "[1/4] Authenticating with ECR..."
aws_cmd ecr get-login-password | \
  docker login --username AWS --password-stdin "${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com"
echo ""

# Step 2: Build
if [ "$SKIP_BUILD" = false ]; then
  echo "[2/4] Building Docker image..."
  docker build --platform linux/amd64 -t "$ECR_IMAGE" "$API_DIR"
  echo ""
else
  echo "[2/4] Skipping build (--skip-build)"
  echo ""
fi

# Step 3: Push
echo "[3/4] Pushing to ECR..."
docker push "$ECR_IMAGE"
echo ""

# Step 4: Rollout
echo "[4/4] Rolling out..."
kube_cmd rollout restart deployment/$K8S_DEPLOYMENT -n $K8S_NAMESPACE
kube_cmd rollout status deployment/$K8S_DEPLOYMENT -n $K8S_NAMESPACE
echo ""

# Verify
echo "=== Deploy complete ==="
kube_cmd get pods -n $K8S_NAMESPACE -l app=$K8S_DEPLOYMENT
