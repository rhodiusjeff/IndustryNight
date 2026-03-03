#!/bin/bash
set -euo pipefail

# setup-dev-persistent.sh — Create persistent resources for the dev environment
#
# ONE-TIME SCRIPT — Run once to create resources that survive teardown/rebuild.
# These are the dev equivalents of what already exists for production.
#
# Creates:
#   1. S3 bucket: industrynight-assets-dev (public images, Object Ownership: BucketOwnerPreferred)
#   2. S3 bucket: industrynight-web-admin-dev (private, for CloudFront OAC)
#   3. Secrets Manager: industrynight/database-dev (generates random DB password)
#   4. CloudFront distribution for dev-admin.industrynight.net → S3 origin with OAC
#   5. Cloudflare DNS: dev-api CNAME (placeholder), dev-admin CNAME (→ CloudFront)
#
# After running:
#   - Update scripts/coop/environments/dev.env with the CloudFront distribution ID
#   - The ACM wildcard cert (*.industrynight.net) covers dev subdomains automatically
#
# Usage:
#   ./scripts/coop/setup-dev-persistent.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Force dev environment
load_environment "dev"

TOTAL_STEPS=6
CURRENT_STEP=0

echo -e "${BOLD}=== Dev Environment: Persistent Resources Setup ===${NC}"
echo ""
echo "  This will create the following resources:"
echo "    - S3: $S3_ASSETS_BUCKET (public images)"
echo "    - S3: $S3_WEB_BUCKET (admin web app)"
echo "    - Secrets Manager: $SECRETS_ID"
echo "    - CloudFront distribution for $ADMIN_HOST"
echo "    - Cloudflare DNS records for dev-api and dev-admin"
echo ""

confirm_destructive "This will create new AWS resources (small ongoing costs ~\$1-2/mo)."

# Step 1: Verify prerequisites
log_step $((++CURRENT_STEP)) $TOTAL_STEPS "Verifying prerequisites..."
check_aws_credentials

# Verify ACM cert exists (shared wildcard)
ACM_STATUS=$(aws_cmd acm describe-certificate --certificate-arn "$ACM_CERT_ARN" \
  --query 'Certificate.Status' --output text 2>/dev/null || echo "NOT_FOUND")
if [[ "$ACM_STATUS" != "ISSUED" ]]; then
  log_error "ACM certificate not found or not issued: $ACM_CERT_ARN"
  log_error "The wildcard cert *.industrynight.net must exist before creating CloudFront."
  exit 1
fi
log_success "ACM wildcard certificate: ISSUED"

# Step 2: Create S3 buckets
log_step $((++CURRENT_STEP)) $TOTAL_STEPS "Creating S3 buckets..."

# Assets bucket (public images)
if aws_cmd s3api head-bucket --bucket "$S3_ASSETS_BUCKET" 2>/dev/null; then
  log_warn "  S3 bucket already exists: $S3_ASSETS_BUCKET"
else
  log_info "  Creating: $S3_ASSETS_BUCKET"
  aws_cmd s3api create-bucket --bucket "$S3_ASSETS_BUCKET" --region "$AWS_REGION"

  # Set Object Ownership to BucketOwnerPreferred (required for ACL: public-read)
  aws_cmd s3api put-bucket-ownership-controls --bucket "$S3_ASSETS_BUCKET" \
    --ownership-controls '{"Rules":[{"ObjectOwnership":"BucketOwnerPreferred"}]}'

  # Unblock public ACLs (needed for public-read on uploaded images)
  aws_cmd s3api put-public-access-block --bucket "$S3_ASSETS_BUCKET" \
    --public-access-block-configuration \
    "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=true,RestrictPublicBuckets=true"

  log_success "  Created: $S3_ASSETS_BUCKET (public ACLs enabled)"
fi

# Admin web bucket (private, OAC-restricted)
if aws_cmd s3api head-bucket --bucket "$S3_WEB_BUCKET" 2>/dev/null; then
  log_warn "  S3 bucket already exists: $S3_WEB_BUCKET"
else
  log_info "  Creating: $S3_WEB_BUCKET"
  aws_cmd s3api create-bucket --bucket "$S3_WEB_BUCKET" --region "$AWS_REGION"
  log_success "  Created: $S3_WEB_BUCKET (private)"
fi

# Step 3: Create Secrets Manager secret
log_step $((++CURRENT_STEP)) $TOTAL_STEPS "Creating Secrets Manager secret..."

if aws_cmd secretsmanager describe-secret --secret-id "$SECRETS_ID" 2>/dev/null; then
  log_warn "  Secret already exists: $SECRETS_ID"
