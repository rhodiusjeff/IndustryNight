#!/bin/bash
set -euo pipefail

# infra-rebuild.sh — Rebuild EKS cluster and RDS from scratch
#
# Sequence:
#   1. Verify preserved resources (S3, ECR, Secrets Manager, Route 53, ACM)
#   2. Create EKS cluster from infrastructure/eks/cluster.yaml
#   3. Install AWS Load Balancer Controller via Helm
#   4. Create RDS instance (or wait for existing stopped one)
#   5. Update Secrets Manager with new RDS endpoint
#   6. Apply Kubernetes manifests
#   7. Create db-proxy pod
#   8. Run database migrations via K8s Job
#   9. Deploy API from ECR image
#  10. Verify health
#
# Usage:
#   ./scripts/coop/infra-rebuild.sh [--env dev|prod] [--yes]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"

parse_env_flag "$@"
set -- "${PASSTHROUGH_ARGS[@]+"${PASSTHROUGH_ARGS[@]}"}"
load_environment "$IN_ENV"

SKIP_CONFIRM=false
for arg in "$@"; do
  case $arg in
    --yes) SKIP_CONFIRM=true ;;
    *) log_error "Unknown option: $arg"; exit 1 ;;
  esac
done

TOTAL_STEPS=10
CURRENT_STEP=0

env_color=$CYAN
[[ "$ENV_NAME" == "prod" ]] && env_color=$RED

echo -e "${BOLD}=== Infrastructure Rebuild ===${NC}"
ENV_UPPER=$(echo "$ENV_NAME" | tr '[:lower:]' '[:upper:]')
echo -e "  Environment: ${env_color}${ENV_UPPER}${NC} ($ENV_LABEL)"
echo ""

confirm_destructive "This will create new EKS and RDS resources (AWS costs begin immediately)."

# Step 1: Prerequisites
log_step $((++CURRENT_STEP)) $TOTAL_STEPS "Verifying prerequisites..."
check_prerequisites_with_helm
check_aws_credentials

# Step 2: Verify preserved resources
log_step $((++CURRENT_STEP)) $TOTAL_STEPS "Verifying preserved resources..."

MISSING=0

# ECR (required — need an image to deploy)
if aws_cmd ecr describe-repositories --repository-names "$ECR_REPO" &>/dev/null; then
  IMAGE_COUNT=$(aws_cmd ecr list-images --repository-name "$ECR_REPO" \
    --query 'imageIds | length(@)' --output text 2>/dev/null || echo "0")
  log_success "  ECR: $ECR_REPO ($IMAGE_COUNT images)"
  if [[ "$IMAGE_COUNT" -eq 0 ]]; then
    log_warn "  ECR has no images — you will need to build and push before API can start"
  fi
else
  log_error "  ECR repository missing: $ECR_REPO"
  MISSING=1
fi

# Secrets Manager (required — contains DB password)
if aws_cmd secretsmanager describe-secret --secret-id "$SECRETS_ID" &>/dev/null; then
  log_success "  Secrets Manager: $SECRETS_ID"
else
  log_error "  Secrets Manager missing: $SECRETS_ID"
  MISSING=1
fi

# S3 (informational)
for bucket in $S3_ASSETS_BUCKET $S3_WEB_BUCKET; do
  if aws_cmd s3api head-bucket --bucket "$bucket" 2>/dev/null; then
    log_success "  S3: $bucket"
  else
    log_warn "  S3 bucket missing: $bucket (non-blocking)"
  fi
done

# Route 53 (informational)
if aws_cmd route53 get-hosted-zone --id "$HOSTED_ZONE_ID" &>/dev/null; then
  log_success "  Route 53: $DOMAIN"
else
  log_warn "  Route 53 zone missing (DNS will need manual setup)"
fi

# ACM (informational — HTTPS won't work without it)
if aws_cmd acm describe-certificate --certificate-arn "$ACM_CERT_ARN" &>/dev/null; then
  log_success "  ACM certificate"
else
  log_warn "  ACM certificate missing (HTTPS will not work until recreated)"
fi

if [[ $MISSING -eq 1 ]]; then
  log_error "Critical resources are missing. Cannot proceed."
  exit 1
fi

# Step 3: Create EKS cluster
log_step $((++CURRENT_STEP)) $TOTAL_STEPS "Creating EKS cluster ($EKS_CLUSTER)..."

