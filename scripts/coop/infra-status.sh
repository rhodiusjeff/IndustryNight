#!/bin/bash
set -euo pipefail

# infra-status.sh — Check status of all Industry Night AWS resources
#
# Color coding:
#   GREEN  = Running / Available / Exists
#   YELLOW = Stopped / Degraded / Warning
#   RED    = Missing / Deleted / Error
#
# Usage:
#   ./scripts/coop/infra-status.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"

echo -e "${BOLD}=== Industry Night Infrastructure Status ===${NC}"
echo "  Region:  $AWS_REGION"
echo "  Profile: $AWS_PROFILE"
echo "  Time:    $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo ""

check_aws_credentials
echo ""

# Helper: print resource status with color
print_status() {
  local resource=$1
  local identifier=$2
  local status=$3
  local detail=${4:-""}

  local color
  case $status in
    ACTIVE|available|exists|ISSUED|INSYNC|Ready|Running)
      color=$GREEN ;;
    stopped|stopping|creating|modifying|backing-up|CREATING|UPDATING)
      color=$YELLOW ;;
    *)
      color=$RED ;;
  esac

  printf "  %-25s %-35s ${color}%-15s${NC} %s\n" "$resource" "$identifier" "$status" "$detail"
}

# ---- EKS Cluster ----
echo -e "${BOLD}Compute (EKS)${NC}"
EKS_STATUS=$(aws_cmd eks describe-cluster --name "$EKS_CLUSTER" \
  --query 'cluster.status' --output text 2>/dev/null || echo "NOT_FOUND")
EKS_VERSION=""
if [[ "$EKS_STATUS" != "NOT_FOUND" ]]; then
  EKS_VERSION="(k8s $(aws_cmd eks describe-cluster --name "$EKS_CLUSTER" \
    --query 'cluster.version' --output text 2>/dev/null))"
fi
print_status "EKS Cluster" "$EKS_CLUSTER" "$EKS_STATUS" "$EKS_VERSION"

if [[ "$EKS_STATUS" == "ACTIVE" ]]; then
  # Node group
  NG_STATUS=$(aws_cmd eks describe-nodegroup --cluster-name "$EKS_CLUSTER" \
    --nodegroup-name "$EKS_NODEGROUP" \
    --query 'nodegroup.status' --output text 2>/dev/null || echo "NOT_FOUND")
  NG_DETAIL=""
  if [[ "$NG_STATUS" == "ACTIVE" ]]; then
    DESIRED=$(aws_cmd eks describe-nodegroup --cluster-name "$EKS_CLUSTER" \
      --nodegroup-name "$EKS_NODEGROUP" \
      --query 'nodegroup.scalingConfig.desiredSize' --output text 2>/dev/null)
    NG_DETAIL="($DESIRED nodes desired)"
  fi
  print_status "  Node Group" "$EKS_NODEGROUP" "$NG_STATUS" "$NG_DETAIL"

  # API pods
  POD_RUNNING=$(kube_cmd get pods -n "$K8S_NAMESPACE" -l app="$K8S_DEPLOYMENT" \
    --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d '[:space:]')
  POD_TOTAL=$(kube_cmd get pods -n "$K8S_NAMESPACE" -l app="$K8S_DEPLOYMENT" \
    --no-headers 2>/dev/null | wc -l | tr -d '[:space:]')

  if [[ "$POD_TOTAL" -gt 0 ]]; then
    if [[ "$POD_RUNNING" == "$POD_TOTAL" ]]; then
      print_status "  API Pods" "$K8S_DEPLOYMENT" "Running" "($POD_RUNNING/$POD_TOTAL)"
    else
      print_status "  API Pods" "$K8S_DEPLOYMENT" "degraded" "($POD_RUNNING/$POD_TOTAL running)"
    fi
  else
    print_status "  API Pods" "$K8S_DEPLOYMENT" "none" "(0 pods)"
  fi

  # Maintenance mode
  MAINT=$(kube_cmd get ingress/"$K8S_DEPLOYMENT" -n "$K8S_NAMESPACE" \
    -o jsonpath='{.metadata.annotations.alb\.ingress\.kubernetes\.io/actions\.fixed-response}' 2>/dev/null || true)
  if [[ -n "$MAINT" ]]; then
    print_status "  Maintenance" "" "ON" "(ALB returning 503)"
  else
    print_status "  Maintenance" "" "OFF" ""
  fi
fi
echo ""

# ---- RDS ----
echo -e "${BOLD}Database (RDS)${NC}"
RDS_STATUS=$(aws_cmd rds describe-db-instances --db-instance-identifier "$RDS_INSTANCE" \
  --query 'DBInstances[0].DBInstanceStatus' --output text 2>/dev/null || echo "NOT_FOUND")
RDS_DETAIL=""
if [[ "$RDS_STATUS" == "available" ]]; then
  RDS_ENGINE_V=$(aws_cmd rds describe-db-instances --db-instance-identifier "$RDS_INSTANCE" \
    --query 'DBInstances[0].EngineVersion' --output text 2>/dev/null)
  RDS_CLASS=$(aws_cmd rds describe-db-instances --db-instance-identifier "$RDS_INSTANCE" \
    --query 'DBInstances[0].DBInstanceClass' --output text 2>/dev/null)
  RDS_DETAIL="(PG $RDS_ENGINE_V, $RDS_CLASS)"
