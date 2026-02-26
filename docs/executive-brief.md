# Industry Night — Executive Brief

**Report Date:** February 25, 2026
**Period:** Project Inception through Week 2
**Branch:** `feature/web-admin-login` (active development)

---

## 1. What Is Industry Night?

Industry Night is a platform for **creative professionals** (hair stylists, makeup artists, photographers, videographers, models, nail/lash technicians) in NYC to discover networking events and build professional community.

**Two products, one backend:**

| Product | Target User | Platform | Purpose |
|---------|------------|----------|---------|
| **Social App** | Creative professionals | iOS, Android, Web | Attend events, QR networking, community feed |
| **Admin App** | Platform operators | Web, iOS, Android | Manage events, users, sponsors, moderation |

**Revenue model:** Ticket sales (currently via Posh.vip, in-app Stripe planned for Phase 2), sponsor partnerships, and verified-user perks/discounts.

---

## 2. Project Timeline

| Date | Milestone |
|------|-----------|
| Feb 4, 2026 | Product requirements finalized (v1.8) |
| Feb 13, 2026 | Initial commit — project scaffolded |
| Feb 23, 2026 | Infrastructure laydown, domain migration, ops tooling |
| Feb 25, 2026 | PR #1 merged — foundation complete, admin auth in progress |

**Elapsed:** 12 days from first commit to current state.

---

## 3. What Has Been Built

### Backend API (Node.js / Express / TypeScript)
- **11 route modules** covering auth, users, events, connections, posts, sponsors, vendors, discounts, webhooks, admin, and admin-auth
- **4 middleware layers** — JWT auth, admin auth (token family separation), role-based access, Zod validation
- **3 service integrations** — Twilio SMS/Verify, AWS SES email, Posh.vip webhooks
- **JWT dual-auth system** — separate `social` and `admin` token families preventing cross-app token reuse
- **DevCode system** — simulator-friendly auth that bypasses Twilio when credentials aren't configured

### Database (PostgreSQL 15 on AWS RDS)
- **21 tables** across 3 migrations
- Full schema: users, admin_users, events, venues, tickets, connections, posts, comments, likes, sponsors, vendors, discounts, audit log, analytics tables, GDPR export tracking
- CASCADE delete design with audit log preservation (SET NULL)
- Seed data for specialties and dev environment

### Social App (Flutter/Dart — iOS, Android, Web)
- **19 screens** across 8 feature modules
- Auth: phone entry, SMS verify with devCode auto-fill
- Onboarding: profile setup (name, bio, specialties, social links)
- Events: browsing, detail view, activation code entry
- Networking: QR code display, QR scanner, connections list, digital business card, scanned-user sheet
- Community: feed, create post, post detail
- Search: user discovery, profile viewing
- Profile: view, edit, settings
- Perks: sponsor discounts, sponsor detail

### Admin App (Flutter/Dart — Web, iOS, Android)
- **16 screens** across 7 feature modules
- Auth: email/password admin login
- Dashboard: stats overview
- Users: list, detail, add user (with role assignment)
- Events: list, create, detail
- Sponsors: list, form, discount management
- Vendors: list, form
- Moderation: posts list, announcements

### Shared Package (Flutter/Dart)
- **9 data models** with JSON serialization (auto-generated)
- **7 API clients** — base HTTP client + auth, users, events, connections, posts, admin, admin-auth
- Utilities: secure storage, validators, formatters, constants

### Infrastructure & Operations
- **AWS EKS cluster** on us-east-1 with auto-scaling (2-10 pods)
- **Kubernetes manifests** — deployment, service, ingress, secrets, HPA
- **SSL/TLS** via ACM on `api.industrynight.net`
- **ECR** container registry with Docker build pipeline
- **COOP system** — infrastructure lifecycle scripts (teardown to ~$3/mo, rebuild from scratch, database backup/restore)
- **CI/CD workflows** — GitHub Actions for API, mobile, and web

### Operational Scripts
- `seed-admin.js` — bootstrap admin users
- `db-reset.js` — full database reset with migrations
- `db-scrub-user.js` — GDPR-compliant user deletion
- `maintenance.sh` — K8s maintenance mode toggle
- `deploy-api.sh` — Docker build + ECR push + K8s rollout
- `coop.sh` — single entry point for infra status, teardown, rebuild, export, import

---

## 4. Codebase Metrics

| Component | Lines of Code | Files |
|-----------|--------------|-------|
| Backend API (TypeScript) | 2,269 | 24 |
| Flutter Apps + Shared (Dart) | 10,006 | 63 |
| Database (SQL) | 545 | 5 |
| Scripts (JS + Bash) | 2,663 | 17 |
| Infrastructure (YAML) | 253 | 7 |
| **Total** | **~15,700** | **116** |

