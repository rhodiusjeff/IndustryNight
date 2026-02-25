# Industry Night - AWS Architecture Plan

**Version:** 1.0
**Date:** February 4, 2026
**Status:** Approved

---

## 1. AWS Experience Assessment

**Your Profile:**
- **Overall Level:** Intermediate (but dated)
- **AWS Experience:** 6 years old - console and services have evolved
- **K8s Experience:** 2.5 years old - core concepts solid, tooling updated
- **Services Used:** EC2, S3, RDS, IAM
- **Learning Style:** Explain concepts before executing

**Gaps to Address:**
- EKS-specific setup (eksctl, managed node groups, IRSA)
- Updated AWS console navigation
- ECR (container registry)
- Secrets Manager
- CloudWatch for K8s
- kubectl CLI refresher
- VPC networking for EKS

---

## 2. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              INTERNET                                    │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │
                    ┌─────────────▼─────────────┐
                    │   Route 53 (DNS)          │
                    │   industrynight.net       │
                    └─────────────┬─────────────┘
                                  │
                    ┌─────────────▼─────────────┐
                    │   Application Load        │
                    │   Balancer (ALB)          │
                    │   + ACM SSL Certificate   │
                    └─────────────┬─────────────┘
                                  │
┌─────────────────────────────────▼───────────────────────────────────────┐
│                            VPC (10.0.0.0/16)                            │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                     PUBLIC SUBNETS (2 AZs)                         │ │
│  │  ┌─────────────────┐              ┌─────────────────┐              │ │
│  │  │ NAT Gateway     │              │ NAT Gateway     │              │ │
│  │  │ (AZ-a)          │              │ (AZ-b)          │              │ │
│  │  └─────────────────┘              └─────────────────┘              │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                    PRIVATE SUBNETS (2 AZs)                         │ │
│  │  ┌─────────────────────────────────────────────────────────────┐   │ │
│  │  │                    EKS CLUSTER                              │   │ │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │   │ │
│  │  │  │ Node Group  │  │ Node Group  │  │ Node Group  │          │   │ │
│  │  │  │ (t3.medium) │  │ (t3.medium) │  │ (t3.medium) │          │   │ │
│  │  │  │             │  │             │  │             │          │   │ │
│  │  │  │ ┌─────────┐ │  │ ┌─────────┐ │  │ ┌─────────┐ │          │   │ │
│  │  │  │ │ IN API  │ │  │ │ IN API  │ │  │ │ IN API  │ │          │   │ │
│  │  │  │ │ Pod     │ │  │ │ Pod     │ │  │ │ Pod     │ │          │   │ │
│  │  │  │ └─────────┘ │  │ └─────────┘ │  │ └─────────┘ │          │   │ │
│  │  │  └─────────────┘  └─────────────┘  └─────────────┘          │   │ │
│  │  └─────────────────────────────────────────────────────────────┘   │ │
│  │                              │                                      │ │
│  │                              ▼                                      │ │
│  │  ┌─────────────────────────────────────────────────────────────┐   │ │
│  │  │               RDS PostgreSQL (Multi-AZ)                     │   │ │
│  │  │               db.t3.micro (MVP) → db.t3.small (scale)       │   │ │
│  │  └─────────────────────────────────────────────────────────────┘   │ │
│  └────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                         SUPPORTING SERVICES                             │
├─────────────────────────────────────────────────────────────────────────┤
│  S3                    │  ECR                   │  Secrets Manager      │
│  • Profile photos      │  • API container       │  • DB credentials     │
│  • Post images         │    images              │  • JWT secrets        │
│  • Sponsor logos       │                        │  • Posh webhook key   │
│                        │                        │  • Twilio API keys    │
├─────────────────────────────────────────────────────────────────────────┤
│  CloudWatch            │  Twilio                │  SES                  │
│  • API logs            │  • SMS verification    │  • Welcome emails     │
│  • EKS metrics         │    codes               │  • Notifications      │
│  • Alerts              │                        │                       │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 3. AWS Services - Decisions & Rationale

### Compute: EKS (Kubernetes)

**Decision:** EKS with managed node groups

