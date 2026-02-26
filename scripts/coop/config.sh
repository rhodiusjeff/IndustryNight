#!/bin/bash
# config.sh — Shared constants and helpers for COOP scripts
#
# Sourced by all other scripts in scripts/coop/
# Do not execute directly.

# ---- Project Root ----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ---- AWS Configuration ----
AWS_PROFILE="industrynight-admin"
AWS_REGION="us-east-1"
AWS_ACCOUNT="047593684855"

# ---- EKS ----
EKS_CLUSTER="industrynight-prod"
EKS_NODEGROUP="standard-workers-v2"
EKS_CLUSTER_CONFIG="infrastructure/eks/cluster.yaml"

# ---- RDS ----
RDS_INSTANCE="industrynight-db"
RDS_ENGINE="postgres"
RDS_ENGINE_VERSION="16.4"
RDS_INSTANCE_CLASS="db.t3.micro"
RDS_STORAGE="20"
RDS_MASTER_USER="industrynight"
RDS_DB_NAME="industrynight"
RDS_SUBNET_GROUP="industrynight-db-subnet"

# ---- Kubernetes ----
K8S_NAMESPACE="industrynight"
K8S_DEPLOYMENT="industrynight-api"
K8S_MANIFESTS_DIR="infrastructure/k8s"

# ---- ECR ----
ECR_REPO="industrynight-api"
ECR_URI="${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"

# ---- S3 ----
S3_ASSETS_BUCKET="industrynight-assets-prod"
S3_WEB_BUCKET="industrynight-web-admin"

# ---- Secrets Manager ----
SECRETS_ID="industrynight/database"

# ---- Route 53 ----
HOSTED_ZONE_ID="Z06747281HOR0DFK445GN"
DOMAIN="industrynight.net"

# ---- ACM ----
ACM_CERT_ARN="arn:aws:acm:us-east-1:047593684855:certificate/97021927-0213-4347-90fa-8e8113ef4a52"

# ---- Database Tables (FK-ordered for export/import) ----
# Tier 0: No foreign keys
# Tier 1: References tier 0 only
# Tier 2: References tier 0 + 1
# Tier 3: References tier 2
# Tier 4: Audit + analytics (can reference anything)
TIER_0_TABLES="specialties venues users verification_codes"
TIER_1_TABLES="events sponsors"
TIER_2_TABLES="tickets connections posts vendors discounts"
TIER_3_TABLES="post_comments post_likes event_vendors"
TIER_4_TABLES="audit_log data_export_requests analytics_connections_daily analytics_users_daily analytics_events analytics_influence"
ALL_TABLES_ORDERED="$TIER_0_TABLES $TIER_1_TABLES $TIER_2_TABLES $TIER_3_TABLES $TIER_4_TABLES"

# ---- Migrations and Seeds ----
MIGRATIONS_DIR="packages/database/migrations"
SEEDS_DIR="packages/database/seeds"
MIGRATION_FILES="001_initial_schema.sql 002_add_sponsors.sql"

# ---- Backups ----
BACKUPS_DIR="backups"

# ---- Colors ----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ---- Helper Functions ----

log_info() {
  echo -e "${CYAN}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
  local step=$1
  local total=$2
  local msg=$3
  echo -e "\n${BOLD}[$step/$total]${NC} $msg"
}

# Run AWS CLI with profile
aws_cmd() {
  AWS_PROFILE=$AWS_PROFILE aws --region $AWS_REGION "$@"
}

# Run kubectl with AWS profile
kube_cmd() {
  AWS_PROFILE=$AWS_PROFILE kubectl "$@"
}

# Safety confirmation prompt (skipped if SKIP_CONFIRM=true)
confirm_destructive() {
  local message=$1
  if [[ "${SKIP_CONFIRM:-false}" == "true" ]]; then
    return 0
  fi
  echo ""
  echo -e "${RED}${BOLD}WARNING:${NC} $message"
  echo ""
  read -p "Type 'yes' to confirm: " answer
  if [[ "$answer" != "yes" ]]; then
    echo "Aborted."
    exit 0
  fi
}

# Verify AWS credentials are valid
check_aws_credentials() {
  log_info "Verifying AWS credentials..."
  local identity
  identity=$(aws_cmd sts get-caller-identity --query 'Arn' --output text 2>/dev/null)
  if [[ $? -ne 0 ]]; then
    log_error "AWS credentials are not valid. Check AWS_PROFILE=$AWS_PROFILE"
    exit 1
  fi
  log_success "Authenticated as: $identity"
}

# Check that required CLI tools are installed
check_prerequisites() {
  local missing=0
  for cmd in aws eksctl kubectl psql pg_dump pg_restore; do
    if ! command -v "$cmd" &>/dev/null; then
      log_error "Required tool not found: $cmd"
      missing=1
    fi
  done
  if [[ $missing -eq 1 ]]; then
    log_error "Install missing tools before continuing."
    exit 1
  fi
  log_success "All prerequisite tools found"
}

# Check prerequisites including helm (needed for rebuild)
check_prerequisites_with_helm() {
  check_prerequisites
  if ! command -v helm &>/dev/null; then
    log_error "Required tool not found: helm (needed for ALB controller installation)"
    exit 1
  fi
}

# Port-forward management
PORT_FORWARD_PID=""

start_port_forward() {
  local local_port=${1:-5432}

  # Kill any existing port-forward on this port
  lsof -ti :"$local_port" 2>/dev/null | xargs kill 2>/dev/null || true
  sleep 1

  log_info "Starting port-forward to db-proxy on port $local_port..."
  kube_cmd port-forward pod/db-proxy "$local_port:5432" -n "$K8S_NAMESPACE" &>/dev/null &
  PORT_FORWARD_PID=$!

  # Wait for port to be ready
  local attempts=0
  while ! nc -z localhost "$local_port" 2>/dev/null; do
    sleep 1
    attempts=$((attempts + 1))
    if [[ $attempts -ge 15 ]]; then
      log_error "Port-forward failed to become ready after 15 seconds"
      kill "$PORT_FORWARD_PID" 2>/dev/null || true
      exit 1
    fi
  done
  log_success "Port-forward ready (PID $PORT_FORWARD_PID)"
}

stop_port_forward() {
  if [[ -n "${PORT_FORWARD_PID:-}" ]]; then
    kill "$PORT_FORWARD_PID" 2>/dev/null || true
    PORT_FORWARD_PID=""
    log_info "Port-forward stopped"
  fi
}

# Get DB password from Secrets Manager
get_db_password() {
  local secret_json
  secret_json=$(aws_cmd secretsmanager get-secret-value \
    --secret-id "$SECRETS_ID" \
    --query 'SecretString' --output text 2>/dev/null)
  if [[ $? -ne 0 ]]; then
    log_error "Failed to retrieve database credentials from Secrets Manager ($SECRETS_ID)"
    exit 1
  fi
  echo "$secret_json" | python3 -c "import sys, json; print(json.load(sys.stdin)['password'])"
}

# Create timestamp for backup directory naming
create_timestamp() {
  date +"%Y-%m-%d_%H%M%S"
}