| Metric | Count |
|--------|-------|
| Git commits | 8 |
| API route modules | 11 |
| Database tables | 21 |
| Social app screens | 19 |
| Admin app screens | 16 |
| Shared data models | 9 |
| API clients | 7 |
| Operational scripts | 13+ |

---

## 5. Architecture Decisions Made

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Database | PostgreSQL 15 (RDS) | Relational model fits domain; no ORM, direct SQL |
| Auth (social) | Phone + SMS OTP | Passwordless, phone-based identity for creatives |
| Auth (admin) | Email + password | Separate `admin_users` table, separate token family |
| Mobile framework | Flutter/Dart | Single codebase for iOS, Android, Web |
| API framework | Express + TypeScript | Proven, team familiarity |
| Container orchestration | AWS EKS (Kubernetes) | Scalability, learning investment |
| SMS provider | Twilio (with Verify API) | DevCode fallback for local/simulator testing |
| Ticketing | Posh.vip (webhook integration) | Existing brand presence, staff trained on Posh |
| State management | Provider + ChangeNotifier | Simple, sufficient for current scope |
| Cost management | COOP teardown/rebuild scripts | Reduce AWS spend from ~$160/mo to ~$3/mo during downtime |

---

## 6. Implementation Status vs Plan

| Phase | Description | Status |
|-------|-------------|--------|
| **1A** | Foundation (Backend + Auth) | **Complete** |
| **1B** | Core Mobile App (login, profile, events) | **Complete** |
| **1C** | Verification & QR Networking | **Complete** |
| **1D** | Event Social Features | **Screens built** |
| **1E** | Community Board | **Complete** |
| **1F** | Creative Search | **Complete** |
| **2A** | Admin App — Foundation | **Complete** |
| **2B** | Admin App — Event Management | **Complete** |
| **2C** | Admin App — Sponsor Management | **Complete** |
| **2D** | Admin App — Vendor Management | **Complete** |
| **2E** | Admin App — Content Moderation | **Complete** |
| — | Admin Auth (email/password) | **In Progress** (current branch) |
| 3 | Advanced Features (Stripe, push, analytics) | Not started |

---

## 7. Current Work in Progress

**Branch:** `feature/web-admin-login`

Active development on admin authentication:
- Admin auth API routes (`/admin/auth` — login, refresh, me, logout)
- Admin auth middleware (JWT with `tokenFamily: 'admin'`)
- `admin_users` database migration (003)
- Shared Dart `AdminUser` model and `AdminAuthApi` client
- `seed-admin.js` script for bootstrapping admin accounts

---

## 8. Known Technical Debt

| Item | Impact | Priority |
|------|--------|----------|
| No API tests (Jest configured but empty) | Risk of regressions | High |
| No DB connectivity check in `/health` | Silent failures in production | Medium |
| No pre-deploy migration runner in CI/CD | Manual migration step required | Medium |
| No post-deploy smoke tests | No automated deploy verification | Medium |
| No down-migration files | Cannot rollback schema changes | Low |

---

## 9. AWS Cost Profile

| State | Monthly Cost | Description |
|-------|-------------|-------------|
| **Full running** | ~$160/mo | EKS cluster + RDS + networking |
| **Hibernated** (COOP teardown) | ~$3/mo | S3 backups + Route53 only |

COOP scripts enable full teardown and rebuild, preserving all data via `pg_dump` backups.

---

## 10. What's Next

1. **Complete admin auth** — finish the login flow connecting Admin App to backend
2. **End-to-end testing** — validate social app auth flow with live backend
3. **First live event integration** — test activation code + QR networking at a real Industry Night
4. **API test coverage** — establish baseline test suite
5. **Phase 2 planning** — in-app ticketing (Stripe), push notifications, analytics

---

## Appendix: How to Regenerate This Brief

This document lives at `docs/executive-brief.md`. To produce an updated version:

1. Review recent git history: `git log --oneline -20`
2. Check current branch and WIP: `git status`, `git diff --stat master...HEAD`
3. Count codebase metrics:
   - API: `find packages/api/src -name '*.ts' | xargs wc -l`
   - Dart: `find packages/social-app/lib packages/admin-app/lib packages/shared/lib -name '*.dart' -not -name '*.g.dart' | xargs wc -l`
   - Screens: `find packages/social-app/lib/features -name '*_screen.dart' | wc -l`
4. Update sections 3-7 with new work completed
5. Move resolved debt items out of section 8
6. Update the report date at the top

**Suggested cadence:** Weekly, at end of each development sprint.