**Why:**
- You want to learn/refresh K8s skills
- Provides scaling path for future
- Industry-standard for containerized apps

**MVP Configuration:**
- 2-3 t3.medium nodes (2 vCPU, 4GB RAM each)
- Single node group to start
- Can scale to 0 nodes during development to save costs

**Alternative Considered:** ECS Fargate
- Simpler, no K8s knowledge needed
- But doesn't meet your learning goal

---

### Database: RDS PostgreSQL

**Decision:** RDS PostgreSQL (not DynamoDB, not Aurora)

**Why:**
- Relational data model (users, events, connections)
- You have RDS experience
- PostgreSQL is powerful and well-documented
- Cheaper than Aurora for MVP scale

**MVP Configuration:**
- db.t3.micro (free tier eligible for 12 months)
- Single-AZ for MVP (Multi-AZ for production)
- 20GB storage (auto-scaling enabled)

**Alternative Considered:** DynamoDB
- Better for massive scale
- But more complex data modeling for relational data
- Overkill for MVP

---

### Storage: S3 + CloudFront

**Decision:** S3 for assets, CloudFront for delivery

**Why:**
- Profile photos, post images, sponsor logos
- CloudFront provides fast global delivery
- You have S3 experience

**MVP Configuration:**
- Single bucket with folder structure
- Public read for assets (signed URLs for private if needed)
- CloudFront distribution for production

---

### SMS: Twilio (not SNS)

**Decision:** Twilio for SMS verification

**Why:**
- Better deliverability than SNS
- More features (verified sender ID, delivery reports)
- Straightforward API
- Industry standard for auth SMS

**Cost:** ~$0.0075 per SMS (US)

**Alternative Considered:** AWS SNS
- Cheaper (~$0.00645 per SMS)
- But less reliable deliverability
- Fewer features

---

### Email: AWS SES

**Decision:** SES for transactional emails

**Why:**
- Welcome emails, password resets
- Very cheap ($0.10 per 1000 emails)
- You're already in AWS

---

### Secrets: AWS Secrets Manager

**Decision:** Secrets Manager (not Parameter Store)

**Why:**
- Automatic rotation capability
- Better for sensitive credentials
- Native K8s integration via External Secrets Operator

**Will Store:**
- Database credentials
- JWT signing secrets
- Posh webhook validation key
- Twilio API credentials

---

## 4. Security Model

### IAM Strategy

**Principle:** Least privilege, separate roles per function

```
┌─────────────────────────────────────────────────────────────────┐
│                        IAM STRUCTURE                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  AWS Account (your account)                                     │
│  │                                                              │
│  ├── IAM User: industrynight-admin (YOU)                        │
│  │   └── Permissions: AdministratorAccess (for setup only)      │
│  │                                                              │
│  ├── IAM User: industrynight-cli (for Claude CLI work)          │
│  │   └── Permissions: Custom policy (see below)                 │
│  │                                                              │
│  ├── IAM Role: industrynight-eks-cluster                        │
│  │   └── Permissions: AmazonEKSClusterPolicy                    │
│  │                                                              │
│  ├── IAM Role: industrynight-eks-nodes                          │
│  │   └── Permissions: AmazonEKSWorkerNodePolicy                 │
│  │                    AmazonEC2ContainerRegistryReadOnly        │
│  │                    AmazonEKS_CNI_Policy                      │
│  │                                                              │
│  └── IAM Role: industrynight-api-pod                            │
│      └── Permissions: (via IRSA - IAM Roles for Service Accts)  │
│                       SecretsManagerReadWrite (scoped)          │
│                       S3 read/write (scoped to bucket)          │
│                       SES send email                            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### CLI Security Policy (industrynight-cli user)

**Purpose:** This is the IAM user we'll use for AWS CLI commands during development. Scoped to prevent accidents.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadOnlyByDefault",
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "eks:Describe*",
        "eks:List*",
        "rds:Describe*",
        "s3:GetObject",
        "s3:ListBucket",
        "iam:Get*",
        "iam:List*",
        "logs:Describe*",
        "logs:Get*",
        "cloudwatch:Describe*",
        "cloudwatch:Get*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "EKSManagement",
      "Effect": "Allow",
      "Action": [
        "eks:UpdateClusterConfig",
        "eks:UpdateNodegroupConfig"
      ],
      "Resource": "arn:aws:eks:*:*:cluster/industrynight-*"
    },
    {
      "Sid": "ECRPushPull",
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "*"
    },
    {
      "Sid": "S3IndustryNightOnly",
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::industrynight-*/*"
    },
    {
      "Sid": "DenyDestructiveActions",
      "Effect": "Deny",
      "Action": [
        "ec2:TerminateInstances",
        "rds:DeleteDBInstance",
        "rds:DeleteDBCluster",
        "eks:DeleteCluster",
        "eks:DeleteNodegroup",
        "s3:DeleteBucket",
        "iam:Delete*",
        "iam:Remove*"
      ],
      "Resource": "*"
    }
  ]
}
```