else
  # Generate a random password
  DEV_DB_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=' | head -c 32)

  aws_cmd secretsmanager create-secret \
    --name "$SECRETS_ID" \
    --description "Industry Night dev database credentials" \
    --secret-string "{\"username\":\"$RDS_MASTER_USER\",\"password\":\"$DEV_DB_PASSWORD\",\"host\":\"\",\"port\":5432,\"database\":\"$RDS_DB_NAME\"}"

  log_success "  Created: $SECRETS_ID (password generated)"
  log_info "  DB password: $DEV_DB_PASSWORD (also stored in Secrets Manager)"
fi

# Step 4: Create CloudFront OAC + distribution
log_step $((++CURRENT_STEP)) $TOTAL_STEPS "Creating CloudFront distribution..."

# Check if distribution already exists for this domain
EXISTING_CF=$(aws_cmd cloudfront list-distributions \
  --query "DistributionList.Items[?Aliases.Items[0]=='${ADMIN_HOST}'].Id" \
  --output text 2>/dev/null || echo "")

if [[ -n "$EXISTING_CF" && "$EXISTING_CF" != "None" ]]; then
  log_warn "  CloudFront distribution already exists for $ADMIN_HOST: $EXISTING_CF"
  CF_DIST_ID="$EXISTING_CF"
