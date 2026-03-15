#!/bin/bash
# config.sh — Shared constants and helpers for COOP scripts
#
# Sourced by all other scripts in scripts/coop/ and scripts/deploy-*.sh
# Do not execute directly.
#
# Environment-specific values live in scripts/coop/environments/{dev,prod}.env
# Call load_environment() after sourcing this file.

# ---- Project Root ----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENVIRONMENTS_DIR="$SCRIPT_DIR/environments"

# ---- Shared AWS Configuration (same across all environments) ----
AWS_PROFILE="industrynight-admin"
AWS_REGION="us-east-1"
AWS_ACCOUNT="047593684855"
DOMAIN="industrynight.net"

# ---- ECR (shared repo, environment-specific tags) ----
ECR_REPO="industrynight-api"
ECR_URI="${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"

# ---- ACM (wildcard cert covers all environments) ----
ACM_CERT_ARN="arn:aws:acm:us-east-1:047593684855:certificate/97021927-0213-4347-90fa-8e8113ef4a52"

# ---- Route 53 ----
HOSTED_ZONE_ID="Z06747281HOR0DFK445GN"

# ---- Cloudflare ----
CF_SECRETS_ID="industrynight/cloudflare"
CF_ZONE_ID="926771c2c344a268af440e076bd89339"

# ---- RDS Defaults (shared across environments) ----
RDS_ENGINE="postgres"
RDS_ENGINE_VERSION="16.4"
RDS_INSTANCE_CLASS="db.t3.micro"
RDS_STORAGE="20"
RDS_MASTER_USER="industrynight"
RDS_DB_NAME="industrynight"

# ---- Kubernetes ----
K8S_DEPLOYMENT="industrynight-api"
K8S_MANIFESTS_DIR="infrastructure/k8s"

# ---- EKS Cluster Template ----
EKS_CLUSTER_TEMPLATE="infrastructure/eks/cluster.yaml.template"

# ---- Migrations and Seeds ----
MIGRATIONS_DIR="packages/database/migrations"
SEEDS_DIR="packages/database/seeds"

# ---- Backups ----
BACKUPS_DIR="backups"

# ---- Database Tables (FK-ordered for export/import) ----
# Tier 0: No foreign keys
# Tier 1: References tier 0 only
# Tier 2: References tier 0 + 1
# Tier 3: References tier 2
# Tier 4: Audit + analytics (can reference anything)
TIER_0_TABLES="specialties users verification_codes admin_users customers products markets"
TIER_1_TABLES="events"
TIER_2_TABLES="orders customer_products customer_contacts customer_markets customer_media tickets connections posts discounts event_images posh_orders"
TIER_3_TABLES="order_items partner_media post_comments post_likes discount_redemptions"
TIER_4_TABLES="audit_log data_export_requests analytics_connections_daily analytics_users_daily analytics_events analytics_influence"
ALL_TABLES_ORDERED="$TIER_0_TABLES $TIER_1_TABLES $TIER_2_TABLES $TIER_3_TABLES $TIER_4_TABLES"

# ---- Colors ----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ---- Environment Loading ----

# Parse --env flag from any argument list.
# Sets IN_ENV and removes --env from the args.
# Usage: parse_env_flag "$@"; set -- "${PASSTHROUGH_ARGS[@]+"${PASSTHROUGH_ARGS[@]}"}"
PASSTHROUGH_ARGS=()
parse_env_flag() {
  IN_ENV="${IN_ENV:-dev}"  # Default to dev
  PASSTHROUGH_ARGS=()
  while [[ $# -gt 0 ]]; do
    case $1 in
      --env)
        IN_ENV="$2"
        shift 2
        ;;
      *)
        PASSTHROUGH_ARGS+=("$1")
        shift
        ;;
    esac
  done
}

