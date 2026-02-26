#!/bin/bash
set -euo pipefail

# infra-teardown.sh — Tear down EKS cluster and RDS database
#
# TEARS DOWN (expensive resources):
#   - EKS cluster (control plane + node group + VPC + NAT gateways)
#   - RDS PostgreSQL instance (creates final snapshot first)
#
# PRESERVES (cheap/free resources):
#   - Route 53 hosted zone (~$0.50/mo)
#   - ACM certificate (free)
#   - S3 buckets (pennies)
#   - ECR repository (pennies)
#   - Secrets Manager (~$0.40/mo)
#
# Usage:
#   ./scripts/coop/infra-teardown.sh [--yes]
#   ./scripts/coop/infra-teardown.sh [--skip-rds-snapshot] [--yes]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"

SKIP_CONFIRM=false
SKIP_RDS_SNAPSHOT=false
for arg in "$@"; do
  case $arg in
    --yes) SKIP_CONFIRM=true ;;
    --skip-rds-snapshot) SKIP_RDS_SNAPSHOT=true ;;
    *) log_error "Unknown option: $arg"; exit 1 ;;
  esac
done

TOTAL_STEPS=7
CURRENT_STEP=0

echo -e "${BOLD}=== Infrastructure Teardown ===${NC}"
echo ""
echo "  Resources to ${RED}TEAR DOWN${NC}:"
echo "    - EKS cluster: $EKS_CLUSTER"
echo "    - RDS instance: $RDS_INSTANCE"
echo ""
echo "  Resources ${GREEN}PRESERVED${NC}:"
echo "    - Route 53: $DOMAIN (zone $HOSTED_ZONE_ID)"
echo "    - ACM cert: $ACM_CERT_ARN"
echo "    - S3: $S3_ASSETS_BUCKET, $S3_WEB_BUCKET"
echo "    - ECR: $ECR_REPO"
echo "    - Secrets Manager: $SECRETS_ID"
echo ""

confirm_destructive "This will delete the EKS cluster and RDS database. Ensure data has been exported first."

# Start teardown manifest log
MANIFEST_DIR="$PROJECT_ROOT/$BACKUPS_DIR"
mkdir -p "$MANIFEST_DIR"
MANIFEST="$MANIFEST_DIR/teardown_$(create_timestamp).log"

tee_log() {
  echo "$1" | tee -a "$MANIFEST"
}

tee_log "=== COOP Teardown Manifest ==="
tee_log "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
tee_log "Operator: $(whoami)"
tee_log ""

# Step 1: Verify AWS credentials
log_step $((++CURRENT_STEP)) $TOTAL_STEPS "Verifying AWS credentials..."
check_aws_credentials

# Step 2: Pre-flight checks
log_step $((++CURRENT_STEP)) $TOTAL_STEPS "Pre-flight checks..."

EKS_STATUS=$(aws_cmd eks describe-cluster --name "$EKS_CLUSTER" \
  --query 'cluster.status' --output text 2>/dev/null || echo "NOT_FOUND")
tee_log "EKS Status: $EKS_STATUS"

RDS_STATUS=$(aws_cmd rds describe-db-instances --db-instance-identifier "$RDS_INSTANCE" \
  --query 'DBInstances[0].DBInstanceStatus' --output text 2>/dev/null || echo "NOT_FOUND")
tee_log "RDS Status: $RDS_STATUS"

if [[ "$EKS_STATUS" == "NOT_FOUND" && "$RDS_STATUS" == "NOT_FOUND" ]]; then
  log_warn "Both EKS and RDS are already gone. Nothing to tear down."
  exit 0
fi

# Step 3: Enable maintenance mode (if EKS is up)
if [[ "$EKS_STATUS" == "ACTIVE" ]]; then
  log_step $((++CURRENT_STEP)) $TOTAL_STEPS "Enabling maintenance mode..."
  "$SCRIPT_DIR/../maintenance.sh" on 2>/dev/null || log_warn "Maintenance mode failed (may already be enabled)"
  tee_log "Action: Maintenance mode enabled"
else
  log_step $((++CURRENT_STEP)) $TOTAL_STEPS "Skipping maintenance mode (EKS not active)"
fi

