#!/bin/bash
set -euo pipefail

# eks-upgrade.sh — In-place sequential EKS Kubernetes version upgrade
#
# EKS only supports upgrading one minor version at a time. This script
# upgrades through each intermediate version until reaching the target.
#
# Current target: 1.35 (standard support through March 2027)
#
# Upgrade path from 1.31:  1.31 → 1.32 → 1.33 → 1.34 → 1.35
#
# When to use this vs teardown/rebuild:
#   - Use THIS script when the cluster has live traffic and data-dependent
#     infra state that makes teardown risky (e.g., production).
#   - Use teardown + rebuild (coop.sh rebuild) when starting fresh or for
#     dev environments where downtime is acceptable. Rebuild always creates
#     the cluster at the target version directly.
#
# Usage:
#   ./scripts/coop/eks-upgrade.sh [--env dev|prod] [--dry-run] [--yes]
#
# Options:
#   --env dev|prod   Target environment (default: dev)
#   --dry-run        Show what would be done without making changes
#   --yes            Skip confirmation prompts

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"

parse_env_flag "$@"
set -- "${PASSTHROUGH_ARGS[@]+"${PASSTHROUGH_ARGS[@]}"}"
load_environment "$IN_ENV"

TARGET_VERSION="1.35"
DRY_RUN=false
SKIP_CONFIRM=false

for arg in "$@"; do
  case $arg in
    --dry-run) DRY_RUN=true ;;
    --yes) SKIP_CONFIRM=true ;;
    *) log_error "Unknown option: $arg"; exit 1 ;;
  esac
done

env_color=$CYAN
[[ "$ENV_NAME" == "prod" ]] && env_color=$RED

echo -e "${BOLD}=== EKS In-Place Version Upgrade ===${NC}"
ENV_UPPER=$(echo "$ENV_NAME" | tr '[:lower:]' '[:upper:]')
echo -e "  Environment: ${env_color}${ENV_UPPER}${NC} ($ENV_LABEL)"
echo -e "  Cluster:     $EKS_CLUSTER"
echo -e "  Target:      Kubernetes $TARGET_VERSION (standard support through March 2027)"
[[ "$DRY_RUN" == "true" ]] && echo -e "  ${YELLOW}[DRY RUN — no changes will be made]${NC}"
echo ""

check_prerequisites
check_aws_credentials

# ---- Verify cluster exists ----
EKS_STATUS=$(aws_cmd eks describe-cluster --name "$EKS_CLUSTER" \
  --query 'cluster.status' --output text 2>/dev/null || echo "NOT_FOUND")

if [[ "$EKS_STATUS" == "NOT_FOUND" ]]; then
  log_error "EKS cluster '$EKS_CLUSTER' not found."
  log_error "If the cluster doesn't exist yet, use rebuild instead:"
  log_error "  ./scripts/coop/coop.sh --env $ENV_NAME rebuild"
  exit 1
fi

if [[ "$EKS_STATUS" != "ACTIVE" ]]; then
  log_error "EKS cluster is not ACTIVE (status: $EKS_STATUS). Cannot upgrade."
  exit 1
fi

# ---- Get current version ----
CURRENT_VERSION=$(aws_cmd eks describe-cluster --name "$EKS_CLUSTER" \
  --query 'cluster.version' --output text)

log_info "Current Kubernetes version: $CURRENT_VERSION"
log_info "Target Kubernetes version:  $TARGET_VERSION"
echo ""

if [[ "$CURRENT_VERSION" == "$TARGET_VERSION" ]]; then
  log_success "Cluster is already at target version $TARGET_VERSION. Nothing to do."
  exit 0
fi

# ---- Build upgrade path ----
# EKS supports versions as integers for comparison (e.g., 1.31 → 131)
current_minor=$(echo "$CURRENT_VERSION" | cut -d. -f2)
target_minor=$(echo "$TARGET_VERSION" | cut -d. -f2)

if [[ "$current_minor" -gt "$target_minor" ]]; then
  log_error "Current version ($CURRENT_VERSION) is newer than target ($TARGET_VERSION)."
  exit 1
fi

UPGRADE_STEPS=()
step=$((current_minor + 1))
while [[ "$step" -le "$target_minor" ]]; do
  UPGRADE_STEPS+=("1.$step")
  step=$((step + 1))
done

echo -e "${BOLD}Upgrade path:${NC}"
echo -e "  $CURRENT_VERSION → ${UPGRADE_STEPS[*]}"
echo ""
echo -e "${YELLOW}Each version hop takes 10-15 minutes. Total estimated time: $((${#UPGRADE_STEPS[@]} * 12)) minutes.${NC}"
echo ""

confirm_destructive "This will perform a rolling upgrade of $EKS_CLUSTER through ${#UPGRADE_STEPS[@]} version(s). Control plane will be upgraded; node group will follow."

# ---- Ensure kubeconfig is up to date ----
aws_cmd eks update-kubeconfig --name "$EKS_CLUSTER" --region "$AWS_REGION"