else
  # Create OAC for S3 access
  OAC_ID=$(aws_cmd cloudfront create-origin-access-control \
    --origin-access-control-config "{
      \"Name\": \"${S3_WEB_BUCKET}-oac\",
      \"OriginAccessControlOriginType\": \"s3\",
      \"SigningBehavior\": \"always\",
      \"SigningProtocol\": \"sigv4\"
    }" \
    --query 'OriginAccessControl.Id' --output text 2>/dev/null || echo "")

  if [[ -z "$OAC_ID" ]]; then
    # OAC might already exist
    OAC_ID=$(aws_cmd cloudfront list-origin-access-controls \
      --query "OriginAccessControlList.Items[?Name=='${S3_WEB_BUCKET}-oac'].Id" \
      --output text 2>/dev/null || echo "")
  fi
  log_info "  OAC ID: $OAC_ID"

  # Create CloudFront distribution
  CF_CONFIG=$(cat <<CFEOF
{
  "CallerReference": "dev-admin-$(date +%s)",
  "Comment": "Industry Night Dev Admin App",
  "Enabled": true,
  "DefaultRootObject": "index.html",
  "Aliases": {
    "Quantity": 1,
    "Items": ["${ADMIN_HOST}"]
  },
  "ViewerCertificate": {
    "ACMCertificateArn": "${ACM_CERT_ARN}",
    "SSLSupportMethod": "sni-only",
    "MinimumProtocolVersion": "TLSv1.2_2021"
  },
  "Origins": {
    "Quantity": 1,
    "Items": [{
      "Id": "S3-${S3_WEB_BUCKET}",
      "DomainName": "${S3_WEB_BUCKET}.s3.${AWS_REGION}.amazonaws.com",
      "OriginAccessControlId": "${OAC_ID}",
      "S3OriginConfig": {
        "OriginAccessIdentity": ""
      }
    }]
  },
  "DefaultCacheBehavior": {
    "TargetOriginId": "S3-${S3_WEB_BUCKET}",
    "ViewerProtocolPolicy": "redirect-to-https",
    "AllowedMethods": {
      "Quantity": 2,
      "Items": ["GET", "HEAD"]
    },
    "CachePolicyId": "658327ea-f89d-4fab-a63d-7e88639e58f6",
    "Compress": true
  },
  "CustomErrorResponses": {
    "Quantity": 1,
    "Items": [{
      "ErrorCode": 403,
      "ResponsePagePath": "/index.html",
      "ResponseCode": "200",
      "ErrorCachingMinTTL": 10
    }]
  }
}
CFEOF
)

  CF_RESULT=$(aws_cmd cloudfront create-distribution \
    --distribution-config "$CF_CONFIG" \
    --output json 2>/dev/null)

  CF_DIST_ID=$(echo "$CF_RESULT" | python3 -c "import sys, json; print(json.load(sys.stdin)['Distribution']['Id'])")
  CF_DOMAIN=$(echo "$CF_RESULT" | python3 -c "import sys, json; print(json.load(sys.stdin)['Distribution']['DomainName'])")

  log_success "  CloudFront distribution created: $CF_DIST_ID"
  log_info "  CloudFront domain: $CF_DOMAIN"

  # Add S3 bucket policy for CloudFront OAC access
  BUCKET_POLICY=$(cat <<BPEOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "AllowCloudFrontServicePrincipal",
    "Effect": "Allow",
    "Principal": {
      "Service": "cloudfront.amazonaws.com"
    },
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::${S3_WEB_BUCKET}/*",
    "Condition": {
      "StringEquals": {
        "AWS:SourceArn": "arn:aws:cloudfront::${AWS_ACCOUNT}:distribution/${CF_DIST_ID}"
      }
    }
  }]
}
BPEOF
)

  aws_cmd s3api put-bucket-policy --bucket "$S3_WEB_BUCKET" --policy "$BUCKET_POLICY"
  log_success "  S3 bucket policy applied for CloudFront OAC"
fi

# Step 5: Create Cloudflare DNS records
log_step $((++CURRENT_STEP)) $TOTAL_STEPS "Creating Cloudflare DNS records..."

# Get Cloudflare API token
CF_SECRET=$(aws_cmd secretsmanager get-secret-value \
  --secret-id "$CF_SECRETS_ID" \
  --query 'SecretString' --output text 2>/dev/null || echo "")

if [[ -z "$CF_SECRET" ]]; then
  log_warn "  Cloudflare credentials not found. Create DNS records manually:"
  log_warn "    dev-api CNAME → (placeholder, updated on rebuild)"
  log_warn "    dev-admin CNAME → CloudFront domain"
else
  CF_TOKEN=$(echo "$CF_SECRET" | python3 -c "import sys, json; print(json.load(sys.stdin)['api_token'])")

  # Get CloudFront domain for admin CNAME
  if [[ -n "${CF_DOMAIN:-}" ]]; then
    ADMIN_TARGET="$CF_DOMAIN"
  else
    ADMIN_TARGET=$(aws_cmd cloudfront get-distribution --id "$CF_DIST_ID" \
      --query 'Distribution.DomainName' --output text 2>/dev/null || echo "")
  fi

  # dev-api CNAME (placeholder — will be updated on rebuild to point to ALB)
  log_info "  Creating dev-api CNAME (placeholder)..."
  API_EXISTS=$(curl -s "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records?name=${CF_API_RECORD_NAME}&type=CNAME" \
    -H "Authorization: Bearer $CF_TOKEN" | \
    python3 -c "import sys, json; r=json.load(sys.stdin); print(len(r.get('result', [])))")

  if [[ "$API_EXISTS" == "0" ]]; then
    curl -s -X POST \
      "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records" \
      -H "Authorization: Bearer $CF_TOKEN" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"CNAME\",\"name\":\"${CF_API_RECORD_NAME}\",\"content\":\"placeholder.example.com\",\"proxied\":false}" \
      > /dev/null
    log_success "  Created: $CF_API_RECORD_NAME CNAME (placeholder)"
  else
    log_warn "  DNS record already exists: $CF_API_RECORD_NAME"
  fi

  # dev-admin CNAME → CloudFront
  if [[ -n "$ADMIN_TARGET" ]]; then
    log_info "  Creating dev-admin CNAME → $ADMIN_TARGET..."
    ADMIN_EXISTS=$(curl -s "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records?name=${CF_ADMIN_RECORD_NAME}&type=CNAME" \
      -H "Authorization: Bearer $CF_TOKEN" | \
      python3 -c "import sys, json; r=json.load(sys.stdin); print(len(r.get('result', [])))")

    if [[ "$ADMIN_EXISTS" == "0" ]]; then
      curl -s -X POST \
        "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records" \
        -H "Authorization: Bearer $CF_TOKEN" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"CNAME\",\"name\":\"${CF_ADMIN_RECORD_NAME}\",\"content\":\"${ADMIN_TARGET}\",\"proxied\":false}" \
        > /dev/null
      log_success "  Created: $CF_ADMIN_RECORD_NAME CNAME → $ADMIN_TARGET"
    else
      log_warn "  DNS record already exists: $CF_ADMIN_RECORD_NAME"
    fi
  fi
fi

# Step 6: Summary
log_step $((++CURRENT_STEP)) $TOTAL_STEPS "Summary..."

echo ""
echo -e "${BOLD}=== Dev Persistent Resources Created ===${NC}"
echo ""
echo "  S3 (assets):     $S3_ASSETS_BUCKET"
echo "  S3 (admin web):  $S3_WEB_BUCKET"
echo "  Secrets Manager: $SECRETS_ID"
echo "  CloudFront:      ${CF_DIST_ID:-check manually}"
echo "  DNS (api):       $CF_API_RECORD_NAME (placeholder)"
echo "  DNS (admin):     $CF_ADMIN_RECORD_NAME"
echo ""

if [[ -n "${CF_DIST_ID:-}" ]]; then
  echo -e "  ${YELLOW}ACTION REQUIRED:${NC} Update dev.env with the CloudFront distribution ID:"
  echo ""
  echo "    CF_DISTRIBUTION_ID=\"$CF_DIST_ID\""
  echo ""
  echo "  in: scripts/coop/environments/dev.env"
  echo ""
fi

echo "  Next: Build the dev environment:"
echo "    ./scripts/coop/coop.sh --env dev rebuild"
echo ""
