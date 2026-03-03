# AWS Infrastructure Setup Commands

This document captures all commands run to set up the Industry Night AWS infrastructure, with explanations.

---

## Phase 0: AWS Account Prep

### 0.1 - 0.2: Manual Steps (Console)
- Enable MFA on root account
- Create `industrynight-admin` IAM user with AdministratorAccess
- Create `industrynight-cli` IAM user with restricted policy

### 0.3: Configure AWS CLI

```bash
# Check AWS CLI version
aws --version

# Configure the restricted CLI profile
aws configure --profile industrynight
# Enter: Access Key ID, Secret Key, us-east-1, json

# Configure the admin profile (for cluster creation)
aws configure --profile industrynight-admin
# Enter: Access Key ID, Secret Key, us-east-1, json

# Verify CLI connection
aws sts get-caller-identity --profile industrynight
aws sts get-caller-identity --profile industrynight-admin
```

**Explanation:** We created two AWS profiles:
- `industrynight` - Restricted permissions for day-to-day CLI work
- `industrynight-admin` - Full admin access for infrastructure creation

---

## Phase 3: EKS Cluster Creation

### Install Required Tools

```bash
# Install eksctl (EKS cluster management tool)
brew tap weaveworks/tap
brew install weaveworks/tap/eksctl

# Verify installations
eksctl version
kubectl version --client
```

**Explanation:** `eksctl` is the official CLI for creating/managing EKS clusters. `kubectl` is the Kubernetes CLI for interacting with the cluster.

### Create EKS Cluster

```bash
# Create cluster using config file
eksctl create cluster -f infrastructure/eks/cluster.yaml --profile industrynight-admin
```

**Explanation:** This single command creates:
- VPC with public/private subnets across 2 availability zones
- Internet Gateway and NAT Gateway
- EKS control plane (managed Kubernetes API)
- IAM roles for cluster, nodes, and service accounts
- Managed node group with EC2 instances
- OIDC provider for IAM Roles for Service Accounts (IRSA)

The cluster.yaml config specifies:
- Kubernetes version 1.31
- Node group: 2x t3.micro instances
- Addons: vpc-cni, coredns, kube-proxy
- CloudWatch logging enabled
- Service account `industrynight-api` with S3, Secrets Manager, SES access

### Node Group Recovery

After initial t3.medium failure (new account restriction), we recreated with t3.micro:

```bash
# Delete failed node group
aws eks delete-nodegroup \
  --cluster-name industrynight-prod \
  --nodegroup-name standard-workers \
  --profile industrynight-admin

# Create new node group with t3.micro (free tier eligible)
aws eks create-nodegroup \
  --cluster-name industrynight-prod \
  --nodegroup-name standard-workers \
  --node-role arn:aws:iam::047593684855:role/eksctl-industrynight-prod-nodegrou-NodeInstanceRole-9Zs7TPBDajzg \
  --subnets subnet-059ac99644d22cdcf subnet-044557d8eb2ebb03a \
  --instance-types t3.micro \
  --scaling-config minSize=1,maxSize=4,desiredSize=2 \
  --capacity-type ON_DEMAND \
  --profile industrynight-admin
```

**Explanation:** New AWS accounts have restrictions on instance types. t3.micro works because it's free-tier eligible.

### Configure kubectl

```bash
# Update kubeconfig to connect to the new cluster
aws eks update-kubeconfig \
  --name industrynight-prod \
  --profile industrynight-admin \
  --region us-east-1
```

**Explanation:** This command updates `~/.kube/config` with the EKS cluster connection details, allowing `kubectl` to communicate with the cluster.

### Verify Cluster

```bash
# List nodes
kubectl get nodes

# List namespaces
kubectl get namespaces

# List resources in our namespace
kubectl get all -n industrynight

# List service accounts
kubectl get serviceaccount -n industrynight
```

**Explanation:** These commands verify the cluster is working and our namespace/service account were created.

---

## Phase 2: RDS PostgreSQL Database

### Get VPC Information