**Key Points:**
- Read-only by default for most services
- Write access scoped to `industrynight-*` resources
- **Explicit DENY on destructive actions** (delete cluster, terminate instances, etc.)
- If we need to do something destructive, you'll do it manually with your admin account

### CLI Workflow Model

```
┌─────────────────────────────────────────────────────────────────┐
│                    SAFE CLI WORKFLOW                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. I propose a command with explanation                        │
│     "This command will create an S3 bucket for profile photos"  │
│     aws s3 mb s3://industrynight-assets-prod                    │
│                                                                 │
│  2. You review and approve (or ask questions)                   │
│                                                                 │
│  3. You run the command (or I run with your approval)           │
│                                                                 │
│  4. We verify the result together                               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 5. Cost Estimation (MVP)

### Monthly Cost Breakdown

| Service | Configuration | Est. Monthly Cost |
|---------|--------------|-------------------|
| EKS Control Plane | 1 cluster | $73 |
| EC2 (EKS Nodes) | 2x t3.medium (on-demand) | $60 |
| RDS PostgreSQL | db.t3.micro, 20GB | $15 (free tier: $0) |
| S3 | 10GB storage + transfers | $2 |
| CloudFront | 50GB transfer | $5 |
| Secrets Manager | 5 secrets | $2 |
| CloudWatch | Basic logging | $5 |
| NAT Gateway | 2 (one per AZ) | $65 |
| ALB | 1 load balancer | $22 |
| **Total (no free tier)** | | **~$250/month** |
| **Total (with free tier)** | | **~$235/month** |

### Cost Optimization Options

1. **Development Mode:** Scale EKS nodes to 0 when not developing
2. **Single NAT Gateway:** Use 1 NAT instead of 2 (less HA, saves $32/month)
3. **Spot Instances:** Use spot for non-prod nodes (60-70% savings)
4. **Reserved Instances:** Commit to 1-year for production (30% savings)

### MVP Budget Recommendation

- **Development:** ~$150/month (single NAT, scale down when idle)
- **Production:** ~$250/month (full HA setup)

---

## 6. Setup Sequence

### Phase 0: AWS Account Prep (You do manually)

- [ ] Enable MFA on root account
- [ ] Create `industrynight-admin` IAM user (your admin user)
- [ ] Create `industrynight-cli` IAM user (for CLI work)
- [ ] Set up AWS CLI profiles locally
- [ ] Set up billing alerts ($50, $100, $200 thresholds)
- [ ] Verify region (us-east-1)

### Phase 1: Networking Foundation

- [ ] Create VPC with public/private subnets
- [ ] Create Internet Gateway
- [ ] Create NAT Gateway(s)
- [ ] Configure route tables
- [ ] Create security groups

### Phase 2: Database

- [ ] Create RDS subnet group
- [ ] Create RDS PostgreSQL instance
- [ ] Store credentials in Secrets Manager
- [ ] Test connectivity

### Phase 3: Container Infrastructure

- [ ] Create ECR repository
- [ ] Build and push initial API image
- [ ] Create EKS cluster
- [ ] Create EKS node group
- [ ] Configure kubectl access

### Phase 4: Application Deployment

- [ ] Deploy API to EKS
- [ ] Create ALB Ingress
- [ ] Configure SSL certificate (ACM)
- [ ] Set up DNS (Route 53)
- [ ] Verify end-to-end connectivity

### Phase 5: Supporting Services

- [ ] Create S3 bucket for assets
- [ ] Set up CloudFront distribution
- [ ] Configure Twilio integration
- [ ] Set up SES for emails
- [ ] Configure CloudWatch logging

---

## 7. Learning Path

### Before We Start (Concepts to Understand)

**VPC Networking (Review):**
- Public vs private subnets
- NAT Gateway purpose (allows private subnet → internet)
- Security groups vs NACLs

**EKS Concepts (New for You):**
- Control plane vs worker nodes
- Node groups (managed vs self-managed)
- kubectl basics (get, describe, logs, apply)
- Kubernetes manifests (Deployment, Service, Ingress)
- Pod → Service → Ingress traffic flow

**Container Concepts:**
- Dockerfile basics
- Image registry (ECR)
- Container vs Pod

### Just-in-Time Learning

I'll explain each concept as we encounter it:

| When | What I'll Explain |
|------|-------------------|
| VPC setup | Subnet CIDR planning, route tables |
| EKS creation | eksctl vs console, cluster architecture |
| First kubectl | Kubeconfig, contexts, namespaces |
| First deployment | Deployment manifest, replicas, rolling updates |
| Ingress setup | ALB controller, annotations, TLS termination |
| Secrets | External Secrets Operator, K8s secrets |

---

## 8. CI/CD Architecture (GitHub Actions)

```
┌─────────────────────────────────────────────────────────────────┐
│                    GITHUB ACTIONS WORKFLOW                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Push to main branch                                            │
│         │                                                       │
│         ▼                                                       │
│  ┌─────────────────┐                                            │
│  │ Build & Test    │  npm test, lint, type-check                │
│  └────────┬────────┘                                            │
│           │                                                     │
│           ▼                                                     │
│  ┌─────────────────┐                                            │
│  │ Build Docker    │  docker build, tag with commit SHA         │
│  └────────┬────────┘                                            │
│           │                                                     │
│           ▼                                                     │
│  ┌─────────────────┐                                            │
│  │ Push to ECR     │  aws ecr push                              │
│  └────────┬────────┘                                            │
│           │                                                     │
│           ▼                                                     │
│  ┌─────────────────┐                                            │
│  │ Deploy to EKS   │  kubectl apply (staging)                   │
│  └────────┬────────┘                                            │
│           │                                                     │
│           ▼                                                     │
│  ┌─────────────────┐                                            │
│  │ Manual Approval │  (for production - optional)               │
│  └─────────────────┘                                            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**GitHub Actions Secrets Needed:**
- `AWS_ACCESS_KEY_ID` (for CI/CD user, separate from CLI user)
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION` (us-east-1)
- `ECR_REPOSITORY` (industrynight-api)
- `EKS_CLUSTER_NAME` (industrynight-prod)

---

## 9. Decisions Summary

| Question | Decision |
|----------|----------|
| Domain | Need to purchase (will do during setup) |
| AWS Region | us-east-1 (N. Virginia) |
| Existing Resources | Clean slate - no conflicts |
| CI/CD | GitHub Actions |
| Database | RDS PostgreSQL |
| Compute | EKS with managed node groups |
| SMS | Twilio |
| Email | AWS SES |
| Secrets | AWS Secrets Manager |

---

## 10. Next Steps

1. **You (Phase 0):** AWS account prep
   - Enable MFA on root
   - Create IAM users (admin + cli)
   - Set up billing alerts
   - Configure AWS CLI locally

2. **Together:** Domain selection and purchase
   - Check availability of industrynight.net, .io, .co, etc.
   - Register via Route 53 or external registrar

3. **Together (with review-before-execute):**
   - Phase 1: VPC and networking
   - Phase 2: RDS database
   - Phase 3: EKS cluster and ECR
   - Phase 4: Deploy API
   - Phase 5: Supporting services

4. **Deliverable:** Update this document with actual resource IDs and configurations

---

## Revision History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-02-04 | Initial architecture plan |
