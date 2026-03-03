#!/bin/bash
set -euo pipefail

# infra-teardown.sh — Tear down EKS cluster and RDS database
#
# Strategy:
#   1. Clean up K8s resources gracefully (scale down, delete ingress/ALB)
#   2. Try eksctl delete cluster (handles CF stacks, IAM, OIDC)
#   3. If eksctl fails, fall back to:
#      a. Delete nodegroups via EKS API
#      b. Delete cluster via EKS API
#      c. Clean up CloudFormation stacks (with --retain-resources fallback)
#      d. Clean up orphaned VPC resources (NAT gateways, subnets, IGW, etc.)
#   4. Delete RDS instance
#   5. Clean up DB subnet group (orphaned after VPC deletion)
#   6. Verify preserved resources
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
#   ./scripts/coop/infra-teardown.sh [--env dev|prod] [--yes]
#   ./scripts/coop/infra-teardown.sh [--env dev|prod] [--skip-rds-snapshot] [--yes]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"

parse_env_flag "$@"
set -- "${PASSTHROUGH_ARGS[@]+"${PASSTHROUGH_ARGS[@]}"}"
load_environment "$IN_ENV"

SKIP_CONFIRM=false
SKIP_RDS_SNAPSHOT=false
for arg in "$@"; do
  case $arg in
    --yes) SKIP_CONFIRM=true ;;
    --skip-rds-snapshot) SKIP_RDS_SNAPSHOT=true ;;
    *) log_error "Unknown option: $arg"; exit 1 ;;
  esac
done

TOTAL_STEPS=8
CURRENT_STEP=0

env_color=$CYAN
[[ "$ENV_NAME" == "prod" ]] && env_color=$RED

echo -e "${BOLD}=== Infrastructure Teardown ===${NC}"
ENV_UPPER=$(echo "$ENV_NAME" | tr '[:lower:]' '[:upper:]')
echo -e "  Environment: ${env_color}${ENV_UPPER}${NC} ($ENV_LABEL)"
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

# Capture VPC ID before deletion (needed for orphan cleanup)
VPC_ID=""
if [[ "$EKS_STATUS" != "NOT_FOUND" ]]; then
  VPC_ID=$(aws_cmd eks describe-cluster --name "$EKS_CLUSTER" \
    --query 'cluster.resourcesVpcConfig.vpcId' --output text 2>/dev/null || echo "")
  tee_log "VPC ID: $VPC_ID"
fi

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
  "$SCRIPT_DIR/../maintenance.sh" --env "$IN_ENV" on 2>/dev/null || log_warn "Maintenance mode failed (may already be enabled)"
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