fi
print_status "RDS Instance" "$RDS_INSTANCE" "$RDS_STATUS" "$RDS_DETAIL"
echo ""

# ---- ECR ----
echo -e "${BOLD}Container Registry (ECR)${NC}"
ECR_EXISTS=$(aws_cmd ecr describe-repositories --repository-names "$ECR_REPO" \
  --query 'repositories[0].repositoryUri' --output text 2>/dev/null || echo "NOT_FOUND")
if [[ "$ECR_EXISTS" != "NOT_FOUND" ]]; then
  IMAGE_COUNT=$(aws_cmd ecr list-images --repository-name "$ECR_REPO" \
    --query 'imageIds | length(@)' --output text 2>/dev/null || echo "0")
  print_status "ECR Repository" "$ECR_REPO" "exists" "($IMAGE_COUNT images)"
else
  print_status "ECR Repository" "$ECR_REPO" "NOT_FOUND" ""
fi
echo ""

# ---- S3 ----
echo -e "${BOLD}Storage (S3)${NC}"
for bucket in $S3_ASSETS_BUCKET $S3_WEB_BUCKET; do
  if aws_cmd s3api head-bucket --bucket "$bucket" 2>/dev/null; then
    OBJECTS=$(aws_cmd s3api list-objects-v2 --bucket "$bucket" \
      --query 'KeyCount' --output text 2>/dev/null || echo "0")
    print_status "S3 Bucket" "$bucket" "exists" "($OBJECTS objects)"
  else
    print_status "S3 Bucket" "$bucket" "NOT_FOUND" ""
  fi
done
echo ""

# ---- Secrets Manager ----
echo -e "${BOLD}Secrets${NC}"
SM_STATUS=$(aws_cmd secretsmanager describe-secret --secret-id "$SECRETS_ID" \
  --query 'Name' --output text 2>/dev/null || echo "NOT_FOUND")
if [[ "$SM_STATUS" != "NOT_FOUND" ]]; then
  print_status "Secrets Manager" "$SECRETS_ID" "exists" ""
else
  print_status "Secrets Manager" "$SECRETS_ID" "NOT_FOUND" ""
fi
echo ""

# ---- Route 53 ----
echo -e "${BOLD}DNS (Route 53)${NC}"
R53_STATUS=$(aws_cmd route53 get-hosted-zone --id "$HOSTED_ZONE_ID" \
  --query 'HostedZone.Name' --output text 2>/dev/null || echo "NOT_FOUND")
if [[ "$R53_STATUS" != "NOT_FOUND" ]]; then
  RECORD_COUNT=$(aws_cmd route53 get-hosted-zone --id "$HOSTED_ZONE_ID" \
    --query 'HostedZone.ResourceRecordSetCount' --output text 2>/dev/null || echo "?")
  print_status "Hosted Zone" "$DOMAIN" "exists" "($RECORD_COUNT records)"
else
  print_status "Hosted Zone" "$DOMAIN" "NOT_FOUND" ""
fi
echo ""

# ---- ACM ----
echo -e "${BOLD}SSL/TLS (ACM)${NC}"
ACM_STATUS=$(aws_cmd acm describe-certificate --certificate-arn "$ACM_CERT_ARN" \
  --query 'Certificate.Status' --output text 2>/dev/null || echo "NOT_FOUND")
if [[ "$ACM_STATUS" != "NOT_FOUND" ]]; then
  ACM_DOMAIN=$(aws_cmd acm describe-certificate --certificate-arn "$ACM_CERT_ARN" \
    --query 'Certificate.DomainName' --output text 2>/dev/null)
  print_status "ACM Certificate" "$ACM_DOMAIN" "$ACM_STATUS" ""
else
  print_status "ACM Certificate" "" "NOT_FOUND" ""
fi
echo ""

# ---- Cost Summary ----
echo -e "${BOLD}Estimated Cost${NC}"
if [[ "$EKS_STATUS" == "ACTIVE" && "$RDS_STATUS" == "available" ]]; then
  echo -e "  ${RED}RUNNING${NC} — EKS + RDS are active. Estimated ~\$160/month."
  echo "  To save costs: ./scripts/coop/coop.sh teardown"
elif [[ "$EKS_STATUS" == "NOT_FOUND" && "$RDS_STATUS" == "NOT_FOUND" ]]; then
  echo -e "  ${GREEN}HIBERNATED${NC} — Only cheap/free resources active (~\$2-5/month)."
  echo "  To bring back: ./scripts/coop/coop.sh rebuild"
elif [[ "$RDS_STATUS" == "stopped" && "$EKS_STATUS" == "ACTIVE" ]]; then
  echo -e "  ${YELLOW}PARTIAL${NC} — EKS running, RDS stopped (~\$130/month)."
else
  echo -e "  ${YELLOW}MIXED${NC} — EKS: $EKS_STATUS, RDS: $RDS_STATUS"
fi
echo ""