EKS_EXISTS=$(aws_cmd eks describe-cluster --name "$EKS_CLUSTER" \
  --query 'cluster.status' --output text 2>/dev/null || echo "NOT_FOUND")

if [[ "$EKS_EXISTS" == "ACTIVE" ]]; then
  log_warn "  EKS cluster already exists and is ACTIVE. Skipping creation."
else
  log_warn "  This will take 15-20 minutes..."
  CLUSTER_CONFIG=$(generate_cluster_config)
  log_info "  Using cluster config: $CLUSTER_CONFIG"
  eksctl create cluster \
    -f "$CLUSTER_CONFIG" \
    --profile "$AWS_PROFILE"

  log_success "  EKS cluster created"
fi

# Update kubeconfig
aws_cmd eks update-kubeconfig \
  --name "$EKS_CLUSTER" \
  --region "$AWS_REGION"

# Verify nodes
log_info "  Waiting for nodes to be Ready..."
kube_cmd wait --for=condition=Ready nodes --all --timeout=300s
log_success "  Nodes are ready"

# Step 4: Install AWS Load Balancer Controller
log_step $((++CURRENT_STEP)) $TOTAL_STEPS "Installing AWS Load Balancer Controller..."

if kube_cmd get deployment -n kube-system aws-load-balancer-controller &>/dev/null; then
  log_warn "  ALB controller already installed. Skipping."
else
  # Create IAM policy
  log_info "  Downloading ALB controller IAM policy..."
  curl -sS -o /tmp/alb-iam-policy.json \
    https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.1/docs/install/iam_policy.json

  ALB_POLICY_ARN=$(aws_cmd iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file:///tmp/alb-iam-policy.json \
    --query 'Policy.Arn' --output text 2>/dev/null || \
    aws_cmd iam list-policies \
      --query "Policies[?PolicyName=='AWSLoadBalancerControllerIAMPolicy'].Arn" \
      --output text)

  log_info "  Creating IRSA service account..."
  eksctl create iamserviceaccount \
    --cluster="$EKS_CLUSTER" \
    --namespace=kube-system \
    --name=aws-load-balancer-controller \
    --attach-policy-arn="$ALB_POLICY_ARN" \
    --override-existing-serviceaccounts \
    --approve \
    --profile "$AWS_PROFILE"

  log_info "  Installing via Helm..."
  helm repo add eks https://aws.github.io/eks-charts 2>/dev/null || true
  helm repo update eks
  helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n kube-system \
    --set clusterName="$EKS_CLUSTER" \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-load-balancer-controller

  kube_cmd rollout status deployment/aws-load-balancer-controller \
    -n kube-system --timeout=120s
  log_success "  ALB controller installed"
fi

# Step 5: Create or start RDS instance
log_step $((++CURRENT_STEP)) $TOTAL_STEPS "Setting up RDS instance ($RDS_INSTANCE)..."

RDS_EXISTS=$(aws_cmd rds describe-db-instances --db-instance-identifier "$RDS_INSTANCE" \
  --query 'DBInstances[0].DBInstanceStatus' --output text 2>/dev/null || echo "NOT_FOUND")

if [[ "$RDS_EXISTS" == "available" ]]; then
  log_warn "  RDS instance already available. Skipping creation."
  NEW_RDS_ENDPOINT=$(aws_cmd rds describe-db-instances --db-instance-identifier "$RDS_INSTANCE" \
    --query 'DBInstances[0].Endpoint.Address' --output text)

elif [[ "$RDS_EXISTS" == "stopped" ]]; then
  log_info "  RDS instance is stopped. Starting..."
  aws_cmd rds start-db-instance --db-instance-identifier "$RDS_INSTANCE"
  log_info "  Waiting for RDS to become available..."
  aws_cmd rds wait db-instance-available --db-instance-identifier "$RDS_INSTANCE"
  NEW_RDS_ENDPOINT=$(aws_cmd rds describe-db-instances --db-instance-identifier "$RDS_INSTANCE" \
    --query 'DBInstances[0].Endpoint.Address' --output text)
  log_success "  RDS instance started"