```bash
# Get VPC ID from EKS cluster
VPC_ID=$(aws eks describe-cluster \
  --name industrynight-prod \
  --profile industrynight-admin \
  --query 'cluster.resourcesVpcConfig.vpcId' \
  --output text)

# Get private subnets (for RDS)
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=*Private*" \
  --profile industrynight-admin \
  --query 'Subnets[].[SubnetId,AvailabilityZone]' \
  --output table

# Get EKS security group
aws eks describe-cluster \
  --name industrynight-prod \
  --profile industrynight-admin \
  --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' \
  --output text
```

**Explanation:** RDS needs to be in the same VPC as EKS. We query the VPC and subnet info that eksctl created.

### Create DB Subnet Group

```bash
aws rds create-db-subnet-group \
  --db-subnet-group-name industrynight-db-subnet \
  --db-subnet-group-description "Subnet group for Industry Night RDS" \
  --subnet-ids subnet-07226c8d9feec5ce3 subnet-0e67a45e9969738f0 \
  --profile industrynight-admin
```

**Explanation:** RDS requires a subnet group spanning at least 2 availability zones. This uses the private subnets created by eksctl.

### Create Security Group for RDS

```bash
# Create security group
RDS_SG=$(aws ec2 create-security-group \
  --group-name industrynight-rds-sg \
  --description "Security group for Industry Night RDS" \
  --vpc-id vpc-0193bb08b55ebce00 \
  --profile industrynight-admin \
  --output text --query 'GroupId')

# Allow PostgreSQL access from EKS nodes
aws ec2 authorize-security-group-ingress \
  --group-id $RDS_SG \
  --protocol tcp \
  --port 5432 \
  --source-group sg-0cc49989fee1a978f \
  --profile industrynight-admin
```

**Explanation:** Security groups are VPC firewalls. We allow PostgreSQL (port 5432) traffic only from the EKS security group - no public access.

### Create RDS Instance

```bash
# Generate secure password
DB_PASSWORD=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 24)

# Create RDS PostgreSQL instance
aws rds create-db-instance \
  --db-instance-identifier industrynight-db \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --engine-version 16.4 \
  --master-username industrynight \
  --master-user-password "$DB_PASSWORD" \
  --allocated-storage 20 \
  --storage-type gp2 \
  --db-subnet-group-name industrynight-db-subnet \
  --vpc-security-group-ids sg-0c6212393fa1254aa \
  --db-name industrynight \
  --no-publicly-accessible \
  --backup-retention-period 0 \
  --no-multi-az \
  --no-storage-encrypted \
  --profile industrynight-admin
```

**Explanation:** Creates a PostgreSQL 16.4 database with free-tier settings:
- `db.t3.micro` - Free tier eligible instance
- `--no-publicly-accessible` - Only accessible within VPC
- `--backup-retention-period 0` - No backups (free tier restriction)
- `--no-storage-encrypted` - No encryption (free tier restriction)

### Store Credentials in Secrets Manager

```bash
# Create secret
aws secretsmanager create-secret \
  --name industrynight/database \
  --description "Industry Night PostgreSQL credentials" \
  --secret-string "{\"username\":\"industrynight\",\"password\":\"$DB_PASSWORD\",\"dbname\":\"industrynight\",\"host\":\"pending\",\"port\":\"5432\"}" \
  --profile industrynight-admin

# Update with actual endpoint after RDS is available
aws secretsmanager update-secret \
  --secret-id industrynight/database \
  --secret-string "{\"username\":\"industrynight\",\"password\":\"$DB_PASSWORD\",\"dbname\":\"industrynight\",\"host\":\"industrynight-db.ckps4qaauvx4.us-east-1.rds.amazonaws.com\",\"port\":\"5432\"}" \
  --profile industrynight-admin
```

**Explanation:** Secrets Manager securely stores database credentials. The API will retrieve these at runtime using its IAM role.

### Check RDS Status

```bash
# Wait for RDS to become available
aws rds describe-db-instances \
  --db-instance-identifier industrynight-db \
  --profile industrynight-admin \
  --query 'DBInstances[0].DBInstanceStatus'

# Get endpoint when ready
aws rds describe-db-instances \
  --db-instance-identifier industrynight-db \
  --profile industrynight-admin \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text
```

