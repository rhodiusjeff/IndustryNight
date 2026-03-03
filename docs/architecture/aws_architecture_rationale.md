# AWS Architecture Rationale

> Design decisions, tradeoffs, and the scaling story behind Industry Night's cloud deployment.

This document is a companion to [aws_architecture.md](aws_architecture.md) (the "what") and [aws_setup_commands.md](aws_setup_commands.md) (the "how"). This document covers the **why** — the reasoning behind every major decision, the tradeoffs accepted, where the architecture aligns with (or intentionally departs from) AWS best practices, and the concrete path from current state to supporting many thousands of concurrent users.

---

## Table of Contents

1. [Design Philosophy](#1-design-philosophy)
2. [Compute: Why EKS Over Simpler Options](#2-compute-why-eks-over-simpler-options)
3. [Database: PostgreSQL on RDS, No ORM](#3-database-postgresql-on-rds-no-orm)
4. [Networking: ALB, VPC, and the Cloudflare Layer](#4-networking-alb-vpc-and-the-cloudflare-layer)
5. [Storage: S3 with Public ACLs](#5-storage-s3-with-public-acls)
6. [CDN: CloudFront for Admin, Direct ALB for API](#6-cdn-cloudfront-for-admin-direct-alb-for-api)
7. [Authentication Architecture](#7-authentication-architecture)
8. [Security Posture](#8-security-posture)
9. [Secrets Management](#9-secrets-management)
10. [Container Strategy](#10-container-strategy)
11. [Deployment Pipeline](#11-deployment-pipeline)
12. [Environment Strategy](#12-environment-strategy)
13. [Cost Engineering](#13-cost-engineering)
14. [Operational Excellence: COOP System](#14-operational-excellence-coop-system)
15. [Graceful Degradation Philosophy](#15-graceful-degradation-philosophy)
16. [Scaling Path: Current → 10,000 Concurrent Users](#16-scaling-path-current--10000-concurrent-users)
17. [Relationship to AWS Well-Architected Framework](#17-relationship-to-aws-well-architected-framework)
18. [Accepted Tradeoffs and Known Gaps](#18-accepted-tradeoffs-and-known-gaps)
19. [Architecture Decision Records (ADRs)](#19-architecture-decision-records-adrs)

---

## 1. Design Philosophy

Three principles guide every infrastructure decision:

### Principle 1: Build for the next stage, not the final stage

Industry Night is a pre-revenue platform serving a niche creative community. The infrastructure must be production-grade (real users, real data, real uptime expectations) but cost-conscious. We sized for hundreds of concurrent users with a clear, non-speculative scaling path to thousands. We did not pre-build for millions.

This means choosing services that scale elastically (EKS, RDS, ALB) over fixed-capacity options, but configuring them at their smallest viable size. The architecture can grow by changing configuration values — not by re-architecting.

### Principle 2: Operational simplicity over architectural elegance

A two-person team (one developer, one product owner) cannot afford operational overhead. Every added service is another thing to monitor, debug, and pay for. We chose fewer, more capable services over a constellation of specialized ones:

- One database (PostgreSQL) handles relational data, JSON storage, full-text search, and analytics aggregations
- One compute platform (EKS) handles API serving, background jobs, and database proxying
- One storage service (S3) handles images, web assets, and backups

### Principle 3: Dev-prod parity with graceful degradation

The same codebase runs locally on a laptop and in production on AWS. External services (Twilio, SES, S3) degrade gracefully when credentials are absent — logging to console instead of throwing errors. This eliminates the need for mocks, stubs, or separate "dev mode" code paths, and ensures that the code running in production is the same code tested locally.

---

## 2. Compute: Why EKS Over Simpler Options

### The decision

Run the Node.js API on Amazon EKS (managed Kubernetes) with t3.small worker nodes.

### Alternatives considered

| Option | Monthly cost | Why not |
|--------|-------------|---------|
| **EC2 directly** | ~$15 | No auto-scaling, no health-based restarts, no rolling deploys. Manual load balancing. Works for a hobby project; too fragile for a platform serving real users at events. |
| **ECS Fargate** | ~$40-60 | Simpler than EKS, good auto-scaling. Viable choice. Rejected because: (1) EKS provides richer ecosystem (Helm charts, kubectl debugging, port-forward proxying), (2) Kubernetes skills transfer to any cloud provider, (3) the db-proxy pod pattern for secure DB access is native to K8s. |
| **Lambda + API Gateway** | ~$5-20 | Lowest cost at low traffic. Rejected because: (1) cold starts are hostile to real-time event check-in flows, (2) WebSocket support for future real-time features requires API Gateway v2 with added complexity, (3) connection pooling to RDS is awkward (RDS Proxy adds $15/mo), (4) deployment artifacts and debugging are fundamentally different from local dev. |
| **App Runner** | ~$25-40 | Simplest container option. Rejected because: (1) no HPA-equivalent fine-grained scaling, (2) limited networking control (no VPC peering, no pod-level networking), (3) no equivalent to K8s Jobs, CronJobs, or proxy pods. |

### Why EKS wins despite higher base cost

EKS costs ~$73/mo for the control plane alone — the most expensive option at idle. The justification:

1. **Horizontal Pod Autoscaler (HPA)**: Scales from 2 to 10 pods based on CPU/memory. During an industry night event with a surge of check-ins and QR scans, pods scale up automatically. After the event, they scale back down. This is table-stakes for event-driven traffic patterns.

2. **Rolling deployments**: Zero-downtime deploys are built in. `kubectl rollout restart` gradually replaces pods while the ALB drains connections from old ones. No maintenance windows needed.

3. **Health-based self-healing**: Liveness probes restart crashed pods. Readiness probes remove unhealthy pods from the load balancer. The system recovers from transient failures without human intervention.

4. **The db-proxy pattern**: A lightweight pod running `socat` provides a secure tunnel from developer laptops to RDS via `kubectl port-forward`. This eliminates the need to expose RDS publicly or manage bastion hosts — a significant security and operational win.

5. **Maintenance mode at the edge**: A single `kubectl patch` on the ingress resource switches the ALB to return 503 JSON for all requests. No code changes, no redeployment. Maintenance mode is an infrastructure concern, not an application concern.

6. **Future-ready**: Kubernetes natively supports CronJobs (analytics aggregation), Jobs (database migrations in CI/CD), and DaemonSets (logging agents). These are on the roadmap and require zero infrastructure changes to adopt.

### Node sizing rationale

**t3.small** (2 vCPU, 2 GiB memory) was chosen over t3.micro (2 vCPU, 1 GiB):

- The Node.js API with Express, `pg` connection pool, and in-memory multer uploads peaks at ~200-300 MiB per pod under load
- Two pods per node leaves ~1.2 GiB for kubelet, kube-proxy, and system overhead
- t3.micro's 1 GiB is too tight — OOM kills under load are likely
- t3.small provides comfortable headroom at only ~$14/mo more per node
- Burstable (T-series) instances are ideal because API traffic is spiky: quiet most of the day, intense during events

### Pod resource limits

```yaml
resources:
  requests: { cpu: 250m, memory: 256Mi }
  limits:   { cpu: 500m, memory: 512Mi }
```

- **Requests** are what the scheduler guarantees. 256Mi ensures the pod always has enough memory for baseline operation.
- **Limits** are the ceiling. 512Mi prevents a memory leak from consuming the entire node.
- **CPU limits at 500m (0.5 core)** allow bursting during request spikes while preventing a single pod from starving co-located pods.
- The 2:1 limit-to-request ratio provides burst headroom without overcommitting the node.

### Pod anti-affinity: preferred, not required

Pods *prefer* to land on different nodes but don't *require* it. With only 2 nodes and 2 pods, a "required" anti-affinity would mean a node failure makes one pod unschedulable until the node recovers. "Preferred" allows both pods on one node as a degraded-but-functional state.

---

## 3. Database: PostgreSQL on RDS, No ORM

### Why PostgreSQL

PostgreSQL is the default choice for a reason. It handles everything Industry Night needs in a single engine:

- **Relational data**: Users, events, tickets, connections — classic normalized schema
- **JSON storage**: `JSONB` columns for audit log payloads (`old_values`, `new_values`) and Posh webhook raw data
- **Array types**: `TEXT[]` for user specialties — avoids a junction table for a simple list
- **Full-text search**: Built-in `tsvector`/`tsquery` for future user and event search
- **GIN indexes**: Efficient indexing on JSONB and array columns
- **Mature ecosystem**: Every hosting provider, every ORM, every migration tool supports it

### Why RDS over self-managed

Running PostgreSQL on an EC2 instance saves ~$5/mo but adds:
- Manual backup configuration
- Manual failover
- Manual patching
- Manual storage management
- Risk of data loss from EC2 instance failure

RDS eliminates all of this. Automated backups, automated failover (when Multi-AZ is enabled), automated patching, and automated storage scaling. The $15/mo for db.t3.micro is the cheapest insurance against data loss available.

### Why no ORM

The API uses the `pg` library directly with parameterized SQL queries. No Prisma, no TypeORM, no Knex query builder.

**Rationale:**

1. **Transparency**: Every query is visible, debuggable, and optimizable. There's no hidden N+1 problem because every SQL statement is written explicitly.

2. **PostgreSQL-native features**: The schema uses `LEAST()`/`GREATEST()` for connection uniqueness, `json_build_object()` for enriched responses, custom enum types, and trigger-based `updated_at` timestamps. ORMs either don't support these or require escape hatches that negate their value.

3. **Performance predictability**: With raw SQL, the query plan is exactly what you'd expect from `EXPLAIN ANALYZE`. No ORM-generated subqueries, no lazy loading surprises, no identity map overhead.

4. **Team size**: With one developer, the "productivity boost" of an ORM is minimal — the developer already knows SQL. The debugging cost of ORM abstraction leaks exceeds the time saved writing queries.

**Tradeoff accepted**: No automatic migration generation from model changes. Migrations are hand-written SQL files, which requires discipline but produces migrations that are readable, reviewable, and safe to run in production.

### Connection pooling

The `pg-pool` library maintains a pool of persistent connections to RDS. Key behaviors:

- **Pool size**: Default (10 connections). Adequate for 2 pods = 20 total connections against RDS.
- **Error recovery**: On idle client error, the process exits. Kubernetes restarts the pod, which creates a fresh pool. This is intentionally aggressive — a corrupted connection pool is worse than a brief restart.
- **SSL everywhere**: All connections use SSL, even in development. `rejectUnauthorized: false` allows self-signed certs in dev while maintaining encryption in transit.

### Schema design decisions

**CASCADE deletes on user FKs**: When a user is deleted (account deletion, GDPR request), all their data — posts, comments, likes, connections, tickets — is automatically removed. The one exception is `audit_log`, which uses `SET NULL` to preserve the historical record while removing the user association.

**Tiered table organization**: Tables are organized into dependency tiers (0-4) for export/import ordering. Tier 0 tables (users, specialties) have no foreign keys. Each subsequent tier only references tables in lower tiers. This eliminates circular dependency issues during backup restoration.

**Text-based venue fields**: Events store `venue_name` and `venue_address` as plain text rather than referencing a `venues` table. This was a deliberate denormalization — venues are entered once per event, rarely reused exactly, and a first-class venue entity adds complexity (CRUD, deduplication, address normalization) without clear value at current scale.

---

## 4. Networking: ALB, VPC, and the Cloudflare Layer

### VPC topology

```
Internet
  │
  ├── Cloudflare (DNS + DDoS protection + SSL)
  │     │
  │     ├── api.industrynight.net → ALB (public subnets)
  │     │                            │
  │     │                            ├── us-east-1a (public subnet) ── NAT GW
  │     │                            └── us-east-1f (public subnet)     │
  │     │                                                               │
  │     │                            ┌── us-east-1a (private subnet) ◄──┘
  │     │                            │     ├── EKS node (t3.small)
  │     │                            │     └── RDS instance
  │     │                            └── us-east-1f (private subnet)
  │     │                                  └── EKS node (t3.small)
  │     │
  │     └── admin.industrynight.net → CloudFront → S3
```

### Why a single NAT Gateway

AWS recommends one NAT Gateway per Availability Zone for high availability. We use one.

**Cost**: A single NAT Gateway is $32/mo. Two would be $64/mo — a 100% increase for a failure mode (AZ-level NAT failure) that is extremely rare.

**Risk accepted**: If the NAT Gateway's AZ goes down, pods in the other AZ lose outbound internet access (to Twilio, SES, S3). The ALB and inbound traffic continue to work — the API can still serve cached data and handle requests that don't require external calls. This is an acceptable degradation for the cost savings.

**Scaling trigger**: When uptime SLA exceeds 99.9%, add a second NAT Gateway. This is a single `eksctl` configuration change.

### Why the ALB (not NLB, not nginx)

The AWS ALB (Application Load Balancer) is managed by the AWS Load Balancer Controller Helm chart, which translates Kubernetes Ingress resources into ALB configuration.

- **Layer 7 routing**: Path-based and host-based routing, HTTP/2 support, WebSocket support (future)
- **Native health checks**: ALB health checks integrate with K8s readiness probes. Unhealthy pods are automatically removed from the target group.
- **TLS termination**: ACM certificate handles SSL at the ALB. Pods receive plain HTTP, avoiding the complexity (and CPU cost) of per-pod TLS.
- **IP-mode targeting**: Targets individual pod IPs rather than EC2 instance IPs, enabling proper load distribution across pods on the same node.

**Why not NLB**: The Network Load Balancer (Layer 4) is cheaper and faster, but doesn't support path-based routing, HTTP health checks, or TLS termination. We need all three.

**Why not self-managed nginx**: An nginx ingress controller adds a pod that must be scaled, monitored, and configured separately. The ALB controller eliminates this operational burden by translating K8s resources directly to AWS-native load balancing.

### The Cloudflare layer

DNS is managed through Cloudflare rather than Route 53. This was driven by domain registration (Cloudflare was the registrar), but provides meaningful benefits:

1. **DDoS protection**: Cloudflare's free tier includes basic L3/L4 DDoS mitigation. The ALB has no native DDoS protection.
2. **DNS propagation speed**: Cloudflare's anycast network propagates DNS changes in seconds. Route 53 changes can take minutes.
3. **Future CDN option**: Cloudflare can proxy API traffic (orange cloud) for caching and WAF, though this is not currently enabled.

**Tradeoff**: DNS is managed outside AWS, creating a split-brain between the Route 53 hosted zone (created by eksctl, effectively unused) and the Cloudflare zone (authoritative). The COOP rebuild script handles this by auto-updating Cloudflare CNAMEs when the ALB DNS changes.

---

## 5. Storage: S3 with Public ACLs

### The decision

User-uploaded images (profile photos, event images, sponsor logos) are stored in S3 with per-object `public-read` ACLs, making them directly accessible via HTTPS URLs in the browser.

### Why public ACLs instead of signed URLs

| Approach | Pros | Cons |
|----------|------|------|
| **Public ACLs** (chosen) | Simple URLs, no expiration, cacheable by CDN/browser, works everywhere | Images are publicly accessible if URL is known |
| **Signed URLs** | Access control per-image, time-limited | URLs expire (breaks cached content), requires API call to generate, not CDN-cacheable without Lambda@Edge |
| **CloudFront + OAI** | S3 stays private, CDN caching | Additional infrastructure, invalidation complexity |

For Industry Night, all uploaded images are intended to be public — event photos, profile pictures, sponsor logos. There is no access-control requirement on images. Public ACLs provide the simplest, most performant, and most cacheable approach.

**S3 bucket configuration required for this to work:**

```
Object Ownership: BucketOwnerPreferred  (allows ACLs)
Block Public Access: BlockPublicAcls=false, IgnorePublicAcls=false
```

AWS has been pushing away from ACLs toward bucket policies. The `BucketOwnerPreferred` setting is the escape hatch that re-enables ACL-based access. This is a conscious decision to use a simpler (if legacy) access pattern for a use case where it's appropriate.

### Graceful degradation

When `S3_BUCKET` is not set (local development), the storage service returns a placeholder URL instead of uploading to S3. This means:

- The full image upload flow works locally (form submission, API processing, database record creation)
- Only the actual S3 upload is skipped
- No mocks, no test doubles, no separate code path

---

## 6. CDN: CloudFront for Admin, Direct ALB for API

### Admin app: CloudFront + S3

The admin dashboard is a Flutter web app compiled to static HTML/JS/CSS. CloudFront serves it from S3 with:

- **OAC (Origin Access Control)**: S3 bucket is private. Only CloudFront can read from it. This is the modern replacement for OAI (Origin Access Identity).
- **HTTPS everywhere**: CloudFront handles TLS for `admin.industrynight.net`
- **Global edge caching**: Admin users get fast loads regardless of location
- **Cache invalidation**: `deploy-admin.sh` invalidates `/*` after each deploy, ensuring fresh content within 1-2 minutes

### API: No CDN (yet)

API traffic goes directly through Cloudflare (DNS only, not proxied) to the ALB. There is no CDN for API responses.

**Why not**: API responses are personalized (user-specific data), rarely cacheable, and the added latency of an extra hop through CloudFront provides no benefit for dynamic content.

**When to add**: If the API starts serving static or semi-static content (event listings that don't change hourly, specialty lists), a short-TTL CloudFront distribution in front of the ALB would reduce ALB costs and improve latency. This is a future optimization, not a current need.

---

## 7. Authentication Architecture

### Two separate auth systems

| Aspect | Social App | Admin App |
|--------|-----------|-----------|
| **User table** | `users` | `admin_users` |
| **Auth method** | Phone + SMS OTP | Email + password |
| **Token family** | `social` | `admin` |
| **Token middleware** | `authenticate()` | `authenticateAdmin()` |
| **Access token TTL** | 15 minutes | 15 minutes |
| **Refresh token TTL** | 7 days | 7 days |

### Why two separate systems

Social users and admin users have fundamentally different identity models:

- **Social users** are creative professionals who may not have (or want to share) an email address. Phone number is the universal identifier in this community.
- **Admin users** are platform operators who need email-based credentials, password resets, and eventually SSO integration.

Sharing a single auth system would require either forcing phone numbers on admins or passwords on social users — both wrong.

### Token family separation

JWTs include a `tokenFamily` claim (`social` or `admin`). The `authenticate()` middleware rejects `admin` tokens, and `authenticateAdmin()` rejects `social` tokens. This is defense-in-depth: even if a social user's token is somehow used against an admin endpoint, the middleware rejects it before role checking begins.

### Why JWT over sessions

JWTs are stateless — the API doesn't need to query a sessions table on every request. This matters for:

1. **Scaling**: Any pod can validate any token without shared state
2. **Mobile clients**: JWTs are trivially stored in secure storage on iOS/Android
3. **Token refresh**: The 15-minute access / 7-day refresh pattern limits exposure if a token is compromised while keeping the user logged in

**Tradeoff**: JWTs cannot be revoked before expiry without a blocklist. For a 15-minute access token, this is acceptable — the blast radius of a compromised token is small. If instant revocation becomes necessary (e.g., banning a user mid-session), a Redis-backed blocklist is straightforward to add.

---

## 8. Security Posture

### Network security

```
Internet → Cloudflare (DDoS mitigation)
         → ALB (TLS termination, ACM cert)
         → VPC private subnets (no public IPs on nodes)
         → Security groups (port-level firewall)
         → Pod network policies (future)
```

**RDS is unreachable from the internet.** It lives in private subnets with a security group that only allows port 5432 from the EKS node security group. Developer access uses `kubectl port-forward` through the db-proxy pod — no bastion host, no public endpoint, no VPN required.

### Application security

| Layer | Mechanism |
|-------|-----------|
| **Input validation** | Zod schemas on all request bodies, query params, and path params |
| **SQL injection** | Parameterized queries (`$1, $2, ...`) everywhere — no string concatenation |
| **XSS** | Helmet.js sets Content-Security-Policy, X-XSS-Protection, X-Content-Type-Options |
| **CORS** | Allowlisted origins from `CORS_ORIGINS` env var |
| **Auth** | JWT with separate token families, 15-min access tokens, role-based middleware |
| **Password storage** | bcryptjs hashing for admin passwords |
| **HTTPS** | TLS termination at ALB (ACM cert) + SSL to RDS (force_ssl=1) |

### Container security

The Dockerfile enforces security best practices:

- **Non-root user**: The container runs as `nodejs` (UID 1001), not root. Even if the container is compromised, the attacker has limited privileges.
- **Alpine base**: Minimal attack surface — no package managers, no shell utilities beyond what's needed.
- **Multi-stage build**: Build dependencies (TypeScript compiler, dev packages) are not present in the production image.
- **Production-only dependencies**: `npm ci --only=production` excludes dev dependencies from the final image.

### What's intentionally missing

- **WAF**: AWS WAF adds ~$5/mo minimum + per-request charges. Cloudflare's free tier provides basic protection. WAF becomes worthwhile when handling payment data or facing targeted attacks.
- **Pod network policies**: Kubernetes NetworkPolicy resources can restrict pod-to-pod traffic. Not yet implemented because the cluster runs a single application. Worth adding when multiple services share the cluster.
- **Image scanning enforcement**: ECR scans images on push, but findings don't block deployment. A policy that fails builds on critical CVEs is a future CI/CD enhancement.

---

## 9. Secrets Management

### Current state

Secrets live in two places:

1. **AWS Secrets Manager**: Database credentials (`industrynight/database`), Cloudflare API token (`industrynight/cloudflare`)
2. **Kubernetes Secrets**: All application env vars (JWT_SECRET, TWILIO_*, S3_BUCKET, etc.)

The COOP rebuild script generates secrets and writes to both locations, keeping them in sync.

### Why not External Secrets Operator (ESO)

ESO would automatically sync Secrets Manager values into K8s Secrets, eliminating manual synchronization. It's the AWS-recommended approach.

**Why deferred**: ESO adds a controller pod, a Helm chart, and IAM role configuration. For a single application with infrequent secret changes, the operational overhead exceeds the benefit. Secrets are set at deploy time and rarely change.

**When to add**: When multiple applications share the cluster or when secrets rotate frequently (e.g., database password rotation).

### JWT_SECRET regeneration on rebuild

The COOP rebuild script generates a new `JWT_SECRET` with `openssl rand -base64 32`. This invalidates all existing access and refresh tokens, forcing every user to re-authenticate.

**Why this is acceptable**: A rebuild implies downtime (25-35 minutes). Users already can't use the app during this window. Forcing re-authentication on return is a minor inconvenience compared to the security risk of persisting a secret across infrastructure lifecycles.

---

## 10. Container Strategy

### Multi-stage Docker build

```dockerfile
# Stage 1: Build
FROM node:20-alpine AS builder
COPY . .
RUN npm ci && npm run build

# Stage 2: Production
FROM node:20-alpine
COPY --from=builder /app/dist ./dist
RUN npm ci --only=production
USER nodejs
CMD ["node", "dist/index.js"]
```

**Why multi-stage**: The build stage includes TypeScript compiler, type definitions, and dev dependencies (~200 MiB). The production image contains only compiled JavaScript and runtime dependencies (~80-100 MiB). This reduces image size by ~50%, reduces attack surface, and speeds up image pulls.

**Why Alpine**: The `node:20-alpine` base image is ~50 MiB versus ~350 MiB for `node:20` (Debian). Smaller images mean faster ECR pushes, faster pod starts, and less storage cost.

**Why node:20**: LTS release with the best balance of stability and modern features. We don't use bleeding-edge Node.js features, so LTS is appropriate.

### Image tagging strategy

Currently, all images are tagged `:latest`. This is simple but has a known limitation: rollback requires rebuilding the previous version.

**Future improvement**: Tag images with git SHA (`git rev-parse --short HEAD`) in addition to `:latest`. This enables instant rollback via `kubectl set image deployment/industrynight-api api=<ecr-uri>:<previous-sha>`.

---

## 11. Deployment Pipeline

### Current: Script-based deployment

```bash
# API deployment
./scripts/deploy-api.sh
# 1. docker build --platform linux/amd64
# 2. docker tag + push to ECR
# 3. kubectl rollout restart deployment/industrynight-api
# 4. kubectl rollout status (waits for completion)

# Admin app deployment
./scripts/deploy-admin.sh
# 1. flutter build web --release
# 2. aws s3 sync build/web/ s3://bucket --delete
# 3. aws cloudfront create-invalidation --paths "/*"
```

### Why scripts over CI/CD (for now)

GitHub Actions workflows are defined (`.github/workflows/`) but not fully wired. Deployments are triggered manually via shell scripts.

**Rationale**: During active development with frequent iteration, the feedback loop of `./deploy-api.sh` (2-3 minutes) is faster than push → CI → deploy (5-10 minutes). The developer can watch the rollout in real time, check logs immediately, and rollback manually if needed.

**When to automate**: When the team grows beyond one developer or when deployment frequency exceeds daily. The scripts are designed to be directly translatable to CI/CD steps — each script is idempotent and uses the same CLI tools available in GitHub Actions runners.

### Rolling update strategy

The deployment uses Kubernetes' default rolling update:

1. New pods are created alongside old pods
2. New pods pass readiness checks (HTTP GET `/health` responds 200)
3. Old pods are removed from the ALB target group
4. Old pods receive SIGTERM and drain connections (30s grace period)
5. Old pods are terminated

With `minReplicas: 2` and `maxSurge: 25%`, there is always at least 1 healthy pod serving traffic during deployment. Zero downtime.

### Database migration ordering

Migrations MUST run before deploying new API code. The deploy script does not enforce this — it's a manual step:

```bash
DB_PASSWORD=xxx node scripts/migrate.js   # Apply new schema
./scripts/deploy-api.sh                    # Deploy code that uses new schema
```

**Why not automated**: Running migrations in CI/CD requires a K8s Job with database access. The Job needs the db-proxy pod for connectivity, and the migration must complete before the deployment begins. This is straightforward to implement (it's on the technical debt list) but was deferred in favor of shipping features.

**Risk**: Deploying code before running migrations will cause runtime SQL errors for any query referencing new columns or tables. The migration script is safe to re-run (idempotent via `_migrations` table), so the fix is always: run `migrate.js`, then re-deploy.

---

## 12. Environment Strategy

### Why a dedicated dev environment on AWS

Industry Night uses real AWS infrastructure for development — not local Docker, not LocalStack, not mocked services. This is an intentional decision:

1. **Cloud-targeted code needs cloud infrastructure.** The API depends on RDS PostgreSQL, S3, SES, and Kubernetes-specific behavior (liveness probes, HPA, ingress). Local approximations add a layer of indirection that hides real bugs and creates false confidence.

2. **COOP scripts are the disaster recovery system.** They must be exercised regularly against real AWS to stay reliable. A dev environment provides a safe target for testing teardown/rebuild cycles without risking production data.

3. **Deployment scripts need real targets.** `deploy-api.sh` pushes to ECR and performs K8s rolling restarts. `deploy-admin.sh` syncs to S3 and invalidates CloudFront. These workflows are only testable against real infrastructure.

4. **Cost is manageable.** Dev costs ~$110/mo when running, ~$2/mo when hibernated via COOP. During active development this is the daily driver; during pauses, tear it down.

### Architecture: same account, different names

Both environments live in the same AWS account (`047593684855`) and region (`us-east-1`). They are isolated by naming convention, not by account boundary:

| Resource | Dev | Prod |
|----------|-----|------|
| EKS cluster | `industrynight-dev` | `industrynight-prod` |
| RDS instance | `industrynight-db-dev` | `industrynight-db` |
| K8s namespace | `industrynight-dev` | `industrynight` |
| S3 assets | `industrynight-assets-dev` | `industrynight-assets-prod` |
| S3 web admin | `industrynight-web-admin-dev` | `industrynight-web-admin` |
| Secrets Manager | `industrynight/database-dev` | `industrynight/database` |
| API domain | `dev-api.industrynight.net` | `api.industrynight.net` |
| Admin domain | `dev-admin.industrynight.net` | `admin.industrynight.net` |
| ECR image tag | `:dev` | `:latest` |

**Why same account:** At a team size of one, multi-account isolation (AWS Organizations, cross-account roles) adds operational complexity without meaningful security benefit. The naming convention provides sufficient isolation. If the team grows or compliance requirements emerge, account-level separation can be added without changing the scripts — only the AWS profile and account ID in the env files.

**Why same region:** Shared resources (ECR repo, ACM wildcard cert, Cloudflare zone) are region-scoped or global. Keeping both environments in `us-east-1` avoids cross-region complexity.

### Shared resources

These resources are created once and shared across environments:

- **ECR repository** (`industrynight-api`) — shared repo, isolated by image tag (`:dev` vs `:latest`)
- **ACM wildcard certificate** (`*.industrynight.net`) — covers all subdomains for both environments, free
- **Cloudflare DNS zone** — both environments' CNAME records live here
- **AWS CLI profile** (`industrynight-admin`) — same IAM user manages both environments

### Sizing differences

Dev is deliberately smaller than prod to minimize cost while maintaining architectural parity:

| Parameter | Dev | Prod | Rationale |
|-----------|-----|------|-----------|
| EKS nodes | 1 | 2 | Dev doesn't need HA |
| HPA min/max | 1/2 | 2/10 | Dev doesn't need burst capacity |
| RDS instance | db.t3.micro | db.t3.micro | Same tier is fine for both |

The dev environment runs the same K8s manifests, the same deployment strategy, the same ALB ingress pattern — just with smaller numbers. Bugs that would appear at scale (HPA thrashing, connection pool exhaustion) won't surface in dev, but that's acceptable: dev is for feature development and integration testing, not load testing.

### The `--env` flag

All scripts accept `--env dev` or `--env prod`, defaulting to `dev`. This was a deliberate safety choice: the most common operation (deploying during active development) should target the safest environment by default. Production requires explicit intent.

The implementation uses environment files (`scripts/coop/environments/{dev,prod}.env`) sourced by a `load_environment()` function in `config.sh`. K8s manifests use `__PLACEHOLDER__` tokens that are substituted via `sed` at apply time. Node.js scripts read environment variables (`IN_NAMESPACE`, `IN_DEPLOYMENT`) exported by `load_environment()`.

---

## 13. Cost Engineering

### Current cost breakdown

| Component | Monthly | % of total | Notes |
|-----------|---------|-----------|-------|
| EKS control plane | $73 | 40% | Fixed cost, non-negotiable |
| NAT Gateway | $32 | 17% | Single gateway (HA would double) |
| EC2 nodes (2× t3.small) | $28 | 15% | On-demand pricing |
| ALB | $22 | 12% | Fixed + per-LCU charges |
| RDS (db.t3.micro) | $15 | 8% | Single-AZ, no backups |
| Other (S3, CloudFront, Secrets, CloudWatch) | $14 | 8% | Minimal at current scale |
| **Total** | **~$184** | **100%** | |

### Cost optimization decisions

**Single NAT Gateway ($32 saved/mo)**: Acceptable risk at current scale. See [Networking section](#4-networking-alb-vpc-and-the-cloudflare-layer).

**t3.small over t3.medium ($28 saved/mo)**: The API's memory footprint (200-300 MiB per pod) fits comfortably in t3.small's 2 GiB. Upgrading to t3.medium (4 GiB) would only be needed if pod count per node exceeds 4-5.

**db.t3.micro over db.t3.small ($15 saved/mo)**: The database handles hundreds of queries per second at this tier. PostgreSQL's query planner and connection pooling are efficient enough that CPU is not the bottleneck. Storage I/O (gp2) will be the first constraint.

**No RDS backups ($0, risk accepted)**: Automated backups add ~$2-3/mo for 20 GB. The COOP export script provides on-demand backups (`pg_dump` + per-table exports). Automated daily backups should be enabled before soft launch — this is acknowledged technical debt.

**No Multi-AZ RDS ($15 saved/mo)**: A standby replica in another AZ provides automatic failover. At current scale, the 5-10 minute recovery time from a single-AZ RDS failure is acceptable. Multi-AZ becomes essential when uptime SLA exceeds 99.9%.

### The COOP cost story

The most aggressive cost optimization is the COOP (Continuity of Operations) system:

| State | Monthly cost | What's running |
|-------|-------------|----------------|
| **Full stack** | ~$184 | Everything |
| **Hibernation** | ~$2 | S3, ECR, Secrets Manager, Route 53 |
| **Savings** | **$182/mo** | EKS + RDS + NAT + ALB torn down |

For a pre-revenue platform in active development, the ability to tear down infrastructure between development sprints and rebuild in 30 minutes saves thousands of dollars per year. The data is preserved (S3 images, ECR container images, exported database backups), and the rebuild is fully scripted.

### Future cost optimizations

| Optimization | Savings | Complexity | When |
|-------------|---------|-----------|------|
| Spot instances for EKS nodes | ~$18/mo (60%) | Low (add `spot: true` to nodegroup) | When comfortable with spot interruptions |
| Reserved instances (1-year) | ~$8/mo (30%) | Low (AWS console purchase) | When committed to running 12+ months |
| Graviton instances (t4g) | ~$5/mo (20%) | Medium (rebuild ARM images) | When Node.js ARM performance is validated |
| VPC endpoints for S3/ECR | ~$5/mo (reduces NAT data transfer) | Low (eksctl config change) | When data transfer charges exceed $10/mo |

---

## 14. Operational Excellence: COOP System

### What COOP is

COOP (Continuity of Operations Plan) is a set of bash scripts that manage the full lifecycle of AWS infrastructure:

```bash
./scripts/coop/coop.sh status     # What's running? What's it costing?
./scripts/coop/coop.sh export     # Backup database to local files
./scripts/coop/coop.sh teardown   # Export + destroy EKS + RDS
./scripts/coop/coop.sh rebuild    # Recreate everything from scratch
./scripts/coop/coop.sh import     # Restore database from backup
```

### Why COOP exists

Most AWS architectures assume infrastructure is permanent. COOP assumes the opposite: infrastructure is ephemeral, and the ability to destroy and recreate it is a feature, not a bug.

**Benefits:**

1. **Cost control**: Tear down during dormant periods, rebuild when needed
2. **Disaster recovery testing**: Every rebuild is a disaster recovery drill. If the scripts work for cost savings, they work for actual recovery.
3. **Infrastructure drift prevention**: Rebuilding from scratch ensures the infrastructure matches the declared configuration. No manual console changes accumulate over time.
4. **Confidence**: The team knows exactly what happens when infrastructure is destroyed because they do it regularly.

### What COOP preserves vs destroys

| Resource | Teardown behavior | Why |
|----------|-------------------|-----|
| EKS cluster + nodes | **Destroyed** | $101/mo savings |
| RDS instance | **Destroyed** (snapshot taken) | $15/mo savings |
| NAT Gateway | **Destroyed** (with VPC) | $32/mo savings |
| ALB | **Destroyed** (with ingress) | $22/mo savings |
| S3 buckets | **Preserved** | Pennies/mo, contain user data |
| ECR repository | **Preserved** | Pennies/mo, contains deployable images |
| Secrets Manager | **Preserved** | $0.40/mo, contains credentials |
| ACM certificate | **Preserved** | Free, auto-renews |
| Route 53 zone | **Preserved** | $0.50/mo, domain routing |

### Rebuild automation

The rebuild script is fully automated (`--yes` flag skips confirmations):

1. Creates EKS cluster from `infrastructure/eks/cluster.yaml` (15-20 min)
2. Installs AWS Load Balancer Controller via Helm
3. Creates RDS instance with same configuration (5-10 min)
4. Generates new DB password, stores in Secrets Manager + K8s secret
5. Applies all K8s manifests (namespace, deployment, service, ingress)
6. Runs database migrations
7. Optionally imports data from backup directory
8. Updates Cloudflare DNS to point to new ALB
9. Verifies `/health` endpoint responds

Total time: 25-35 minutes, fully unattended.

---

## 15. Graceful Degradation Philosophy

A core architectural principle is that the API should always start and serve requests, even when external services are unavailable. This is implemented through feature flags on service availability:

### Service availability flags

```typescript
// storage.ts
export const s3Available = !!process.env.S3_BUCKET;

// sms.ts
export const twilioAvailable = !!(accountSid && authToken);
export const verifyAvailable = !!(twilioAvailable && verifySid);
```

### Degradation behavior

| Service | Available | Unavailable |
|---------|-----------|-------------|
| **S3** | Uploads to S3, returns public URL | Returns placeholder URL, logs `[DEV]` |
| **Twilio SMS** | Sends real SMS via Twilio Verify | Logs to console, returns devCode in response |
| **SES Email** | Sends via AWS SES | Logs email content to console |
| **Posh webhook** | Processes and stores orders | Logs payload, skips SMS/email invite |

### Why this matters

1. **Local development**: Run `npm run dev` with no environment variables. The API starts, all endpoints work, images get placeholder URLs, SMS codes appear in the console. No external service configuration needed.

2. **Partial outages**: If Twilio is down, the API doesn't crash — it continues serving all non-SMS functionality. If S3 is misconfigured, image uploads fail gracefully with a placeholder instead of a 500 error.

3. **Testing**: Integration tests can run against the real API without mocking external services. The degraded mode IS the test mode.

4. **New developer onboarding**: Clone the repo, run `npm install && npm run dev`, start building. No AWS account, no Twilio account, no environment variable scavenger hunt.

---

## 16. Scaling Path: Current → 10,000 Concurrent Users

The architecture was designed to scale incrementally. Each scaling stage addresses a specific bottleneck with a specific, non-speculative change.

### Current capacity estimate

| Component | Capacity | Bottleneck at |
|-----------|----------|--------------|
| 2 API pods (256-512 MiB each) | ~200 concurrent connections | Memory exhaustion |
| 2 t3.small nodes | ~4-6 pods total | Node memory/CPU |
| db.t3.micro (2 vCPU, 1 GiB) | ~500 queries/sec | CPU saturation |
| 10 pg-pool connections per pod | 20 total DB connections | Connection exhaustion |
| ALB | ~10,000 req/sec | Effectively unlimited for our needs |

**Estimated concurrent users**: ~500-1,000 with current configuration.

### Stage 1: 1,000-3,000 concurrent users

**Trigger**: HPA consistently scales to 4+ pods, p99 latency exceeds 500ms.

| Change | What | Effort |
|--------|------|--------|
| Increase HPA max | 10 → 20 pods | Config change |
| Add EKS nodes | 2 → 4 nodes (or t3.medium) | Config change |
| Upgrade RDS | db.t3.micro → db.t3.small (2 GiB) | Console click |
| Increase pool size | 10 → 25 per pod | Env var change |
| Enable RDS backups | 0 → 7 day retention | Console toggle |
| Add connection pooler | PgBouncer sidecar or RDS Proxy | New component |

**Cost impact**: ~$184 → ~$300/mo. Primarily from larger nodes and RDS instance.

### Stage 2: 3,000-10,000 concurrent users

**Trigger**: Database CPU consistently above 70%, read queries dominating.

| Change | What | Effort |
|--------|------|--------|
| RDS read replica | Offload read queries to replica | Medium (split read/write in API) |
| RDS Multi-AZ | Automatic failover | Console toggle |
| CloudFront for API | Cache GET /events, GET /specialties | Medium (cache headers + distribution) |
| Redis for sessions | Rate limiting, caching, pub/sub | New component (ElastiCache) |
| Spot instances | 60% compute savings | Config change (tolerate interruptions) |
| Second NAT Gateway | HA for outbound traffic | Config change |

**Cost impact**: ~$300 → ~$500-700/mo. RDS read replica is the largest new cost.

### Stage 3: 10,000+ concurrent users

**Trigger**: Single-writer database is the bottleneck, event-night traffic spikes exceed predictable scaling.

| Change | What | Effort |
|--------|------|--------|
| Aurora PostgreSQL | Auto-scaling storage, faster failover, up to 15 read replicas | Migration (compatible but requires testing) |
| Event-driven architecture | SQS/SNS for webhook processing, notifications | Significant refactor |
| CDN for all static content | CloudFront for S3 images | Low effort, high impact |
| API response caching | Redis-backed caching layer | Medium refactor |
| WebSocket support | Real-time notifications (replace polling) | New infrastructure (API Gateway WebSocket or socket.io) |
| Multi-region | Serve from multiple AWS regions | Major effort (database replication) |

**Cost impact**: ~$700 → ~$1,500-3,000/mo. Aurora alone is ~$200/mo minimum.

### Why this path is credible

Every step in this scaling path is a configuration change or a single-component addition — not a re-architecture. This is by design:

- **EKS + HPA** means compute scales horizontally by changing a number
- **RDS** means the database scales vertically (instance size) and horizontally (read replicas) without application changes
- **ALB** means the load balancer scales automatically and invisibly
- **Stateless API** means any pod can handle any request, enabling linear horizontal scaling
- **Connection pooling** means database connections are efficiently shared, not per-request
- **Parameterized SQL** means query patterns are compatible with pgBouncer, RDS Proxy, and Aurora

The architecture does not contain any component that would require replacement at the next scale level. It contains components that are *configured small* and can be *configured larger*.

---

## 17. Relationship to AWS Well-Architected Framework

The AWS Well-Architected Framework defines six pillars. Here's how Industry Night's architecture relates to each:

### Operational Excellence

| Practice | Status | Notes |
|----------|--------|-------|
| Infrastructure as code | **Partial** | EKS cluster defined in YAML, K8s manifests in git. VPC created by eksctl (not Terraform/CDK). |
| Automated deployment | **Partial** | Script-based (`deploy-api.sh`), not CI/CD-triggered. |
| Monitoring & observability | **Basic** | CloudWatch logs enabled, `/health` endpoint, pod liveness/readiness probes. No APM, no distributed tracing. |
| Runbook automation | **Strong** | COOP scripts automate teardown, rebuild, backup, restore. Maintenance mode is one command. |
| Change management | **Good** | Git-based workflow with PR reviews, protected branches, labeled issues. |

### Security

| Practice | Status | Notes |
|----------|--------|-------|
| Identity & access management | **Good** | IRSA for pod-level IAM, separate admin/social auth, token family separation. |
| Detection | **Basic** | CloudWatch audit logs enabled, application audit_log table. No GuardDuty, no CloudTrail analysis. |
| Infrastructure protection | **Good** | VPC isolation, private subnets, security groups, non-root containers, Cloudflare DDoS. |
| Data protection | **Good** | SSL everywhere (ALB TLS + RDS SSL), parameterized queries, bcrypt passwords. |
| Incident response | **Basic** | Manual. No automated alerting, no PagerDuty integration. |

### Reliability

| Practice | Status | Notes |
|----------|--------|-------|
| Fault isolation | **Good** | Pods across nodes (anti-affinity), private subnets across AZs. |
| Auto-recovery | **Good** | HPA + liveness probes + rolling deploys. |
| Backup & restore | **Manual** | COOP export/import scripts. No automated daily backups (RDS retention = 0). |
| Capacity planning | **Good** | HPA 2-10 pods, node ASG 1-4, clear scaling path documented. |
| Single points of failure | **Known** | Single NAT Gateway, single-AZ RDS. Documented and accepted. |

### Performance Efficiency

| Practice | Status | Notes |
|----------|--------|-------|
| Right-sizing | **Good** | t3.small nodes, db.t3.micro, 256-512Mi pod limits. Sized for current load. |
| Elasticity | **Good** | HPA for pods, ASG for nodes. Scales up on demand, down on quiet. |
| Caching | **Minimal** | No Redis, no API response caching. CloudFront for admin static assets only. |
| Database optimization | **Good** | Connection pooling, GIN indexes, parameterized queries, no ORM overhead. |

### Cost Optimization

| Practice | Status | Notes |
|----------|--------|-------|
| Right-sizing | **Good** | Smallest viable instances throughout. |
| Elasticity | **Good** | HPA prevents over-provisioning during quiet periods. |
| Reserved/Spot | **Not yet** | On-demand pricing. Savings opportunities documented for future. |
| Waste elimination | **Excellent** | COOP teardown eliminates 99% of costs during dormant periods. |

### Sustainability

| Practice | Status | Notes |
|----------|--------|-------|
| Resource efficiency | **Good** | Alpine containers, production-only dependencies, right-sized instances. |
| Managed services | **Good** | EKS, RDS, ALB, S3, CloudFront — AWS manages underlying infrastructure efficiency. |

---

## 18. Accepted Tradeoffs and Known Gaps

Every architecture accepts tradeoffs. Documenting them explicitly prevents future developers from "fixing" intentional decisions.

### Intentional tradeoffs

| Tradeoff | What we chose | What we gave up | Why |
|----------|--------------|-----------------|-----|
| EKS over simpler compute | Kubernetes ecosystem, HPA, rolling deploys | $73/mo control plane cost | Scaling and operational features justify the cost |
| No ORM | Full SQL control, PostgreSQL-native features | Auto-migrations, type-safe query builders | Transparency and performance over convenience |
| Public S3 ACLs | Simple, cacheable image URLs | Per-image access control | All images are intended to be public |
| Single NAT Gateway | $32/mo savings | Cross-AZ outbound resilience | Acceptable risk at current scale |
| Single-AZ RDS | $15/mo savings | Automatic failover | Acceptable risk pre-launch |
| JWT over sessions | Stateless auth, mobile-friendly | Instant token revocation | 15-min access tokens limit blast radius |
| Cloudflare over Route 53 | Free DDoS, fast propagation | Single-pane AWS management | Cloudflare is the registrar; benefits outweigh fragmentation |
| Script-based deploys | Fast iteration, real-time feedback | CI/CD automation, audit trail | Team size makes manual deploys efficient |
| No Redis cache | One fewer service to manage | API response caching, rate limiting | Not a bottleneck at current traffic |

### Known gaps (technical debt)

| Gap | Risk | Remediation | Priority |
|-----|------|-------------|----------|
| No automated RDS backups | Data loss on RDS failure | Enable 7-day retention | High (before soft launch) |
| `/health` doesn't check DB | Pod appears healthy with dead DB | Add `SELECT 1` to health check | Medium |
| No CI/CD pipeline | Manual deploy errors possible | Wire scripts into GitHub Actions | Medium |
| No API tests | Regressions undetected | Write Jest tests for critical flows | Medium |
| S3 images orphaned on event delete | Storage waste | Delete S3 objects before DB cascade | Low |
| JWT_SECRET regenerated on rebuild | All users logged out | Persist secret in Secrets Manager across rebuilds | Low |
| No rate limiting on auth endpoints | Brute-force OTP possible | Add express-rate-limit to /auth routes | High (before soft launch) |
| No container image tags (only :latest) | Cannot rollback to specific version | Tag with git SHA | Medium |

---

## 19. Architecture Decision Records (ADRs)

Key decisions captured in a lightweight ADR format for future reference.

### ADR-001: Use EKS for compute
- **Date**: 2025-02
- **Status**: Accepted
- **Context**: Need container orchestration with auto-scaling for event-driven traffic
- **Decision**: Amazon EKS with t3.small worker nodes
- **Consequences**: $73/mo control plane cost; Kubernetes operational complexity; rich ecosystem access

### ADR-002: PostgreSQL on RDS, no ORM
- **Date**: 2025-02
- **Status**: Accepted
- **Context**: Need relational database with JSON support, array types, and full-text search
- **Decision**: RDS PostgreSQL with `pg` library, hand-written SQL
- **Consequences**: Full control over queries; manual migration authoring; no auto-generated types

### ADR-003: Separate social and admin authentication
- **Date**: 2025-02
- **Status**: Accepted
- **Context**: Social users authenticate via phone; admin users need email/password
- **Decision**: Separate `users`/`admin_users` tables, separate token families, separate middleware
- **Consequences**: No cross-app token reuse; clear security boundary; two auth flows to maintain

### ADR-004: COOP teardown/rebuild system
- **Date**: 2026-02
- **Status**: Accepted
- **Context**: Pre-revenue platform spending $184/mo on infrastructure during development
- **Decision**: Scripted infrastructure lifecycle — tear down to $2/mo, rebuild in 30 minutes
- **Consequences**: $182/mo savings during dormant periods; forced infrastructure-as-code discipline; regular DR testing

### ADR-005: Cloudflare for DNS over Route 53
- **Date**: 2025-02
- **Status**: Accepted
- **Context**: Domain registered at Cloudflare; Route 53 domain registration blocked for new AWS accounts
- **Decision**: Use Cloudflare as authoritative DNS with CNAME records to AWS resources
- **Consequences**: Split-brain DNS management; COOP scripts must update Cloudflare on ALB changes; free DDoS protection

### ADR-006: Public S3 ACLs for user images
- **Date**: 2025-12
- **Status**: Accepted
- **Context**: Event images, profile photos, and sponsor logos need browser-accessible URLs
- **Decision**: Per-object `public-read` ACL with `BucketOwnerPreferred` ownership
- **Consequences**: Simple, cacheable URLs; no signed-URL expiration issues; requires legacy ACL settings

### ADR-007: Graceful service degradation
- **Date**: 2025-02
- **Status**: Accepted
- **Context**: External services (Twilio, SES, S3) should not prevent the API from starting or serving requests
- **Decision**: Feature flags check service availability; unavailable services log to console instead of failing
- **Consequences**: Zero-config local development; partial outage resilience; dev-prod parity without mocks

### ADR-008: Multi-environment with `--env` flag (same account)
- **Date**: 2026-03
- **Status**: Accepted
- **Context**: Need dedicated dev AWS environment for active development; production stays hibernated via COOP until post-revenue
- **Decision**: Same AWS account, naming-convention isolation, `--env dev|prod` flag on all scripts, environment files in `scripts/coop/environments/`, K8s manifest templating via `sed`, default to dev
- **Consequences**: Dev costs ~$110/mo when running; all scripts parameterized; K8s manifests are templates; shared ECR repo with tagged images; wildcard ACM cert covers all subdomains; future account-level isolation possible without script changes

---

*Last updated: 2026-03-02*
*Companion documents: [aws_architecture.md](aws_architecture.md) | [aws_setup_commands.md](aws_setup_commands.md) | [COOP guide](../guides/coop.md)*