elif [[ "$RDS_EXISTS" == "NOT_FOUND" ]]; then
  log_info "  Creating new RDS instance..."

  # Get DB password from Secrets Manager
  DB_PASSWORD=$(get_db_password)

  # Discover VPC from the new EKS cluster
  VPC_ID=$(aws_cmd eks describe-cluster --name "$EKS_CLUSTER" \
    --query 'cluster.resourcesVpcConfig.vpcId' --output text)
  log_info "  VPC: $VPC_ID"

  # Delete old DB subnet group if it exists (may reference subnets from previous VPC)
  aws_cmd rds delete-db-subnet-group \
    --db-subnet-group-name "$RDS_SUBNET_GROUP" 2>/dev/null || true

  log_info "  Creating DB subnet group..."
  PRIVATE_SUBNETS=$(aws_cmd ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=*Private*" \
    --query 'Subnets[].SubnetId' --output text)
  aws_cmd rds create-db-subnet-group \
    --db-subnet-group-name "$RDS_SUBNET_GROUP" \
    --db-subnet-group-description "Industry Night RDS subnet group" \
    --subnet-ids $PRIVATE_SUBNETS

  # Create security group for RDS if needed
  RDS_SG=$(aws_cmd ec2 describe-security-groups \
    --filters "Name=group-name,Values=industrynight-rds-sg" "Name=vpc-id,Values=$VPC_ID" \
    --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "None")

  if [[ "$RDS_SG" == "None" ]]; then
    log_info "  Creating RDS security group..."
    RDS_SG=$(aws_cmd ec2 create-security-group \
      --group-name industrynight-rds-sg \
      --description "Industry Night RDS" \
      --vpc-id "$VPC_ID" \
      --output text --query 'GroupId')

    EKS_SG=$(aws_cmd eks describe-cluster --name "$EKS_CLUSTER" \
      --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' --output text)

    aws_cmd ec2 authorize-security-group-ingress \
      --group-id "$RDS_SG" --protocol tcp --port 5432 --source-group "$EKS_SG"
  fi

  # Create RDS instance
  aws_cmd rds create-db-instance \
    --db-instance-identifier "$RDS_INSTANCE" \
    --db-instance-class "$RDS_INSTANCE_CLASS" \
    --engine "$RDS_ENGINE" \
    --engine-version "$RDS_ENGINE_VERSION" \
    --master-username "$RDS_MASTER_USER" \
    --master-user-password "$DB_PASSWORD" \
    --allocated-storage "$RDS_STORAGE" \
    --storage-type gp2 \
    --db-subnet-group-name "$RDS_SUBNET_GROUP" \
    --vpc-security-group-ids "$RDS_SG" \
    --db-name "$RDS_DB_NAME" \
    --no-publicly-accessible \
    --backup-retention-period 0 \
    --no-multi-az \
    --no-storage-encrypted

  log_info "  Waiting for RDS to become available (5-10 minutes)..."
  aws_cmd rds wait db-instance-available --db-instance-identifier "$RDS_INSTANCE"

  NEW_RDS_ENDPOINT=$(aws_cmd rds describe-db-instances --db-instance-identifier "$RDS_INSTANCE" \
    --query 'DBInstances[0].Endpoint.Address' --output text)
  log_success "  RDS instance created"
else
  log_info "  RDS status: $RDS_EXISTS — waiting for it to become available..."
  aws_cmd rds wait db-instance-available --db-instance-identifier "$RDS_INSTANCE"
  NEW_RDS_ENDPOINT=$(aws_cmd rds describe-db-instances --db-instance-identifier "$RDS_INSTANCE" \
    --query 'DBInstances[0].Endpoint.Address' --output text)
fi

log_info "  RDS endpoint: $NEW_RDS_ENDPOINT"

# Step 6: Update Secrets Manager with new endpoint
log_step $((++CURRENT_STEP)) $TOTAL_STEPS "Updating Secrets Manager..."

SECRET_JSON=$(aws_cmd secretsmanager get-secret-value --secret-id "$SECRETS_ID" \
  --query 'SecretString' --output text)

# Update the host field
UPDATED_SECRET=$(echo "$SECRET_JSON" | python3 -c "
import sys, json
d = json.load(sys.stdin)
d['host'] = '$NEW_RDS_ENDPOINT'
print(json.dumps(d))
")
aws_cmd secretsmanager update-secret --secret-id "$SECRETS_ID" \
  --secret-string "$UPDATED_SECRET"
log_success "  Secrets Manager updated with endpoint: $NEW_RDS_ENDPOINT"

# Extract credentials for K8s secret creation
DB_HOST_VAL="$NEW_RDS_ENDPOINT"
DB_USER_VAL=$(echo "$SECRET_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin).get('username', '$RDS_MASTER_USER'))")
DB_PASS_VAL=$(echo "$SECRET_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin)['password'])")
POSH_WEBHOOK_SECRET_VAL=$(echo "$SECRET_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin).get('POSH_WEBHOOK_SECRET', ''))")
POSH_WEBHOOK_COMPAT_MODE_VAL=$(echo "$SECRET_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin).get('POSH_WEBHOOK_COMPAT_MODE', 'false'))")

# Step 7: Apply Kubernetes manifests
log_step $((++CURRENT_STEP)) $TOTAL_STEPS "Applying Kubernetes manifests..."

# Namespace
apply_k8s_manifest "namespace.yaml"
log_info "  Namespace applied"

# Create K8s secret from Secrets Manager values
kube_cmd delete secret industrynight-secrets -n "$K8S_NAMESPACE" 2>/dev/null || true
kube_cmd create secret generic industrynight-secrets \
  --from-literal=DB_HOST="$DB_HOST_VAL" \
  --from-literal=DB_PORT="5432" \
  --from-literal=DB_NAME="$RDS_DB_NAME" \
  --from-literal=DB_USER="$DB_USER_VAL" \
  --from-literal=DB_PASSWORD="$DB_PASS_VAL" \
  --from-literal=JWT_SECRET="$(openssl rand -base64 32)" \
  --from-literal=CORS_ORIGINS="$CORS_ORIGINS" \
  -n "$K8S_NAMESPACE"

if [[ -n "$POSH_WEBHOOK_SECRET_VAL" ]]; then
  kube_cmd patch secret industrynight-secrets -n "$K8S_NAMESPACE" --type merge \
    -p "{\"stringData\":{\"POSH_WEBHOOK_SECRET\":\"$POSH_WEBHOOK_SECRET_VAL\"}}" >/dev/null
  log_info "  Added POSH_WEBHOOK_SECRET to K8s secret"
else
  log_warn "  POSH_WEBHOOK_SECRET missing in Secrets Manager; webhook signature validation will reject requests"
fi

kube_cmd patch secret industrynight-secrets -n "$K8S_NAMESPACE" --type merge \
  -p "{\"stringData\":{\"POSH_WEBHOOK_COMPAT_MODE\":\"$POSH_WEBHOOK_COMPAT_MODE_VAL\"}}" >/dev/null
log_info "  Added POSH_WEBHOOK_COMPAT_MODE=$POSH_WEBHOOK_COMPAT_MODE_VAL to K8s secret"

log_info "  K8s secrets created"

# Deployment, Service, Ingress
apply_k8s_manifest "deployment.yaml"
apply_k8s_manifest "service.yaml"
apply_k8s_manifest "ingress.yaml"
log_success "  Manifests applied"

# Step 8: Create db-proxy pod
log_step $((++CURRENT_STEP)) $TOTAL_STEPS "Creating database proxy pod..."

kube_cmd delete pod/db-proxy -n "$K8S_NAMESPACE" 2>/dev/null || true
sleep 2

kube_cmd run db-proxy \
  --image=alpine/socat \
  -n "$K8S_NAMESPACE" \
  --restart=Never \
  -- -d -d tcp-listen:5432,fork,reuseaddr tcp-connect:"${NEW_RDS_ENDPOINT}:5432"

kube_cmd wait --for=condition=ready pod/db-proxy -n "$K8S_NAMESPACE" --timeout=60s
log_success "  db-proxy pod ready"

# Step 9: Run database migrations
log_step $((++CURRENT_STEP)) $TOTAL_STEPS "Running database migrations..."

export PGPASSWORD="$DB_PASS_VAL"
start_port_forward 5432
trap 'stop_port_forward; unset PGPASSWORD' EXIT

sleep 2

# Create uuid extension
psql -h localhost -p 5432 -U "$RDS_MASTER_USER" -d "$RDS_DB_NAME" \
  -c 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp"' &>/dev/null

# Create migrations tracking table
psql -h localhost -p 5432 -U "$RDS_MASTER_USER" -d "$RDS_DB_NAME" <<'MIGRATION_TABLE' &>/dev/null
CREATE TABLE IF NOT EXISTS _migrations (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE,
    applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
MIGRATION_TABLE

# Run each migration if not already applied
for migration_file in "$PROJECT_ROOT/$MIGRATIONS_DIR"/*.sql; do
  FILENAME=$(basename "$migration_file")
  APPLIED=$(psql -h localhost -p 5432 -U "$RDS_MASTER_USER" -d "$RDS_DB_NAME" \
    -t -A -c "SELECT COUNT(*) FROM _migrations WHERE name = '$FILENAME'" 2>/dev/null)
  APPLIED=$(echo "$APPLIED" | tr -d '[:space:]')

  if [[ "$APPLIED" == "0" ]]; then
    log_info "  Applying: $FILENAME"
    psql -h localhost -p 5432 -U "$RDS_MASTER_USER" -d "$RDS_DB_NAME" \
      -f "$migration_file" &>/dev/null
    psql -h localhost -p 5432 -U "$RDS_MASTER_USER" -d "$RDS_DB_NAME" \
      -c "INSERT INTO _migrations (name) VALUES ('$FILENAME')" &>/dev/null
  else
    log_info "  Already applied: $FILENAME"
  fi
done

# Load specialties seed (reference data, always needed)
log_info "  Loading specialties seed data..."
psql -h localhost -p 5432 -U "$RDS_MASTER_USER" -d "$RDS_DB_NAME" \
  -f "$PROJECT_ROOT/$SEEDS_DIR/specialties.sql" &>/dev/null

log_success "  Migrations and seeds applied"

# Clean up port-forward before deploy
stop_port_forward
unset PGPASSWORD
trap - EXIT

# Step 10: Deploy API and verify
log_step $((++CURRENT_STEP)) $TOTAL_STEPS "Deploying API and verifying health..."

IMAGE_COUNT=$(aws_cmd ecr list-images --repository-name "$ECR_REPO" \
  --query 'imageIds | length(@)' --output text 2>/dev/null || echo "0")

if [[ "$IMAGE_COUNT" -gt 0 ]]; then
  # Pods were just created in step 7 with the correct image.
  # Only wait for them to become ready — no restart needed.
  kube_cmd rollout status deployment/"$K8S_DEPLOYMENT" -n "$K8S_NAMESPACE" --timeout=180s
  log_success "  API deployed"
else
  log_warn "  No ECR image found. Build and push first:"
  log_warn "    ./scripts/deploy-api.sh --env $ENV_NAME"
fi

# Check pods
kube_cmd get pods -n "$K8S_NAMESPACE" -l app="$K8S_DEPLOYMENT"

# Check ALB
ALB_DNS=$(kube_cmd get ingress/"$K8S_DEPLOYMENT" -n "$K8S_NAMESPACE" \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

if [[ -n "$ALB_DNS" ]]; then
  log_info "  ALB DNS: $ALB_DNS"

  # Update Cloudflare DNS to point to new ALB
  log_info "  Updating Cloudflare DNS..."
  update_cloudflare_cname "$CF_API_RECORD_NAME" "$ALB_DNS" || true

  sleep 10
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://${API_HOST}/health" 2>/dev/null || echo "000")
  if [[ "$HTTP_STATUS" == "200" ]]; then
    log_success "  Health check passed (HTTP $HTTP_STATUS)"
  else
    log_warn "  Health check returned HTTP $HTTP_STATUS (ALB may still be provisioning)"
    log_warn "  Try: curl https://${API_HOST}/health"
  fi
else
  log_warn "  ALB not yet provisioned. Check in a few minutes:"
  log_warn "    kubectl get ingress -n $K8S_NAMESPACE"
fi

echo ""
echo -e "${BOLD}=== Rebuild Complete ($ENV_NAME) ===${NC}"
echo ""
echo "  EKS Cluster:  $EKS_CLUSTER"
echo "  RDS Instance: $RDS_INSTANCE"
echo "  RDS Endpoint: $NEW_RDS_ENDPOINT"
echo "  ALB DNS:      $ALB_DNS"
echo "  API Endpoint: https://${API_HOST}/health"
echo ""
echo "  Next steps:"
echo "    - Import data:       ./scripts/coop/coop.sh --env $ENV_NAME import <backup-dir>"
echo "    - Check status:      ./scripts/coop/coop.sh --env $ENV_NAME status"
if [[ "$IMAGE_COUNT" -eq 0 ]]; then
  echo "    - Build & push API:  ./scripts/deploy-api.sh --env $ENV_NAME"
fi