# Step 5: Delete EKS cluster (hardened — eksctl with direct API fallback)
if [[ "$EKS_STATUS" != "NOT_FOUND" ]]; then
  log_step $((++CURRENT_STEP)) $TOTAL_STEPS "Deleting EKS cluster ($EKS_CLUSTER)..."
  log_warn "This will take 15-25 minutes..."

  # --- 5a: Try eksctl (happy path) ---
  EKSCTL_SUCCESS=false
  log_info "  Attempting eksctl delete cluster..."

  if eksctl delete cluster \
    --name "$EKS_CLUSTER" \
    --profile "$AWS_PROFILE" \
    --region "$AWS_REGION" \
    --wait 2>&1 | tee -a "$MANIFEST"; then
    EKSCTL_SUCCESS=true
    tee_log "Action: EKS cluster deleted via eksctl"
    log_success "  EKS cluster deleted (eksctl)"
  else
    log_warn "  eksctl failed. Falling back to direct cleanup..."
    tee_log "Action: eksctl failed — falling back to direct API cleanup"
  fi

  # --- 5b: Fallback — delete nodegroups via EKS API ---
  if [[ "$EKSCTL_SUCCESS" == "false" ]]; then

    NODEGROUPS=$(aws_cmd eks list-nodegroups --cluster-name "$EKS_CLUSTER" \
      --query 'nodegroups[]' --output text 2>/dev/null || echo "")

    for ng in $NODEGROUPS; do
      NG_STATUS=$(aws_cmd eks describe-nodegroup --cluster-name "$EKS_CLUSTER" \
        --nodegroup-name "$ng" --query 'nodegroup.status' --output text 2>/dev/null || echo "GONE")

      if [[ "$NG_STATUS" != "GONE" && "$NG_STATUS" != "DELETING" ]]; then
        log_info "  Deleting nodegroup: $ng (status: $NG_STATUS)..."
        aws_cmd eks delete-nodegroup \
          --cluster-name "$EKS_CLUSTER" \
          --nodegroup-name "$ng" 2>/dev/null || true
      fi

      if [[ "$NG_STATUS" != "GONE" ]]; then
        log_info "  Waiting for nodegroup $ng deletion (may take 5-10 min)..."
        # Two attempts — waiter has a timeout
        aws_cmd eks wait nodegroup-deleted \
          --cluster-name "$EKS_CLUSTER" \
          --nodegroup-name "$ng" 2>/dev/null || \
        aws_cmd eks wait nodegroup-deleted \
          --cluster-name "$EKS_CLUSTER" \
          --nodegroup-name "$ng" 2>/dev/null || \
          log_warn "  Nodegroup $ng wait timed out (may still be deleting)"
      fi
    done
    tee_log "Action: Nodegroups deleted via EKS API"

    # --- 5c: Delete cluster via EKS API ---
    CLUSTER_CHECK=$(aws_cmd eks describe-cluster --name "$EKS_CLUSTER" \
      --query 'cluster.status' --output text 2>/dev/null || echo "GONE")

    if [[ "$CLUSTER_CHECK" != "GONE" ]]; then
      if [[ "$CLUSTER_CHECK" != "DELETING" ]]; then
        log_info "  Deleting cluster via EKS API..."
        aws_cmd eks delete-cluster --name "$EKS_CLUSTER" 2>/dev/null || true
      fi

      log_info "  Waiting for cluster deletion..."
      aws_cmd eks wait cluster-deleted --name "$EKS_CLUSTER" 2>/dev/null || \
      aws_cmd eks wait cluster-deleted --name "$EKS_CLUSTER" 2>/dev/null || \
        log_warn "  Cluster deletion wait timed out"
    fi
    tee_log "Action: EKS cluster deleted via direct API"

    # --- 5d: Clean up CloudFormation stacks ---
    log_info "  Cleaning up CloudFormation stacks..."

    CF_STACKS=$(aws_cmd cloudformation list-stacks \
      --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE DELETE_FAILED ROLLBACK_COMPLETE \
      --query "StackSummaries[?contains(StackName,'${EKS_CLUSTER}')].StackName" \
      --output text 2>/dev/null || echo "")

    for stack in $CF_STACKS; do
      log_info "    Deleting stack: $stack"
      aws_cmd cloudformation delete-stack --stack-name "$stack" 2>/dev/null || true

      if ! aws_cmd cloudformation wait stack-delete-complete \
        --stack-name "$stack" 2>/dev/null; then
        log_warn "    Stack $stack failed to delete. Retrying with --retain-resources..."

        FAILED_RESOURCES=$(aws_cmd cloudformation describe-stack-resources \
          --stack-name "$stack" \
          --query "StackResources[?ResourceStatus!='DELETE_COMPLETE'].LogicalResourceId" \
          --output text 2>/dev/null || echo "")

        if [[ -n "$FAILED_RESOURCES" ]]; then
          log_info "    Retaining stuck resources: $FAILED_RESOURCES"
          aws_cmd cloudformation delete-stack \
            --stack-name "$stack" \
            --retain-resources $FAILED_RESOURCES 2>/dev/null || true
          aws_cmd cloudformation wait stack-delete-complete \
            --stack-name "$stack" 2>/dev/null || \
            log_warn "    Stack $stack still stuck. May need manual cleanup."
        fi
      fi
    done
    tee_log "Action: CloudFormation stacks cleaned up"

    # --- 5e: Clean up orphaned VPC resources ---
    if [[ -n "$VPC_ID" ]]; then
      VPC_EXISTS=$(aws_cmd ec2 describe-vpcs --vpc-ids "$VPC_ID" \
        --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "GONE")

      if [[ "$VPC_EXISTS" != "GONE" ]]; then
        log_info "  Cleaning up orphaned VPC resources ($VPC_ID)..."

        # Delete NAT gateways
        NAT_GWS=$(aws_cmd ec2 describe-nat-gateways \
          --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available,pending" \
          --query 'NatGateways[].NatGatewayId' --output text 2>/dev/null || echo "")
        for nat in $NAT_GWS; do
          log_info "    Deleting NAT gateway: $nat"
          aws_cmd ec2 delete-nat-gateway --nat-gateway-id "$nat" 2>/dev/null || true
        done

        # Wait for NAT gateways to fully delete
        if [[ -n "$NAT_GWS" ]]; then
          log_info "    Waiting for NAT gateway deletion..."
          for nat in $NAT_GWS; do
            wait_attempts=0
            while [[ $wait_attempts -lt 40 ]]; do
              NAT_STATE=$(aws_cmd ec2 describe-nat-gateways --nat-gateway-ids "$nat" \
                --query 'NatGateways[0].State' --output text 2>/dev/null || echo "deleted")
              if [[ "$NAT_STATE" == "deleted" || "$NAT_STATE" == "failed" ]]; then
                break
              fi
              sleep 5
              wait_attempts=$((wait_attempts + 1))
            done
          done
        fi

        # Release Elastic IPs tagged with our cluster
        EIPS=$(aws_cmd ec2 describe-addresses \
          --filters "Name=domain,Values=vpc" \
          --query "Addresses[?Tags[?Key=='aws:cloudformation:stack-name' && contains(Value,'${EKS_CLUSTER}')]].AllocationId" \
          --output text 2>/dev/null || echo "")
        for eip in $EIPS; do
          log_info "    Releasing EIP: $eip"
          aws_cmd ec2 release-address --allocation-id "$eip" 2>/dev/null || true
        done

        # Detach and delete internet gateways
        IGWS=$(aws_cmd ec2 describe-internet-gateways \
          --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
          --query 'InternetGateways[].InternetGatewayId' --output text 2>/dev/null || echo "")
        for igw in $IGWS; do
          log_info "    Detaching internet gateway: $igw"
          aws_cmd ec2 detach-internet-gateway --internet-gateway-id "$igw" --vpc-id "$VPC_ID" 2>/dev/null || true
          aws_cmd ec2 delete-internet-gateway --internet-gateway-id "$igw" 2>/dev/null || true
        done

        # Delete non-main route table associations, then route tables
        ROUTE_TABLES=$(aws_cmd ec2 describe-route-tables \
          --filters "Name=vpc-id,Values=$VPC_ID" \
          --query "RouteTables[?Associations[?Main!=\`true\`]].RouteTableId" \
          --output text 2>/dev/null || echo "")
        for rt in $ROUTE_TABLES; do
          ASSOC_IDS=$(aws_cmd ec2 describe-route-tables --route-table-ids "$rt" \
            --query "RouteTables[0].Associations[?Main!=\`true\`].RouteTableAssociationId" \
            --output text 2>/dev/null || echo "")
          for assoc in $ASSOC_IDS; do
            aws_cmd ec2 disassociate-route-table --association-id "$assoc" 2>/dev/null || true
          done
          aws_cmd ec2 delete-route-table --route-table-id "$rt" 2>/dev/null || true
        done

        # Delete subnets
        SUBNETS=$(aws_cmd ec2 describe-subnets \
          --filters "Name=vpc-id,Values=$VPC_ID" \
          --query 'Subnets[].SubnetId' --output text 2>/dev/null || echo "")
        for subnet in $SUBNETS; do
          aws_cmd ec2 delete-subnet --subnet-id "$subnet" 2>/dev/null || true
        done

        # Delete non-default security groups
        SGS=$(aws_cmd ec2 describe-security-groups \
          --filters "Name=vpc-id,Values=$VPC_ID" \
          --query "SecurityGroups[?GroupName!='default'].GroupId" \
          --output text 2>/dev/null || echo "")
        for sg in $SGS; do
          aws_cmd ec2 delete-security-group --group-id "$sg" 2>/dev/null || true
        done

        # Delete VPC
        aws_cmd ec2 delete-vpc --vpc-id "$VPC_ID" 2>/dev/null || \
          log_warn "  Could not delete VPC $VPC_ID (may have remaining dependencies)"

        tee_log "Action: VPC $VPC_ID cleaned up"
        log_success "  VPC cleanup complete"
      fi
    fi

    log_success "  EKS cluster and associated resources cleaned up"
  fi
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
    FINAL_SNAPSHOT="${RDS_INSTANCE}-final-$(date +%Y%m%d-%H%M%S)"
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

# Step 7: Clean up DB subnet group
log_step $((++CURRENT_STEP)) $TOTAL_STEPS "Cleaning up DB subnet group..."

if aws_cmd rds describe-db-subnet-groups \
  --db-subnet-group-name "$RDS_SUBNET_GROUP" &>/dev/null 2>&1; then
  aws_cmd rds delete-db-subnet-group \
    --db-subnet-group-name "$RDS_SUBNET_GROUP" 2>/dev/null && \
    log_success "  DB subnet group deleted" || \
    log_warn "  Could not delete DB subnet group (may still be in use)"
  tee_log "Action: DB subnet group cleanup attempted"
else
  log_info "  DB subnet group already gone"
fi

# Step 8: Final verification
log_step $TOTAL_STEPS $TOTAL_STEPS "Verifying preserved resources..."

S3_CHECK=$(aws_cmd s3api head-bucket --bucket "$S3_ASSETS_BUCKET" &>/dev/null && echo "exists" || echo "MISSING")
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
echo -e "${BOLD}=== Teardown Complete ($ENV_NAME) ===${NC}"
echo "  Manifest: $MANIFEST"
echo ""
echo "  To rebuild: ./scripts/coop/coop.sh --env $ENV_NAME rebuild"
echo "  To check:   ./scripts/coop/coop.sh --env $ENV_NAME status"