---

## Database Migrations

### Create Kubernetes Secret for DB Credentials

```bash
# Get credentials from Secrets Manager
DB_SECRET=$(aws secretsmanager get-secret-value \
  --secret-id industrynight/database \
  --profile industrynight-admin \
  --query 'SecretString' --output text)

DB_HOST=$(echo $DB_SECRET | python3 -c "import sys, json; print(json.load(sys.stdin)['host'])")
DB_USER=$(echo $DB_SECRET | python3 -c "import sys, json; print(json.load(sys.stdin)['username'])")
DB_PASS=$(echo $DB_SECRET | python3 -c "import sys, json; print(json.load(sys.stdin)['password'])")
DB_NAME=$(echo $DB_SECRET | python3 -c "import sys, json; print(json.load(sys.stdin)['dbname'])")

# Create Kubernetes secret
kubectl create secret generic db-credentials \
  --from-literal=host=$DB_HOST \
  --from-literal=username=$DB_USER \
  --from-literal=password=$DB_PASS \
  --from-literal=dbname=$DB_NAME \
  -n industrynight
```

**Explanation:** Creates a Kubernetes secret that pods can mount to get database credentials.

### Create ConfigMap with Migration Files

```bash
kubectl create configmap db-migrations \
  --from-file=001_baseline_schema.sql=packages/database/migrations/001_baseline_schema.sql \
  --from-file=specialties.sql=packages/database/seeds/specialties.sql \
  -n industrynight
```

**Explanation:** ConfigMaps store configuration data. We use it to inject SQL files into the migration pod.

### Run Migration Job

```bash
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migrate
  namespace: industrynight
spec:
  ttlSecondsAfterFinished: 300
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: migrate
        image: postgres:16-alpine
        command:
        - /bin/sh
        - -c
        - |
          psql -f /migrations/001_baseline_schema.sql
          psql -f /migrations/specialties.sql
          psql -c "\dt"
        env:
        - name: PGHOST
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: host
        - name: PGUSER
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: username
        - name: PGPASSWORD
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: password
        - name: PGDATABASE
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: dbname
        volumeMounts:
        - name: migrations
          mountPath: /migrations
      volumes:
      - name: migrations
        configMap:
          name: db-migrations
EOF
```

**Explanation:** A Kubernetes Job runs a pod to completion. This one:
- Uses postgres:16-alpine image (has psql client)
- Mounts credentials from secret as env vars
- Mounts SQL files from ConfigMap
- Runs all migrations then lists tables to verify

### Monitor and Cleanup

```bash
# Wait for job to complete
kubectl wait --for=condition=complete job/db-migrate -n industrynight --timeout=120s

# View logs
kubectl logs job/db-migrate -n industrynight

# Cleanup
kubectl delete job db-migrate -n industrynight
kubectl delete configmap db-migrations -n industrynight
```

---

## Useful Commands Reference

### EKS Node Scaling (Cost Management)

```bash
# Scale down to 0 nodes (save money when not using)
aws eks update-nodegroup-config \
  --cluster-name industrynight-prod \
  --nodegroup-name standard-workers \
  --scaling-config minSize=0,maxSize=4,desiredSize=0 \
  --profile industrynight-admin

# Scale back up
aws eks update-nodegroup-config \
  --cluster-name industrynight-prod \
  --nodegroup-name standard-workers \
  --scaling-config minSize=1,maxSize=4,desiredSize=2 \
  --profile industrynight-admin
```

### Check Resource Status

```bash
# EKS cluster status
aws eks describe-cluster --name industrynight-prod --profile industrynight-admin --query 'cluster.status'

# Node group status
aws eks describe-nodegroup --cluster-name industrynight-prod --nodegroup-name standard-workers --profile industrynight-admin --query 'nodegroup.status'

# RDS status
aws rds describe-db-instances --db-instance-identifier industrynight-db --profile industrynight-admin --query 'DBInstances[0].DBInstanceStatus'

# Kubernetes nodes
kubectl get nodes

# Kubernetes pods
kubectl get pods -A
```