# Load environment-specific configuration.
# Sources the corresponding .env file from scripts/coop/environments/
# Usage: load_environment "dev" or load_environment "prod"
load_environment() {
  local env_name="${1:-dev}"

  local env_file="$ENVIRONMENTS_DIR/${env_name}.env"
  if [[ ! -f "$env_file" ]]; then
    log_error "Environment file not found: $env_file"
    log_error "Available environments:"
    for f in "$ENVIRONMENTS_DIR"/*.env; do
      [[ -f "$f" ]] && echo "  $(basename "$f" .env)"
    done
    exit 1
  fi

  source "$env_file"

  # Derived values
  ECR_IMAGE="${ECR_URI}:${ECR_IMAGE_TAG}"
  BACKUPS_PATH="$PROJECT_ROOT/$BACKUPS_DIR/$BACKUPS_SUBDIR"

  # Export for Node.js scripts
  export IN_ENV="$env_name"
  export IN_NAMESPACE="$K8S_NAMESPACE"
  export IN_DEPLOYMENT="$K8S_DEPLOYMENT"
  export IN_AWS_PROFILE="$AWS_PROFILE"
}

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
# Shows extra warning for production environment
confirm_destructive() {
  local message=$1
  if [[ "${SKIP_CONFIRM:-false}" == "true" ]]; then
    return 0
  fi
  echo ""
  if [[ "${ENV_NAME:-}" == "prod" ]]; then
    echo -e "${RED}${BOLD}!!! PRODUCTION ENVIRONMENT !!!${NC}"
    echo ""
  fi
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

# Apply a K8s manifest with environment-specific placeholder substitution
# Usage: apply_k8s_manifest <filename>
apply_k8s_manifest() {
  local file=$1
  sed -e "s|__NAMESPACE__|${K8S_NAMESPACE}|g" \
      -e "s|__ECR_IMAGE__|${ECR_IMAGE}|g" \
      -e "s|__ACM_CERT_ARN__|${ACM_CERT_ARN}|g" \
      -e "s|__API_HOST__|${API_HOST}|g" \
      -e "s|__ENVIRONMENT__|${ENV_LABEL}|g" \
      -e "s|__HPA_MIN__|${K8S_HPA_MIN}|g" \
      -e "s|__HPA_MAX__|${K8S_HPA_MAX}|g" \
      -e "s|\${AWS_ACCOUNT_ID}|${AWS_ACCOUNT}|g" \
      "$PROJECT_ROOT/$K8S_MANIFESTS_DIR/$file" | kube_cmd apply -f -
}

# Generate eksctl cluster config from template
# Usage: generate_cluster_config -> prints path to generated file
generate_cluster_config() {
  local output="/tmp/industrynight-cluster-${ENV_NAME}.yaml"

  sed -e "s|__CLUSTER_NAME__|${EKS_CLUSTER}|g" \
      -e "s|__REGION__|${AWS_REGION}|g" \
      -e "s|__NAMESPACE__|${K8S_NAMESPACE}|g" \
      -e "s|__NODEGROUP_NAME__|${EKS_NODEGROUP}|g" \
      -e "s|__DESIRED_CAPACITY__|${EKS_DESIRED_CAPACITY}|g" \
      -e "s|__MIN_SIZE__|${EKS_MIN_SIZE}|g" \
      -e "s|__MAX_SIZE__|${EKS_MAX_SIZE}|g" \
      -e "s|__ENVIRONMENT__|${ENV_LABEL}|g" \
      "$PROJECT_ROOT/$EKS_CLUSTER_TEMPLATE" > "$output"

  # Handle CW log types (convert comma-separated to YAML list)
  python3 -c "
import sys
content = open('$output').read()
types = '${CW_LOG_TYPES}'.split(',')
yaml_list = '\n'.join(f'      - {t.strip()}' for t in types)
content = content.replace('    enableTypes: __CW_LOG_TYPES__', f'    enableTypes:\n{yaml_list}')
open('$output', 'w').write(content)
"
  echo "$output"
}

# Update Cloudflare DNS CNAME record
# Usage: update_cloudflare_cname "api.industrynight.net" "new-alb-dns.elb.amazonaws.com"
update_cloudflare_cname() {
  local record_name=$1
  local new_target=$2

  # Get Cloudflare API token from Secrets Manager
  local cf_secret
  cf_secret=$(aws_cmd secretsmanager get-secret-value \
    --secret-id "$CF_SECRETS_ID" \
    --query 'SecretString' --output text 2>/dev/null)
  if [[ $? -ne 0 ]]; then
    log_warn "Cloudflare credentials not found in Secrets Manager ($CF_SECRETS_ID)"
    log_warn "Update DNS manually: $record_name → $new_target"
    return 1
  fi

  local cf_token
  cf_token=$(echo "$cf_secret" | python3 -c "import sys, json; print(json.load(sys.stdin)['api_token'])")

  # Look up the DNS record ID
  local record_id
  record_id=$(curl -s "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records?name=${record_name}&type=CNAME" \
    -H "Authorization: Bearer $cf_token" | \
    python3 -c "import sys, json; r=json.load(sys.stdin); print(r['result'][0]['id'] if r['success'] and r['result'] else '')")

  if [[ -z "$record_id" ]]; then
    log_warn "Cloudflare DNS record not found for $record_name"
    log_warn "Update DNS manually: $record_name → $new_target"
    return 1
  fi

  # Update the record
  local result
  result=$(curl -s -X PATCH \
    "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records/${record_id}" \
    -H "Authorization: Bearer $cf_token" \
    -H "Content-Type: application/json" \
    --data "{\"content\":\"${new_target}\"}")

  local success
  success=$(echo "$result" | python3 -c "import sys, json; print(json.load(sys.stdin).get('success', False))")

  if [[ "$success" == "True" ]]; then
    log_success "Cloudflare DNS updated: $record_name → $new_target"
    return 0
  else
    log_warn "Cloudflare DNS update failed for $record_name"
    log_warn "Update DNS manually: $record_name → $new_target"
    return 1
  fi
}