# ---- Upgrade function ----
upgrade_to_version() {
  local version=$1
  log_step "→" "↑" "Upgrading control plane to Kubernetes $version..."

  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "  [DRY RUN] Would run: aws eks update-cluster-version --name $EKS_CLUSTER --kubernetes-version $version"
    return 0
  fi

  aws_cmd eks update-cluster-version \
    --name "$EKS_CLUSTER" \
    --kubernetes-version "$version" \
    --query 'update.id' --output text

  log_info "  Waiting for control plane upgrade to complete (this takes 10-15 minutes)..."
  aws_cmd eks wait cluster-active --name "$EKS_CLUSTER"

  # Confirm the version landed
  ACTUAL=$(aws_cmd eks describe-cluster --name "$EKS_CLUSTER" \
    --query 'cluster.version' --output text)
  if [[ "$ACTUAL" != "$version" ]]; then
    log_warn "  Cluster reports version $ACTUAL, expected $version. Waiting longer..."
    sleep 60
    ACTUAL=$(aws_cmd eks describe-cluster --name "$EKS_CLUSTER" \
      --query 'cluster.version' --output text)
  fi
  log_success "  Control plane upgraded to $ACTUAL"
}

upgrade_nodegroup() {
  local version=$1
  log_info "  Upgrading node group '$EKS_NODEGROUP' to Kubernetes $version..."

  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "  [DRY RUN] Would run: aws eks update-nodegroup-version --cluster-name $EKS_CLUSTER --nodegroup-name $EKS_NODEGROUP"
    return 0
  fi

  aws_cmd eks update-nodegroup-version \
    --cluster-name "$EKS_CLUSTER" \
    --nodegroup-name "$EKS_NODEGROUP" \
    --query 'update.id' --output text

  log_info "  Waiting for node group upgrade to complete..."
  aws_cmd eks wait nodegroup-active \
    --cluster-name "$EKS_CLUSTER" \
    --nodegroup-name "$EKS_NODEGROUP"

  log_success "  Node group upgraded to $version"
}

upgrade_addons() {
  local version=$1
  log_info "  Upgrading EKS addons for Kubernetes $version..."

  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "  [DRY RUN] Would upgrade vpc-cni, coredns, kube-proxy to latest for $version"
    return 0
  fi

  for addon in vpc-cni coredns kube-proxy; do
    ADDON_EXISTS=$(aws_cmd eks describe-addon \
      --cluster-name "$EKS_CLUSTER" --addon-name "$addon" \
      --query 'addon.addonName' --output text 2>/dev/null || echo "")

    if [[ -z "$ADDON_EXISTS" ]]; then
      log_info "    Addon $addon not installed, skipping."
      continue
    fi

    LATEST_VERSION=$(aws_cmd eks describe-addon-versions \
      --addon-name "$addon" \
      --kubernetes-version "$version" \
      --query 'addons[0].addonVersions[0].addonVersion' \
      --output text 2>/dev/null || echo "")

    if [[ -z "$LATEST_VERSION" || "$LATEST_VERSION" == "None" ]]; then
      log_warn "    Could not determine latest version for $addon on K8s $version, skipping."
      continue
    fi

    log_info "    Upgrading $addon → $LATEST_VERSION..."
    aws_cmd eks update-addon \
      --cluster-name "$EKS_CLUSTER" \
      --addon-name "$addon" \
      --addon-version "$LATEST_VERSION" \
      --resolve-conflicts OVERWRITE \
      --query 'update.id' --output text

    aws_cmd eks wait addon-active \
      --cluster-name "$EKS_CLUSTER" \
      --addon-name "$addon"
    log_success "    $addon upgraded to $LATEST_VERSION"
  done
}

# ---- Execute upgrade path ----
TOTAL_STEPS=${#UPGRADE_STEPS[@]}
STEP_NUM=0

for version in "${UPGRADE_STEPS[@]}"; do
  STEP_NUM=$((STEP_NUM + 1))
  echo ""
  echo -e "${BOLD}[$STEP_NUM/$TOTAL_STEPS] Upgrading to Kubernetes $version${NC}"

  upgrade_to_version "$version"
  upgrade_addons "$version"
  upgrade_nodegroup "$version"

  log_success "  ✓ Kubernetes $version complete"
done

# ---- Final node group AMI refresh (AL2023) ----
if [[ "$DRY_RUN" != "true" ]]; then
  echo ""
  log_info "Triggering node group AMI refresh to AmazonLinux2023..."
  aws_cmd eks update-nodegroup-version \
    --cluster-name "$EKS_CLUSTER" \
    --nodegroup-name "$EKS_NODEGROUP" \
    --force \
    --query 'update.id' --output text 2>/dev/null || \
    log_warn "AMI refresh skipped (node group may already be on AL2023)."
fi

# ---- Summary ----
echo ""
echo -e "${BOLD}=== Upgrade Complete ===${NC}"
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
  echo -e "  ${YELLOW}[DRY RUN — no changes were made]${NC}"
else
  FINAL_VERSION=$(aws_cmd eks describe-cluster --name "$EKS_CLUSTER" \
    --query 'cluster.version' --output text)
  echo -e "  Cluster:  $EKS_CLUSTER"
  echo -e "  Version:  ${GREEN}$FINAL_VERSION${NC}"
  echo -e "  Status:   ${GREEN}standard support through March 2027${NC}"
  echo ""
  echo "  Verify cluster health:"
  echo "    kubectl get nodes"
  echo "    kubectl get pods -n $K8S_NAMESPACE"
  echo "    curl https://${API_HOST}/health"
fi
echo ""