### View IAM Roles Created

```bash
aws iam list-roles --profile industrynight-admin --query "Roles[?contains(RoleName, 'industrynight')].RoleName" --output table
```

---

## Infrastructure Summary

| Resource | Identifier | Notes |
|----------|------------|-------|
| EKS Cluster | industrynight-prod | Kubernetes 1.31 |
| Node Group | standard-workers | 2x t3.micro |
| VPC | vpc-0193bb08b55ebce00 | Created by eksctl |
| Private Subnets | subnet-07226c8d9feec5ce3, subnet-0e67a45e9969738f0 | us-east-1a, us-east-1f |
| EKS Security Group | sg-0cc49989fee1a978f | For cluster/nodes |
| RDS Security Group | sg-0c6212393fa1254aa | PostgreSQL from EKS only |
| RDS Instance | industrynight-db | PostgreSQL 16.4 |
| RDS Endpoint | industrynight-db.ckps4qaauvx4.us-east-1.rds.amazonaws.com | Port 5432 |
| Secrets Manager | industrynight/database | DB credentials |
| Namespace | industrynight | Application namespace |
| Service Account | industrynight-api | IRSA for S3, Secrets, SES |

---

## Teardown Commands (When Needed)

```bash
# Delete RDS (WARNING: destroys all data)
aws rds delete-db-instance \
  --db-instance-identifier industrynight-db \
  --skip-final-snapshot \
  --profile industrynight-admin

# Delete EKS cluster and all associated resources
eksctl delete cluster --name industrynight-prod --profile industrynight-admin

# Delete Secrets Manager secret
aws secretsmanager delete-secret \
  --secret-id industrynight/database \
  --force-delete-without-recovery \
  --profile industrynight-admin
```

**WARNING:** These commands permanently delete resources and data. Use with caution.

---

## Phase 4: Domain & DNS (Route 53)

### Create Hosted Zone

```bash
# Create hosted zone for industrynight.net
aws route53 create-hosted-zone \
  --name industrynight.net \
  --caller-reference "industrynight-$(date +%s)" \
  --profile industrynight-admin
```

**Explanation:** Creates a Route 53 hosted zone to manage DNS for the domain. Returns 4 nameservers that must be configured at the domain registrar.

**Output:** Hosted Zone ID `Z06747281HOR0DFK445GN`

**Nameservers (configure at registrar):**
- ns-1356.awsdns-41.org
- ns-1868.awsdns-41.co.uk
- ns-334.awsdns-41.com
- ns-731.awsdns-27.net

**Note:** Domain was registered at Cloudflare (Route 53 domain registration blocked for new accounts). Nameserver update pending Cloudflare support ticket resolution.

---

## Phase 5: Container Registry (ECR)

### Create ECR Repository

```bash
# Create ECR repository for API container images
aws ecr create-repository \
  --repository-name industrynight-api \
  --image-scanning-configuration scanOnPush=true \
  --encryption-configuration encryptionType=AES256 \
  --profile industrynight-admin \
  --region us-east-1
```

**Explanation:** Creates a private container registry for storing Docker images:
- `scanOnPush=true` - Automatically scans images for vulnerabilities when pushed
- `encryptionType=AES256` - Encrypts images at rest

**Output:** Repository URI: `047593684855.dkr.ecr.us-east-1.amazonaws.com/industrynight-api`

### Authenticate Docker with ECR

```bash
# Get ECR login token and authenticate Docker
aws ecr get-login-password --profile industrynight-admin --region us-east-1 | \
  docker login --username AWS --password-stdin 047593684855.dkr.ecr.us-east-1.amazonaws.com
```

**Explanation:** ECR requires authentication. This command gets a temporary token from AWS and passes it to Docker.

### Build and Push Image

```bash
# Build Docker image
cd packages/api
docker build -t industrynight-api .

# Tag for ECR
docker tag industrynight-api:latest 047593684855.dkr.ecr.us-east-1.amazonaws.com/industrynight-api:latest

# Push to ECR
docker push 047593684855.dkr.ecr.us-east-1.amazonaws.com/industrynight-api:latest
```