# Step 4: Clean up K8s resources (if EKS is up)
if [[ "$EKS_STATUS" == "ACTIVE" ]]; then
  log_step $((++CURRENT_STEP)) $TOTAL_STEPS "Cleaning up Kubernetes resources..."

  # Scale deployment to 0
  kube_cmd scale deployment/"$K8S_DEPLOYMENT" -n "$K8S_NAMESPACE" --replicas=0 2>/dev/null || true
  log_info "  Scaled deployment to 0"
  tee_log "Action: Deployment scaled to 0"

  # Wait for pods to terminate
  attempts=0
  while [[ $attempts -lt 30 ]]; do
    POD_COUNT=$(kube_cmd get pods -n "$K8S_NAMESPACE" -l app="$K8S_DEPLOYMENT" \
      --no-headers 2>/dev/null | wc -l | tr -d '[:space:]')
    if [[ "$POD_COUNT" == "0" ]]; then
      break
    fi
    sleep 2
    attempts=$((attempts + 1))
  done
  log_success "  All pods terminated"

  # Delete ingress first to release ALB
  log_info "  Deleting ingress (triggers ALB cleanup)..."
  kube_cmd delete ingress/"$K8S_DEPLOYMENT" -n "$K8S_NAMESPACE" 2>/dev/null || true
  tee_log "Action: Ingress deleted"

  # Wait for ALB to be deregistered
  log_info "  Waiting 30s for ALB cleanup..."
  sleep 30

  # Delete remaining K8s resources
  kube_cmd delete service/"$K8S_DEPLOYMENT" -n "$K8S_NAMESPACE" 2>/dev/null || true
  kube_cmd delete deployment/"$K8S_DEPLOYMENT" -n "$K8S_NAMESPACE" 2>/dev/null || true
  kube_cmd delete hpa/"${K8S_DEPLOYMENT}-hpa" -n "$K8S_NAMESPACE" 2>/dev/null || true
  kube_cmd delete pod/db-proxy -n "$K8S_NAMESPACE" 2>/dev/null || true

  tee_log "Action: K8s resources deleted (service, deployment, HPA, db-proxy)"
  log_success "  Kubernetes resources cleaned up"
else
  log_step $((++CURRENT_STEP)) $TOTAL_STEPS "Skipping K8s cleanup (EKS not active)"
fi

# Step 5: Delete EKS cluster
if [[ "$EKS_STATUS" != "NOT_FOUND" ]]; then
  log_step $((++CURRENT_STEP)) $TOTAL_STEPS "Deleting EKS cluster ($EKS_CLUSTER)..."
  log_warn "This will take 10-15 minutes..."

  eksctl delete cluster \
    --name "$EKS_CLUSTER" \
    --profile "$AWS_PROFILE" \
    --region "$AWS_REGION" \
    --wait

  tee_log "Action: EKS cluster deleted"
  log_success "EKS cluster deleted"
else
  log_step $((++CURRENT_STEP)) $TOTAL_STEPS "Skipping EKS deletion (already gone)"
fi

# Step 6: Delete RDS instance
if [[ "$RDS_STATUS" != "NOT_FOUND" ]]; then
  log_step $((++CURRENT_STEP)) $TOTAL_STEPS "Deleting RDS instance ($RDS_INSTANCE)..."

  if [[ "$SKIP_RDS_SNAPSHOT" == "true" ]]; then
    log_info "  Deleting without final snapshot (--skip-rds-snapshot)"
    aws_cmd rds delete-db-instance \
      --db-instance-identifier "$RDS_INSTANCE" \
      --skip-final-snapshot

    tee_log "Action: RDS deletion initiated (no final snapshot)"
  else
    FINAL_SNAPSHOT="industrynight-db-final-$(date +%Y%m%d-%H%M%S)"
    log_info "  Creating final snapshot: $FINAL_SNAPSHOT"

    aws_cmd rds delete-db-instance \
      --db-instance-identifier "$RDS_INSTANCE" \
      --final-db-snapshot-identifier "$FINAL_SNAPSHOT"

    tee_log "Action: RDS deletion initiated (snapshot: $FINAL_SNAPSHOT)"
  fi

  log_info "  Waiting for RDS deletion (this may take several minutes)..."
  aws_cmd rds wait db-instance-deleted \
    --db-instance-identifier "$RDS_INSTANCE" 2>/dev/null || true

  tee_log "Action: RDS instance deleted"
  log_success "RDS instance deleted"
else
  log_step $((++CURRENT_STEP)) $TOTAL_STEPS "Skipping RDS deletion (already gone)"
fi

# Step 7: Final verification
log_step $TOTAL_STEPS $TOTAL_STEPS "Verifying preserved resources..."

S3_CHECK=$(aws_cmd s3api head-bucket --bucket "$S3_ASSETS_BUCKET" 2>/dev/null && echo "exists" || echo "MISSING")
ECR_CHECK=$(aws_cmd ecr describe-repositories --repository-names "$ECR_REPO" \
  --query 'repositories[0].repositoryName' --output text 2>/dev/null || echo "MISSING")
R53_CHECK=$(aws_cmd route53 get-hosted-zone --id "$HOSTED_ZONE_ID" \
  --query 'HostedZone.Name' --output text 2>/dev/null || echo "MISSING")
SM_CHECK=$(aws_cmd secretsmanager describe-secret --secret-id "$SECRETS_ID" \
  --query 'Name' --output text 2>/dev/null || echo "MISSING")

tee_log ""
tee_log "=== Preserved Resources ==="
tee_log "  S3 ($S3_ASSETS_BUCKET): $S3_CHECK"
tee_log "  ECR ($ECR_REPO): $ECR_CHECK"
tee_log "  Route 53 ($DOMAIN): $R53_CHECK"
tee_log "  Secrets Manager ($SECRETS_ID): $SM_CHECK"
tee_log ""
tee_log "=== Teardown Complete ==="

echo ""
echo -e "${BOLD}=== Teardown Complete ===${NC}"
echo "  Manifest: $MANIFEST"
echo ""
echo "  To rebuild: ./scripts/coop/coop.sh rebuild"
echo "  To check:   ./scripts/coop/coop.sh status"