**Explanation:** Standard Docker workflow - build locally, tag with ECR URI, push to registry.

---

## Phase 6: S3 Storage

### Create S3 Bucket

```bash
# Create bucket for user assets (profile photos, post images)
aws s3 mb s3://industrynight-assets-prod --profile industrynight-admin --region us-east-1
```

**Explanation:** Creates an S3 bucket for storing user-uploaded content.

### Configure Public Access

```bash
# Allow public read access (for serving images)
aws s3api put-public-access-block \
  --bucket industrynight-assets-prod \
  --public-access-block-configuration "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false" \
  --profile industrynight-admin
```

**Explanation:** Removes default public access blocks so we can serve images publicly.

### Configure CORS

```bash
# Enable CORS for web/mobile uploads
aws s3api put-bucket-cors \
  --bucket industrynight-assets-prod \
  --cors-configuration '{
    "CORSRules": [{
      "AllowedHeaders": ["*"],
      "AllowedMethods": ["GET", "PUT", "POST"],
      "AllowedOrigins": ["*"],
      "ExposeHeaders": ["ETag"],
      "MaxAgeSeconds": 3600
    }]
  }' \
  --profile industrynight-admin
```

**Explanation:** CORS (Cross-Origin Resource Sharing) allows the mobile app and web frontend to upload directly to S3.

---

## Local Development: Database Access

### Create Database Proxy Pod

```bash
# Create a pod that tunnels to RDS (since RDS is in private subnet)
kubectl run db-proxy --image=alpine/socat -n industrynight --restart=Never -- \
  -d -d tcp-listen:5432,fork,reuseaddr \
  tcp-connect:industrynight-db.ckps4qaauvx4.us-east-1.rds.amazonaws.com:5432

# Wait for pod to be ready
kubectl wait --for=condition=ready pod/db-proxy -n industrynight --timeout=60s
```

**Explanation:** Since RDS is in a private subnet (no public access), we create a "jump pod" inside the EKS cluster that can reach the database. The `socat` tool forwards TCP connections.

### Port Forward to Local Machine

```bash
# Forward local port 5432 to the proxy pod
kubectl port-forward pod/db-proxy 5432:5432 -n industrynight
```

**Explanation:** Forwards your local port 5432 to the proxy pod, which then connects to RDS. Now you can use any PostgreSQL client (VS Code, pgAdmin, etc.) connected to `localhost:5432`.

**Connection Settings:**
- Host: `localhost`
- Port: `5432`
- Database: `industrynight`
- Username: `industrynight`
- Password: (from Secrets Manager or 1Password)
- SSL: Enable/Require

### Cleanup

```bash
# Delete proxy pod when done
kubectl delete pod db-proxy -n industrynight
```

---

## Updated Infrastructure Summary

| Resource | Identifier | Notes |
|----------|------------|-------|
| EKS Cluster | industrynight-prod | Kubernetes 1.31 |
| Node Group | standard-workers | 2x t3.micro |
| VPC | vpc-0193bb08b55ebce00 | Created by eksctl |
| Private Subnets | subnet-07226c8d9feec5ce3, subnet-0e67a45e9969738f0 | us-east-1a, us-east-1f |
| EKS Security Group | sg-0cc49989fee1a978f | For cluster/nodes |
| RDS Security Group | sg-0c6212393fa1254aa | PostgreSQL from EKS only |
| RDS Instance | industrynight-db | PostgreSQL 16.4 |
| RDS Endpoint | industrynight-db.ckps4qaauvx4.us-east-1.rds.amazonaws.com | Port 5432 |
| Secrets Manager | industrynight/database | DB credentials |
| Namespace | industrynight | Application namespace |
| Service Account | industrynight-api | IRSA for S3, Secrets, SES |
| **Route 53 Zone** | Z06747281HOR0DFK445GN | industrynight.net |
| **ECR Repository** | industrynight-api | 047593684855.dkr.ecr.us-east-1.amazonaws.com/industrynight-api |
| **S3 Bucket** | industrynight-assets-prod | User assets |
