# Industry Night Master Plan v2

**Version:** 2.1
**Date:** March 22, 2026
**Status:** Active Planning
**Audience:** Product Owner, Engineering Leadership, CODEX Implementation Agent

---

## Executive Summary

Industry Night is a platform for NYC creative professionals (hair stylists, makeup artists, photographers, videographers, etc.) to discover networking events, make connections, and build community. The platform consists of a mobile-first Flutter social app, an admin web dashboard (currently Flutter, migrating to React), and a Node.js/PostgreSQL backend on AWS EKS.

The platform's happy-path infrastructure is solid — authentication, event management, QR networking, and admin tooling all work end-to-end. However, the implementation deviates from requirements in structurally significant ways, and several social features remain stubbed out. More importantly, the platform is **ready to transact** (events, check-ins, QR connections work) but **not yet ready to retain** (community features are incomplete, perks/sponsors are non-functional, analytics is entirely absent).

This document consolidates the current state assessment, new requirements from recent planning, a complete gap analysis, a phased implementation plan with effort estimates, and architectural specifications for the React admin migration. It is designed to guide a code-generating agent (CODEX) through systematic implementation while keeping human stakeholders aligned on priorities and trade-offs.

---

## 1. Current State Assessment

### 1.1 What Works End-to-End

| Category | Status | Notes |
|----------|--------|-------|
| Phone SMS authentication | ✅ Complete | Twilio Verify (prod) / devCode (dev), JWT with token families |
| Event management (admin) | ✅ Complete | Full CRUD, multi-image upload with S3, hero image system, publish gate |
| Event check-in flow | ✅ Complete | Activation code validation (QR scan or manual entry), ticket validation |
| QR networking | ✅ Complete | Instant mutual connections, celebration overlay, auto-verification, polling notifications |
| Admin dashboard | ✅ Complete | Live stats (users, events, connections, posts), user management, event CRUD |
| Posh webhook integration | ✅ Complete | Receives new_order events, stores posh_orders, sends invite SMS/email |
| Remember-me login | ✅ Complete | Token persistence across app launches |
| Email/password admin auth | ✅ Complete | Separate admin_users table, token family isolation |

### 1.2 What's Stubbed (UI exists, no API wiring)

| Feature | Screens | Impact |
|---------|---------|--------|
| Community Board | Feed, Create Post, Post Detail | 10 hardcoded fake posts, no API calls |
| User Search | Search, User Profile | 10 hardcoded results, no API calls |
| Perks/Sponsors Display | Perks Screen, Sponsor Detail | Hardcoded fake sponsors, no API calls |
| Post Moderation (admin) | Posts List, Announcements | 100% fake data, no API integration |
| Profile Photo Upload | Onboarding, Edit Profile | UI buttons exist, no backend endpoint |

### 1.3 Scorecard: Implementation vs. Requirements

| Component | Complete | Partial | Stub | Missing |
|-----------|----------|---------|------|---------|
| API Routes (40 total) | 32 | 3 | 0 | 5 |
| Social App Screens (20) | 11 | 3 | 6 | 0 |
| Admin App Screens (21) | 16 | 3 | 2 | 0 |
| Shared Models & Clients | 7/10 | 3 | 0 | 0 |

**Overall:** ~75% of core platform built; social retention features incomplete; admin migration not yet started.

### 1.4 Key Finding: Ready to Transact, Not Yet Ready to Retain

The platform successfully handles the transactional loop: users create accounts, discover events, check in with activation codes, make QR connections, and leave. However, the features that drive repeated engagement — community posts, user search, perks/discounts, analytics — remain non-functional. Without these, user retention will be poor even if the transactional flow is smooth.

---

## 2. New Requirements Inventory

The following features have been prioritized for the next phase of development. Each is characterized by scope, business rationale, and dependencies.

### 2.1 React Admin App Migration

**Description:** Migrate the admin dashboard from Flutter Web to Next.js (React + TypeScript + shadcn/ui + Tailwind CSS) with dark-first design system.

**Why it matters:** Flutter Web is not optimized for desktop workflows. The desktop experience is sluggish, the modal/drawer patterns don't feel native, and team onboarding is challenging (Flutter developers are rare in NYC). React is the standard for web admin dashboards, offers better performance, and attracts more experienced engineers.

**Scope:** Large (4-6 weeks of concurrent development)

**Dependencies:** None (can run in parallel with social app development). Requires design system specification (done; see docs/design/).

### 2.2 LLM Content Moderation Pipeline

**Description:** Posts run through asynchronous moderation before appearing. Two-stage pipeline: Haiku (fast, cheap, high-volume) handles clear violations → Sonnet for borderline cases. Confidence-based routing: auto-approve safe content, auto-reject flagrant violations, flag uncertain cases for human review.

**Why it matters:** Community boards are harassment vectors. Proactive moderation protects users and reduces admin burden. LLM-based moderation is fast and cost-effective at scale.

**Scope:** Medium (2-3 weeks)

**Dependencies:** Community feed must be wired first (§2.3).

### 2.3 Community Board (Wire Up Existing Stub)

**Description:** Connect the existing stub screens to the API. Posts auto-submit with `is_hidden=false`, then run through moderation pipeline asynchronously. Verified-users-only gate enforced server-side. Image posts supported. Admin can create announcements (highlighted in feed).

**Why it matters:** Community is the primary retention driver. It gives users a reason to open the app between events.

**Scope:** Medium (2-3 weeks for API wiring + state management, plus 1 week for LLM integration)

**Dependencies:** None for basic wiring. Moderation pipeline depends on this being fully functional first.

### 2.4 Jobs Board (Separate from Community)

**Description:** New feature: structured job postings. Distinct from general community posts. New `jobs` table with title, description, role/specialty required, compensation/rate, duration, location, remote flag. Jobs dashboard in social app (dedicated tab). Search/filter by specialty, remote, rate. Only verified employer accounts can post jobs. Admin manages job listings.

**Why it matters:** Jobs board is a B2B revenue lever (employers pay to post). It's also a strong engagement hook for workers — they return regularly to check for opportunities.

**Scope:** Medium (3-4 weeks)

**Dependencies:** Primary specialty designation (§2.7). Hire confirmation flow (§2.5).

### 2.5 Hire Confirmation Flow

**Description:** Either party (job poster OR worker) can initiate "I was hired for this job" confirmation. Other party gets notification with verification request. Once both confirm, the hire is recorded in the database. Only after confirmed hire can the job poster post a professional rating (§2.6).

**Why it matters:** Enables verified, bidirectional hire-to-rating pipeline. Prevents false ratings.

**Scope:** Small (1-2 weeks)

**Dependencies:** Jobs Board (§2.4).

### 2.6 Professional Ratings

**Description:** Employer-verified reviews of workers. Available only after both parties confirm a hire. Rating covers work quality, professionalism, communication, would-hire-again. Visible on user profiles. LLM-moderated like posts. Platform can reject ratings that violate ToS. Ratings data feeds analytics and data products.

**Why it matters:** Creates verifiable track record for workers, trust signal for employers. Key data product (employers pay for access to rated talent).

**Scope:** Medium (2-3 weeks)

**Dependencies:** Hire confirmation flow (§2.5), LLM moderation pipeline (§2.2).

### 2.7 Primary Specialty Designation

**Description:** Users select multiple specialties as now, but must designate one as "primary." Schema change: add `users.primary_specialty_id` FK to specialties. Updated UX in profile/onboarding to allow designation.

**Why it matters:** Simplifies filtering and search. "Primary" becomes the first thing shown on profiles, reducing ambiguity in multi-specialty users.

**Scope:** Small (1 week)

**Dependencies:** None.

### 2.8 Influence Metric

**Description:** Compute network influence using a PageRank variant weighted by event attendance, connections made at events, and post engagement. Run nightly (batch job). Used primarily in data products and search ranking. Avoid displaying raw score on user profiles (mitigates leaderboard/status anxiety dynamics).

**Why it matters:** Enables sorting/ranking users by influence. Powers "Find High-Impact Talent" data product.

**Scope:** Medium (2-3 weeks for algorithm + nightly job)

**Dependencies:** None for implementation. Product decision needed: compute in Postgres vs. external service (Spark/DuckDB)?

### 2.9 Event Wrap Report

**Description:** Auto-generated 24 hours after event end. AI (Claude) drafts the report from platform data: attendance breakdown, connections made, specialty distribution, perk redemptions, community post engagement. Report goes to admin review queue. Operators can edit with AI assistance. Distributed to customers with data product. Social media export is nice-to-have.

**Why it matters:** Delivers data product value. Saves IN staff manual report writing. Gives events analytical weight.

**Scope:** Medium (2-3 weeks for job + LLM orchestration + review queue)

**Dependencies:** LLM pipeline established (§2.2). Event data complete (analytics tables populated).

### 2.10 Admin User Management

**Description:** CRUD screen for admin_users table (separate from social users). Operations: create, edit, deactivate, view login history. Fields: email, name, role (admin_role), created_at, last_login.

**Why it matters:** Enables platform operators to onboard new admins without database access. Required for access control.

**Scope:** Small (1 week)

**Dependencies:** None.

### 2.11 Posh Orders Visibility

**Description:** Admin screen showing posh_orders with reconciliation status (linked to IN user? linked to ticket? unlinked?), order details, manual exception handling (re-link, create ticket, investigate).

**Why it matters:** Operational transparency. Reveals data quality issues (unlinked orders). Enables fast resolution of "I bought a ticket but can't log in" issues.

**Scope:** Small (1-2 weeks)

**Dependencies:** None (backend data already exists).

### 2.12 Virtual/Avatar Attendee Concept

**Description:** A sick or immunocompromised person attends virtually via an iPad held by another attendee (or FaceTime/Teams). The virtual attendee gets a ticket and checks in, enabling QR connections through their avatar device. No engineering change needed — the existing QR system supports this naturally.

**Why it matters:** Accessibility feature. Positions IN as inclusive. Record for community comms.

**Scope:** Zero engineering (pure UX/community innovation)

**Dependencies:** None.

### 2.13 RBAC Architecture (Role-Based Access Control)

**Description:** Formalize access control across the platform using three separate account tables as the RBAC mechanism — no full ACL system needed at current scale. Permissions are defined in code (`permissions.ts`). Each account type has its own authentication flow, token family, and capability set.

**Account tables:**
- `users` — social app users (phone OTP auth); `user_role` simplified (remove `venueStaff`)
- `admin_users` — admin dashboard users (email/password auth); `admin_role: platformAdmin | moderator | eventOps`
- `job_poster_accounts` — employer job posting accounts (email/password, separate portal); lifecycle: `pending → probationary → active → suspended`

**venueStaff migration:** Removed from `user_role` enum on `users` table. Venue check-in staff use the React admin app with `eventOps` role — they get a mobile-optimized Event Ops section that handles check-in queue, wristband confirmation, and Posh order exceptions.

**Permissions pattern (`packages/react-admin/lib/permissions.ts`):**
```typescript
export const PERMISSIONS = {
  'posts:read':               { social: ['verified'] },
  'posts:create':             { social: ['verified'] },
  'connections:create':       { social: ['user', 'verified'] },
  'perks:read':               { social: ['verified'] },
  'jobs:read':                { social: ['verified'], jobPoster: ['active'] },
  'hire_confirmation:create': { social: ['verified'], jobPoster: ['active'] },
  'admin:dashboard':          { admin: ['moderator', 'eventOps', 'platformAdmin'] },
  'admin:users:read':         { admin: ['moderator', 'platformAdmin'] },
  'admin:users:write':        { admin: ['platformAdmin'] },
  'admin:events:read':        { admin: ['eventOps', 'platformAdmin'] },
  'admin:events:write':       { admin: ['eventOps', 'platformAdmin'] },
  'admin:moderation:write':   { admin: ['moderator', 'platformAdmin'] },
  'admin:config':             { admin: ['platformAdmin'] },
  'jobs:create':              { jobPoster: ['active'] },
  'ratings:create':           { jobPoster: ['active'] },
};
```

**Scope:** Medium (2 weeks — schema migration for eventOps + job_poster_accounts, permissions.ts, route guards in React admin)

**Dependencies:** React Admin Foundation (§Phase 2).

### 2.14 Push Notifications (FCM)

**Description:** Firebase Cloud Messaging (FCM) for iOS and Android. Flutter `firebase_messaging` package. `fcm_token` stored on user record, updated on login. First use case: wristband confirmation ("🎉 You're in. Welcome to Industry Night"). Additional use cases: new connection, new message, job application status.

**Wristband notification detail:** When Event Ops marks wristband as issued, backend triggers FCM push to that user's device. Notification deep-links to the event's Who's Here view. Additive only — wristband delivery does not block any functional flow.

**Why it matters:** The wristband notification creates a memorable, celebratory check-in moment. All other features work without it. It's the first high-impact use of push that makes the platform feel alive.

**Scope:** Medium (2 weeks for FCM setup, token storage, first push use case)

**Dependencies:** Event Ops screen functional; users.fcm_token column added.

### 2.15 Event Ops Screen (React Admin — eventOps role)

**Description:** Mobile-optimized section of the React admin for `eventOps` staff at venue. Features:
- **Real-time check-in stream** via SSE (Server-Sent Events): "12 checked in, 9 wristbands confirmed" delta visible live
- **Wristband confirmation flow:** Staff taps attendee card → "Mark wristband issued" → timestamps `wristband_issued_at` on ticket → triggers FCM push to attendee device
- **QR tablet check-in mode:** Full-screen tablet view shows a dynamic QR encoding the event activation code; attendee scans with phone → auto-check-in (4-digit fallback)
- **Posh order exceptions:** Unlinked Posh orders appear in side queue for manual resolution

**Why it matters:** Replaces all check-in tooling for venue staff. eventOps staff only need this screen — no other admin sections visible to their role.

**Scope:** Medium (2-3 weeks — SSE endpoint, wristband API, FCM trigger, React admin mobile layout)

**Dependencies:** Phase 2 React Admin Foundation; FCM setup (§2.14).

### 2.16 Image Assets Architecture

**Description:** Promote uploaded images to first-class `image_assets` table rather than storing raw S3 URLs on entity tables. All images (event images, sponsor/vendor logos, user profile photos, job post images) reference the same asset table. Enables image reuse, LLM-driven cleanup suggestions, near-duplicate detection, and archive vs. delete distinction.

**Key behaviors:**
- Images uploaded to S3, then `image_assets` record created with metadata (file_size, dimensions, ai_description, usage_count)
- Entity tables (events, customers, users, jobs) FK to `image_assets` rather than storing raw URLs
- Community post photos also stored as image assets; admin can view "From Community" picker to reuse social content in events/sponsors (per ToS)
- Weekly LLM cleanup job: flags unused images (usage_count=0, last_used_at > 30 days) as `deletion_suggested`; near-duplicate detection groups similar photos
- Admin image catalog shows suggested deletes with AI reasoning; admin chooses archive (soft-delete, keeps S3) vs. delete (removes from S3)
- Event delete cascades to image asset usage records, but asset itself preserved until explicit cleanup

**Scope:** Large (3-4 weeks — schema migration, S3 upload refactor, LLM cleanup job, admin UI)

**Dependencies:** Phase 0 fixes; existing S3/admin image catalog.

### 2.17 Platform Configuration & LLM Telemetry

**Description:** Two new operational tables:

**`platform_config`** — admin-editable key/value store for configuration (LLM model versions, confidence thresholds, feature flags). NOT for secrets. Secrets stay in AWS Secrets Manager and are injected as environment variables. Admin settings screen allows reading/editing config values with descriptions.

**`llm_usage_log`** — per-call telemetry for all LLM calls (model, feature, input/output tokens, latency, success/error). Enables cost tracking, debugging, and rate limiting decisions.

**API keys management:** Admin settings shows API key status (configured/not configured) and "Test Connection" button per service. Admin can link out to AWS Console for rotation. Key values are NEVER shown in the UI or API responses.

**Scope:** Small (1 week — two table migrations, API endpoint, admin settings screen section)

**Dependencies:** None.

### 2.18 Terms of Service & Privacy Policy

**Description:** Platform-wide ToS and Privacy Policy needed before App Store submission and public launch. Legal review required. Covers: UGC image reuse license, professional ratings standards, LLM data processing disclosure, data products use of platform data.

**`user_agreements` table** tracks version acceptance: user_id, tos_version, accepted_at, ip_address, user_agent. Shown to users on first login after new ToS version.

**Timing:** Implement the UI/acceptance flow in Phase 2. Finalize legal text before App Store submission (coordinate with legal counsel). "Export My Data" (GDPR/CCPA) is a **late-phase separate feature** — it is NOT a prerequisite for Delete Account or App Store compliance.

**Scope:** Small engineering (1 week — user_agreements table, in-app acceptance modal), but requires external legal review timeline.

**Dependencies:** Legal counsel available; scheduled for Phase 2 before App Store submission.

---

## 3. Complete Gap Analysis

### 3.1 Social App Gaps

| Feature | Current | Target | Effort | Priority |
|---------|---------|--------|--------|----------|
| Community feed | Stub (10 hardcoded) | Wired to API, paginated, refreshable | Medium | P1 |
| Create post | Stub (Future.delayed) | Wired to API, image upload support | Small | P1 |
| Post detail + comments | Stub (static) | Wired to API, comment add/delete, like optimistic | Medium | P1 |
| Search users | Stub (10 hardcoded) | Debounced query, specialty filters, pagination | Medium | P1 |
| User profile (other users) | Stub (static) | Loads from API, edit own only, follow/connect button | Small | P1 |
| Profile photo upload | Button no-op | Picks image, uploads to API, stores URL | Medium | P1 |
| Social links editing | No UI | Add/edit/remove links (Instagram, TikTok, etc.) | Small | P1 |
| Who's Going / Who's Here | Not built | Event tabs showing connections with tickets/checked-in status | Large | P1 |
| Delete account button | Missing | Settings → Delete Account → confirmation → backend call | Small | P0 |
| Verification status display | Implicit | "Verified" badge on profiles | Small | P1 |
| Primary specialty display | All specialties | Show primary first, rest as secondary | Small | P1 |
| Jobs board tab | Not built | List, filter, detail, apply flow | Large | P2 |
| Perks/sponsors display | Stub | API-wired, show customer name/logo/discounts | Medium | P2 |
| Event bookmarks | Not built | Save event for later, view saved list | Small | P2 |
| Event filtering | No filtering | Filter by market area (from user profile) | Small | P1 |

**Critical gaps:** Community board wiring (blocks retention), Delete Account button (App Store compliance).

### 3.2 Admin App Gaps (Flutter → React)

| Workflow | Flutter Status | React Status | Effort | Notes |
|----------|---|---|---|---|
| Authentication | ✅ | TBD | Small | Email/password, JWT persistence |
| Dashboard | ✅ | TBD | Small | Stats cards, recent activity |
| User management | ✅ | TBD | Medium | List, search, detail, add, ban, verify, role change |
| Event management | ✅ (full) | TBD | Large | Create, edit, list, detail, publish gate, images, partners |
| Sponsor/vendor | ⚠️ (edit missing) | TBD | Medium | CRUD + event linking (backends routes missing) |
| Discounts | ⚠️ (no edit) | TBD | Small | List, create, edit, delete |
| Tickets | ✅ (full) | TBD | Medium | Global list, per-event list, issue, delete, refund stub |
| Moderation | Stub | TBD | Medium | Post list, review queue, delete, announcements |
| Audit log | Missing | TBD | Small | View action history, filter by action/user |
| Admin users | Missing | TBD | Small | CRUD for admin accounts |
| Posh orders | Missing | TBD | Small | View orders, reconciliation status, manual linking |
| Image catalog | ✅ | TBD | Small | Grid of all images, multi-select, bulk delete |

**P0 for React parity:** Event management, User management, Tickets, Sponsor/Vendor CRUD.

### 3.3 Backend API Gaps

| Endpoint | Status | Issue | Impact |
|----------|--------|-------|--------|
| `POST /users/me/photo` | Missing | Backend route not implemented | Profile photos blocked |
| `PATCH /admin/sponsors/:id` | Missing | Backend route not implemented | Sponsor editing fails |
| `PATCH /admin/vendors/:id` | Missing | Backend route not implemented | Vendor editing fails |
| `DELETE /posts/:id/comments/:commentId` | Missing | Backend route not implemented | Comment deletion unavailable |
| `GET/POST /admin/sponsors/:id/discounts` | Missing | Backend routes not implemented | Discount admin management missing |
| `POST /auth/refresh` | 500 error | JWT errors not caught; returns 500 instead of 401 | Users get "refresh token" error popups |
| `POST /auth/refresh` | Missing validation | No check of tokenFamily === 'social' | Admin tokens can generate social tokens |
| `DELETE /posts/:id/like` → `POST /posts/:id/unlike` | Bug | `unlikePost()` casts void to Map<String, dynamic>, crashes | Unliking posts crashes the app |
| `GET /posts` | SQL injection | userId interpolated instead of parameterized | Low risk (JWT signed) but security smell |
| `DELETE /events/:id` | S3 orphaning | Images deleted from DB but not S3 | Storage waste |

**P0 for release:** Fix token refresh 500→401, fix unlikePost crash, fix SQL injection, add Delete Account UI, add photo upload endpoint.

### 3.4 Schema Migrations Required

Each of these requires a new migration file (002_*.sql and beyond) to be applied before deployment. Grouped by phase. Since the platform is pre-production, schema can be flattened — migration files are still used for traceability but there is no production rollback risk.

**Phase 0 (Immediate — run before any other work):**

| Migration | Table | Change | Rationale |
|-----------|-------|--------|-----------|
| Create platform_config | platform_config | New table: key TEXT PK, value JSONB, description TEXT, updated_by UUID REFS admin_users(id), updated_at TIMESTAMPTZ | Admin-editable platform configuration (non-secrets) |
| Create llm_usage_log | llm_usage_log | New table: id, feature TEXT, model TEXT, input_tokens INT, output_tokens INT, latency_ms INT, success BOOLEAN, error TEXT, created_at TIMESTAMPTZ | LLM call telemetry for cost/perf tracking |
| Update admin_role enum | admin_users | Change admin_role enum: `platformAdmin \| moderator \| eventOps` (add moderator + eventOps, rename venueStaff → eventOps) | venueStaff moved from users table to admin_users; event ops staff are admins |
| Update user_role enum | users | Remove `venueStaff` from user_role enum | venueStaff is now eventOps admin role |
| Add fcm_token | users | Add fcm_token TEXT | FCM push notification device token |
| Add primary_specialty_id | users | Add FK to specialties | Support primary specialty designation |
| Add wristband_issued_at | tickets | Add wristband_issued_at TIMESTAMPTZ | Wristband confirmation flow in Event Ops |

**Phase 1–2 (Social completion + React admin foundation):**

| Migration | Table | Change | Rationale |
|-----------|-------|--------|-----------|
| Create image_assets | image_assets | New table: id, s3_key, s3_bucket, url, file_size INT, width INT, height INT, content_type TEXT, uploaded_by UUID REFS admin_users(id), uploaded_by_user UUID REFS users(id), uploaded_at TIMESTAMPTZ, last_used_at TIMESTAMPTZ, usage_count INT DEFAULT 0, ai_description TEXT, deletion_suggested BOOLEAN DEFAULT FALSE, deletion_reason TEXT, archive_status TEXT DEFAULT 'active' | First-class image asset registry; replaces direct URL storage |
| Migrate event_images | event_images | Add image_asset_id FK to image_assets; retain url as denormalized cache | Transition event images to asset model |
| Add logo_image_asset_id | customers | Add logo_image_asset_id UUID REFS image_assets(id) | Customer logos via asset model |
| Add profile_image_asset_id | users | Add profile_image_asset_id UUID REFS image_assets(id) | User profile photos via asset model |
| Create user_agreements | user_agreements | New table: id, user_id UUID REFS users(id), tos_version TEXT, accepted_at TIMESTAMPTZ, ip_address TEXT, user_agent TEXT | ToS version acceptance tracking |
| Create job_poster_accounts | job_poster_accounts | New table: id, email TEXT UNIQUE, password_hash TEXT, company_name TEXT, contact_name TEXT, status TEXT (pending/probationary/active/suspended), approved_by UUID REFS admin_users(id), approved_at TIMESTAMPTZ, customer_id UUID REFS customers(id) nullable, created_at TIMESTAMPTZ, updated_at TIMESTAMPTZ | Separate account table for job posters |

**Phase 4–5 (LLM moderation + jobs board):**

| Migration | Table | Change | Rationale |
|-----------|-------|--------|-----------|
| Add moderation columns | posts | Add moderation_status TEXT DEFAULT 'pending', is_hidden BOOLEAN DEFAULT FALSE | Post moderation tracking |
| Create moderation_results | moderation_results | New table: id, post_id UUID REFS posts(id), model TEXT, category TEXT, confidence FLOAT, action TEXT, reasoning TEXT, reviewed_by UUID REFS admin_users(id), reviewed_at TIMESTAMPTZ, created_at TIMESTAMPTZ | LLM moderation pipeline output |
| Create jobs table | jobs | New table: id, title TEXT, description TEXT, poster_id UUID REFS job_poster_accounts(id), specialty_ids UUID[], compensation_display TEXT, compensation_min INT, compensation_max INT, duration TEXT, location_display TEXT NOT NULL, location_city TEXT, location_state TEXT, location_country TEXT DEFAULT 'US', remote_ok BOOLEAN DEFAULT FALSE, status TEXT (draft/open/closed/filled), moderation_status TEXT DEFAULT 'pending', created_at TIMESTAMPTZ, updated_at TIMESTAMPTZ | Jobs board feature |
| Create job_applications | job_applications | New table: id, job_id UUID REFS jobs(id), applicant_id UUID REFS users(id), status TEXT (pending/reviewed/accepted/rejected), message TEXT, created_at TIMESTAMPTZ | Track job applications |
| Create hire_confirmations | hire_confirmations | New table: id, job_id UUID REFS jobs(id), worker_id UUID REFS users(id), poster_id UUID REFS job_poster_accounts(id), initiated_by TEXT (worker/poster), worker_confirmed_at TIMESTAMPTZ, poster_confirmed_at TIMESTAMPTZ, status TEXT (pending/confirmed/rejected), created_at TIMESTAMPTZ | Bidirectional hire confirmation |
| Create job_post_images | job_post_images | New table: job_id UUID REFS jobs(id), image_asset_id UUID REFS image_assets(id), sort_order INT | Job post image references |

**Phase 6 (Professional ratings):**

| Migration | Table | Change | Rationale |
|-----------|-------|--------|-----------|
| Create professional_ratings | professional_ratings | New table: id, hire_confirmation_id UUID REFS hire_confirmations(id), worker_id UUID REFS users(id), poster_id UUID REFS job_poster_accounts(id), quality_score INT (1-5), professionalism_score INT (1-5), communication_score INT (1-5), would_hire_again BOOLEAN, review_text TEXT, moderation_status TEXT DEFAULT 'pending', is_hidden BOOLEAN DEFAULT FALSE, created_at TIMESTAMPTZ | Employer-verified worker ratings |

**Phase 7 (Analytics):**

| Migration | Table | Change | Rationale |
|-----------|-------|--------|-----------|
| Create event_wrap_reports | event_wrap_reports | New table: id, event_id UUID REFS events(id) UNIQUE, generated_at TIMESTAMPTZ, reviewed_by UUID REFS admin_users(id), reviewed_at TIMESTAMPTZ, content JSONB, status TEXT (generating/draft/approved/distributed), distributed_at TIMESTAMPTZ | Auto-generated event summaries |

---

## 4. Implementation Plan — Phased

The plan is divided into phases designed to be executed sequentially but with some parallelization. Each phase is sized for 1-3 weeks of engineering effort.

### Phase 0: Immediate Fixes + Schema Foundation (1-2 weeks) — **START HERE**

**Mandatory before any other work.** Critical bugs, compliance issues, and foundational schema changes that everything else depends on.

**Bug fixes and compliance:**

| Item | Effort | Details |
|------|--------|---------|
| Delete Account button | Small | Add button to Settings, wire to AppState.deleteAccount(), handle confirmation dialog |
| Token refresh 500→401 | Small | Wrap JWT errors in try/catch, throw UnauthorizedError('Invalid or expired refresh token') in auth.ts + admin-auth.ts |
| PostsApi.unlikePost() crash | Small | Either change ApiClient.delete() to return response body, or change unlikePost() to return void |
| SQL injection in posts.ts | Small | Replace `userId` interpolation with parameterized query ($1, $2, etc.) |
| Post author data shape | Small | Add authorName, authorPhoto fields to Post model, update JSON deserialization |
| Comment delete endpoint | Small | Implement DELETE /posts/:id/comments/:commentId in posts.ts |

**Schema foundation (run migrations before deploying):**

| Item | Effort | Details |
|------|--------|---------|
| admin_role enum expansion | Small | Add `moderator` and `eventOps` values; this enables the React admin RBAC from day one |
| user_role venueStaff removal | Small | Remove venueStaff from user_role enum (migrated to eventOps admin role) |
| platform_config table | Small | Key/value store for admin-editable config (LLM model versions, thresholds, feature flags) |
| llm_usage_log table | Small | Per-call LLM telemetry (model, feature, tokens, latency, success) |
| users.fcm_token column | Small | FCM device token for push notifications (nullable at first) |
| users.primary_specialty_id FK | Small | Primary specialty designation |
| tickets.wristband_issued_at column | Small | Timestamp for Event Ops wristband confirmation flow |

**Deliverable:** Critical bugs fixed; Delete Account available for App Store submission; SQL injection remediated; schema foundation ready for all subsequent phases.

### Phase 1: Social App Completion (2-3 weeks)

**Wire up existing stubbed features.** Backend routes exist; these screens just need API calls.

| Item | Effort | Details |
|------|--------|---------|
| Community feed wiring | Medium | Load posts from API, infinite scroll, pull-to-refresh, verification gate, post type filtering (general/collab/job), empty state |
| Create post wiring | Small | Wire to PostsApi.createPost(), handle image selection (defer image upload to Phase 2) |
| Post detail wiring | Medium | Load post + comments from API, add comment form, like/unlike with optimistic updates, relative timestamps |
| Search wiring | Medium | Debounced UsersApi.searchUsers(), specialty filter chips, empty state, pagination |
| User profile wiring | Small | Load from UsersApi.getUser(), display specialty badge, connection count, event count, visit profile button |
| Primary specialty display | Small | Update User model, profile screens to show primary first |
| Profile photo upload | Medium | Wire photo picker, upload to POST /users/me/photo, update profile display |
| Verification status display | Small | Show "Verified" badge on user profiles where applicable |
| Event filtering by market area | Small | Add market_area to events list filter, defaults to user's market_area from profile |

**Deliverable:** Community board fully functional; user search working; all retention features operational; compliance items resolved.

### Phase 2: React Admin Foundation + ToS/Privacy (3-4 weeks) — **Parallel with Phase 1**

**Build the skeleton of the React admin app, RBAC, push notification infrastructure, and ToS framework.** Design tokens, component library, auth, dashboard. This runs parallel to social app work.

| Item | Effort | Details |
|------|--------|---------|
| Project scaffold | Small | Next.js 14+ with App Router, TypeScript, Tailwind, shadcn/ui, Framer Motion for transitions |
| Design system setup | Small | Color tokens (dark-first, #121212 base), spacing grid (4px), typography (display font TBD + Inter), CSS variables |
| Component library | Medium | Button, Badge, Card, Avatar, Input, Textarea, Select, DatePicker, DataTable, SideDrawer, Modal, Toast, SkeletonLoader, EmptyState, SidebarNav |
| App shell | Medium | Role-gated sidebar (platformAdmin sees all; moderator sees Users + Moderation; eventOps sees Event Ops only), top bar (user menu), responsive mobile layout for eventOps |
| Auth screen | Small | Email/password form, error display, remember me, token persistence, role-based redirect after login |
| permissions.ts | Small | Define permissions map; create `hasPermission(role, permission)` helper; role-guard components |
| Dashboard screen | Small | Stats cards (users, events, connections, posts), recent activity list |
| Event Ops screen | Medium | SSE-driven real-time check-in stream, wristband confirmation flow, QR tablet mode, Posh order exception queue |
| API client setup | Small | Fetch wrapper with token injection, error handling, request/response logging |
| FCM push notification setup | Medium | Firebase project setup, flutter_messaging package, backend FCM sender, wristband push trigger |
| Local dev scripts | Small | `run-react-admin.sh` (port 3630, .env.local bootstrap, --env flag), `debug-react-admin.sh` (NODE_OPTIONS='--inspect') |
| ToS acceptance modal | Small | user_agreements table, modal shown on first login after new ToS version, version tracking |
| Platform config admin screen | Small | Admin settings section for reading/editing platform_config; API key status display (never show values); Test Connection buttons |

**Deliverable:** React admin deployed and role-gated; eventOps check-in workflow operational; wristband push notifications working; ToS acceptance framework live; platform config manageable without code changes.

### Phase 3: React Admin Parity (4-6 weeks) — **After Phase 2 foundation**

**Implement all screens to achieve feature parity with Flutter admin.** This is the critical path for admin migration.

| Item | Effort | Details |
|------|--------|---------|
| User management | Large | Users list (search, filter by role/status), user detail (profile, tickets, actions), add user form |
| Event management | Large | Events list (status filters, image count, partner count), event detail (full form, image upload + hero, partner management, publish gate, status transitions), image catalog |
| Sponsor/vendor management | Medium | Sponsors/vendors list (CRUD forms), discount management (list, create, edit, delete), event linking |
| Tickets | Medium | Global tickets list, per-event list, issue/delete/refund dialogs |
| Moderation (wired) | Medium | Posts list, review queue UI, delete/approve dialogs, announcements create/manage (no LLM integration yet, just backend wiring) |
| Audit log viewer | Small | List action history, filter by action/user/date, pagination |
| Admin users management | Small | CRUD for admin accounts, role assignment |
| Posh orders visibility | Small | Orders list with reconciliation status, manual linking UI |

**Deliverable:** React admin achieves feature parity with Flutter; all critical workflows operational; big-bang migration can proceed.

### Phase 4: LLM Moderation Pipeline (2-3 weeks) — **After Phase 1 + Phase 2 complete**

**Implement asynchronous post moderation.** Posts auto-submit then run through pipeline.

| Item | Effort | Details |
|------|--------|---------|
| Backend moderation service | Small | Async job processor (Bull queue or AWS SQS), Haiku → Sonnet routing, database writes of moderation_results |
| Two-stage pipeline | Medium | Stage 1 (Haiku): fast violation detection, high-confidence auto-approve/reject. Stage 2 (Sonnet): ambiguous cases, lower-confidence threshold, flag for human review |
| Admin review queue UI | Medium | React admin moderation screen shows flagged posts, review/approve/reject with confidence scores |
| Metrics dashboard | Small | Breakdown by category (hate speech, NSFW, spam, etc.), false positive tracking, response time SLA monitoring |
| Community board integration | Small | Update wiring to show is_hidden status, mark moderation_pending posts with visual indicator |

**Deliverable:** All posts auto-moderated; false positives tracked; admin queue functional; community safety established.

### Phase 5: Jobs Board (3-4 weeks) — **After Phase 1 complete**

**Implement full jobs feature.** New data model, backend, social UI, admin management.

| Item | Effort | Details |
|------|--------|---------|
| Schema + migrations | Small | jobs, job_applications, hire_confirmations tables |
| Backend API | Medium | Job CRUD (admin + verified employers), search/filter endpoints, application creation/status endpoints |
| Social app Jobs tab | Large | Jobs list (search by specialty, filter by remote/rate), job detail, apply button, applications list (for job posters) |
| Admin jobs management | Medium | Jobs list, detail, create/edit/delete, application review queue |
| Hire confirmation flow | Medium | Both parties can initiate, notification system, confirmation dialog, status tracking |

**Deliverable:** Full jobs marketplace operational; hire confirmation pipeline working; data flows to ratings system.

### Phase 6: Professional Ratings (2-3 weeks) — **After Phase 5 complete**

**Implement verified employer ratings.** Locked behind hire confirmation.

| Item | Effort | Details |
|------|--------|---------|
| Schema + migrations | Small | professional_ratings table |
| Backend API | Small | Ratings CRUD (post-hire only), visibility rules (public on profiles), moderation pipeline integration |
| Social app display | Medium | Ratings on user profiles, average rating badge, detailed breakdown, employer name/logo on each rating |
| Moderation wiring | Small | Ratings run through LLM pipeline same as posts; IN staff can reject ToS-violating ratings |
| Admin management | Small | Ratings list, detail, delete if ToS violation |

**Deliverable:** Verified track records established; trust signals visible; revenue data product enabled.

### Phase 7: Analytics & Data Products (4-5 weeks) — **After Phase 1 + others stabilized**

**Populate analytics tables; build influence metric; implement event wrap reports.**

| Item | Effort | Details |
|------|--------|---------|
| Analytics data pipeline | Medium | Nightly jobs to populate analytics_connections_daily, analytics_users_daily, analytics_events, analytics_influence |
| Influence metric algorithm | Medium | PageRank variant weighted by attendance, connections, post engagement. Nightly batch compute. |
| Analytics dashboard (React admin) | Medium | Influence scores, trending users, event performance, connection patterns, engagement trends |
| Event wrap report generator | Large | Scheduled job (runs 24h post-event), LLM drafting of report from platform data, review queue in admin, AI-assisted editing UI, distribution to customers with data product |
| Data product UI | Small | Display/download reports, filter by event, export options |

**Deliverable:** Full analytics visibility; event wrap reports automated; influence metric powers search ranking and data products.

### Phase 8: Infrastructure Hardening (2-3 weeks) — **Can run in parallel with other phases**

**Rate limiting, testing, optimization.**

| Item | Effort | Details |
|------|--------|---------|
| Rate limiting | Medium | Token bucket on auth endpoints (SMS request, verify code), API endpoint rate limits, webhook rate limits |
| API test suite | Large | Auth flow tests (request → verify → refresh → logout), cascade delete tests, event publish gate tests, Posh webhook tests, moderation pipeline tests |
| S3 orphan cleanup | Small | S3 deletes now handled via image_assets cascade; backfill script to clean pre-migration orphans |
| Health check DB connectivity | Small | GET /health now queries DB; returns 500 if DB unreachable |
| CI/CD integration | Small | Wire migrate.js into api.yml as pre-deploy K8s Job; add post-deploy smoke tests |
| Flutter test suite | Large | Admin app + social app widget tests; priority: login form, event form, connection flow state |

**Deliverable:** Platform hardened against abuse; test coverage adequate for production; deployments safer.

### Phase 9: Export My Data / GDPR (Post-MVP — Very Late Phase)

**Implement "Export My Data" for GDPR/CCPA compliance.** This is explicitly NOT a prerequisite for Delete Account (which is Phase 0) or App Store submission. Ship well after public launch when user volume makes compliance necessary.

| Item | Effort | Details |
|------|--------|---------|
| Data export request endpoint | Small | POST /users/me/export → creates data_export_requests record, triggers async job |
| Export job | Medium | Collects all user data (profile, connections, posts, tickets, ratings), packages as JSON/CSV archive |
| S3 delivery | Small | Uploads to private S3 URL, emails download link to user (expires 48h) |
| Admin export management | Small | Admin can view export requests, status, trigger manual export |

**Deliverable:** Users can request full data export; GDPR/CCPA Article 20 (data portability) satisfied. Schedule legal review of export format completeness.

*Note: The `data_export_requests` table already exists in the schema (migration 001). The backend job and delivery mechanism are the remaining work.*

---

## 5. React Admin App — Architecture Spec

### 5.1 Technology Stack

- **Framework:** Next.js 14+ (App Router)
- **UI Library:** shadcn/ui components (built on Radix UI + Tailwind CSS)
- **Styling:** Tailwind CSS with custom design tokens (dark-first)
- **State Management:** React Query (server state) + Zustand (client state) or Context API
- **Animation:** Framer Motion for transitions, drawer slide-ins, toast animations
- **Deployment:** Docker container → ECR → EKS (same pattern as API)
- **Build:** Vercel's Next.js toolchain; SWC for transpilation
- **TypeScript:** Strict mode; generated types from API schema (openapi-typescript)

### 5.2 Design System

**Color Palette (Dark-First):**
- Background: #121212
- Foreground: #FFFFFF
- Primary: #7C3AED (purple)
- Primary Light: #A855F7
- Accent: #FF3D8E (energy/notifications)
- Secondary: #1B9CFC (links/info)
- Verification: #F1C40F (gold)
- Success: #10B981
- Warning: #F59E0B
- Destructive: #EF4444

**Spacing Grid:** 4px base unit (4, 8, 12, 16, 24, 32, 48, 64px)

**Typography:**
- Display: Clash Display or Satoshi (TBD; see docs/design/)
- Body: Inter (400, 500, 600, 700 weights)

**Component Patterns:**
- Sidebar navigation (icon + label, section grouping)
- Data tables with inline actions
- Side drawers for CRUD forms (not modal overlays)
- Toast notifications for feedback
- Skeleton loaders during data fetch

### 5.3 Navigation Structure

Navigation is role-gated. Each section shows only for roles that have permission.

```
Sidebar Navigation (role visibility noted):
├── Dashboard [all roles]
│   └── Stats overview, recent activity
├── Event Ops [eventOps, platformAdmin] ← Mobile-optimized section
│   ├── Live Check-in Feed (SSE real-time stream)
│   ├── Wristband Confirmation (tap to confirm)
│   ├── QR Tablet Mode (full-screen check-in QR)
│   └── Posh Order Exceptions (unlinked orders queue)
├── Users [moderator, platformAdmin]
│   ├── Social Users (list, search, filter, detail, ban, verify)
│   ├── Admin Users (CRUD — platformAdmin only)
│   └── Job Poster Accounts (list, approve, suspend)
├── Events [eventOps, platformAdmin]
│   ├── Event List (status, image count, partner count)
│   ├── Create Event
│   ├── Event Detail (images + partners inline)
│   └── Image Catalog
├── Customers [platformAdmin]
│   ├── List (filter by product type)
│   ├── Add Customer
│   ├── Customer Detail (products, discounts, stats)
│   ├── Products (catalog)
│   └── Discounts (per-customer)
├── Jobs Board [moderator, platformAdmin]
│   ├── Job Listings (review, approve, manage)
│   └── Hire Confirmations
├── Moderation [moderator, platformAdmin]
│   ├── Posts Review Queue (LLM confidence scores, flag/approve/reject)
│   ├── Ratings Review Queue
│   └── Announcements (create + manage)
├── Posh Orders [eventOps, platformAdmin]
│   ├── All Orders (reconciliation status)
│   └── Exception Queue (unlinked orders)
├── Analytics [platformAdmin]
│   ├── Overview Dashboard
│   ├── Influence Scores (leaderboard)
│   ├── Event Reports (wrap reports)
│   └── Data Products
└── Settings [platformAdmin]
    ├── Audit Log (view history)
    ├── Platform Config (LLM settings, feature flags)
    └── API Key Status (service connectivity, Test Connection)

Top Bar:
├── Search (global user/event/order search — Phase 2+)
├── Notifications (placeholder)
└── User Menu (logout, role display)
```

### 5.4 Component Inventory

**Layout Components:**
- Sidebar (collapsible, icon-only mode on mobile)
- TopBar (user menu, notifications)
- MainContent (scrollable area)
- Modal, Drawer, Sheet (for forms)

**Data Components:**
- DataTable (sortable, filterable, pagination)
- DataGrid (for image gallery)
- Card (stats, summary)
- Badge (status, type, category)

**Form Components:**
- Input (text, number, email, password)
- Textarea
- Select (dropdown, multi-select)
- Checkbox, Radio
- DatePicker (date + time)
- FileUpload (images, documents)

**Feedback Components:**
- Toast (success, error, info, warning)
- Alert (inline warnings/info)
- Skeleton (loading placeholders)
- EmptyState (no results, no data)
- ErrorBoundary

**Feature Components:**
- UserTable (with actions: ban, verify, role change)
- EventForm (create/edit with image upload, partner management)
- ImageUploadZone (drag-drop, preview, delete)
- SponsorForm, VendorForm, DiscountForm
- PostsModerationQueue (with approve/reject + confidence display)

### 5.5 RBAC Architecture

Industry Night uses **separate account tables as the RBAC mechanism** — not a full ACL system. Three distinct user types authenticate differently, have their own JWT token families, and access separate sections of the platform. At current scale, this is cleaner and more maintainable than a flexible permission graph.

| Account Type | Table | Auth Method | Token Family | Portal |
|---|---|---|---|---|
| Social users | `users` | Phone + SMS OTP | `social` | Flutter social app |
| Admin/ops staff | `admin_users` | Email + password | `admin` | React admin app |
| Job poster employers | `job_poster_accounts` | Email + password | `jobPoster` | Separate React job poster portal |

**Admin roles (`admin_role` enum):**
- `platformAdmin` — full access to all sections
- `moderator` — Users (read) + Moderation (write)
- `eventOps` — Event Ops screen + Events (read/write) + Posh Orders

**Job poster account lifecycle:** `pending → probationary → active → suspended`
- `pending`: applied, awaiting admin review
- `probationary`: approved, can post but posts require manual moderation review; admin dashboard shows probationary job metrics
- `active`: trusted poster, standard moderation pipeline
- `suspended`: access revoked pending investigation

**Job poster ↔ Customer relationship:** A job poster is optionally a customer with a "job posting subscription" product. Customer record is created first in the CRM; `job_poster_accounts.customer_id` FK links them. Auto-provisioned when admin assigns the job posting subscription product to a customer.

**Permissions pattern (`packages/react-admin/lib/permissions.ts`):** See §2.13 for the full permissions map. Route guards in React admin wrap each section with `<RequirePermission permission="admin:events:write">`.

### 5.6 Push Notifications Architecture

**Service:** Firebase Cloud Messaging (FCM) for iOS and Android. Flutter `firebase_messaging` package.

**Token lifecycle:**
1. On social app launch, `firebase_messaging.getToken()` is called
2. Token stored in `users.fcm_token` via `PATCH /users/me` (or dedicated endpoint)
3. On `onTokenRefresh`, update stored token
4. On logout, token is kept (device may still receive notifications); on account delete, token cleared

**Backend notification service (`packages/api/services/push.ts`):**
- `sendPush(userId, title, body, data)` — looks up `fcm_token` from DB, calls FCM REST API
- Gracefully degrades if FCM not configured (console.log in dev mode)
- Wraps in try/catch; push failures are non-fatal (never block main flow)

**First use case — Wristband confirmation:**
```
Event Ops staff taps "Mark wristband issued" on attendee card
  → API: PATCH /admin/events/:eventId/tickets/:ticketId/wristband
  → Sets tickets.wristband_issued_at = NOW()
  → Calls push.sendPush(userId, "🎉 You're in!", "Welcome to Industry Night", { type: 'wristband', eventId })
  → Social app receives push → deep-links to event's Who's Here tab
```

**Additive, not gating:** If push fails (no token, FCM error, device offline), the wristband is still marked as issued. Notification delivery is best-effort.

**Future push use cases (Phase 5+):** new connection notification, job application status update, hire confirmation request, moderation decision.

### 5.7 Event Ops Screen Design

The Event Ops screen is a mobile-optimized section of the React admin app, accessible to `eventOps` and `platformAdmin` roles. Designed to be usable on a phone or tablet at the venue.

**Real-time check-in stream (SSE):**
- `GET /admin/events/:id/checkins/stream` — SSE endpoint, sends events on each check-in
- React admin subscribes via `EventSource` on screen mount
- Displays running tally: "12 checked in / 9 wristbands confirmed" with live delta
- Each new check-in animates into the list with name + photo

**Wristband confirmation flow:**
1. Attendee card shows: [Photo] [Name] [Specialty] [Checked in 3m ago] [Wristband: ⏳ Pending]
2. Staff taps card → "Mark wristband issued" button → confirmation tap
3. API call → `wristband_issued_at` timestamped → FCM push triggered
4. Card updates: [Wristband: ✅ Issued at 8:47pm]
5. Summary updates: "9 → 10 wristbands confirmed"

**QR Tablet Check-in Mode:**
- Full-screen mode for a tablet placed at venue entrance
- Displays dynamic QR code encoding the event activation code
- Attendee scans with their phone → social app auto-checks in
- 4-digit code shown below QR as fallback (manual entry option)
- Refreshes activation code display automatically

**Posh Orders Exception Queue:**
- Side panel showing unlinked Posh orders for the current event
- Each shows buyer name, phone, ticket type, purchase time
- "Match to User" action → search by phone → confirm link

### 5.8 Image Assets Architecture

First-class `image_assets` table replaces direct S3 URL storage on entity tables. All image uploads go through this system.

**Upload flow:**
```
Admin/user selects file
  → POST /admin/images or POST /users/me/photo (multipart)
  → Server: sharp resize + compress, upload to S3
  → Server: create image_assets record (s3_key, url, size, dimensions)
  → Server: optionally trigger AI description job (async, low priority)
  → Response: { assetId, url }
  → Caller stores assetId on entity (event, customer, user, job)
```

**Entity FK pattern:**
- `event_images.image_asset_id` → `image_assets.id`
- `customers.logo_image_asset_id` → `image_assets.id`
- `users.profile_image_asset_id` → `image_assets.id`
- `job_post_images.image_asset_id` → `image_assets.id`

**Community photo reuse:** When creating an event or sponsor page, admin can open a "From Community" image picker that shows photos uploaded by social users. Each image shows "Uploaded by @username at Event Name". Usage is covered by ToS. Original poster name is logged in `image_assets.uploaded_by_user`.

**LLM cleanup job (weekly cron):**
1. Query images where `usage_count = 0` AND `last_used_at < NOW() - 30 days`
2. Run near-duplicate detection (perceptual hash comparison within same event/customer group)
3. Call LLM (Haiku) to score each image: clarity, composition, relevance to creative industry
4. Set `deletion_suggested = true` and `deletion_reason` on candidates
5. Admin image catalog shows "Suggested for cleanup" section with AI reasoning

**Archive vs. Delete distinction:**
- **Archive:** Sets `archive_status = 'archived'`, hides from pickers, keeps S3 object. Reversible.
- **Delete:** Removes `image_assets` record + deletes S3 object. Irreversible (with confirmation modal).

### 5.9 API Key & Secrets Management

**Principle:** Secrets (API keys, database passwords, JWT secrets) live exclusively in AWS Secrets Manager and are injected as Kubernetes environment variables. The admin app NEVER shows, stores, or transmits secret values.

**Admin Settings — API Integrations panel shows:**
| Service | Status | Last Tested | Action |
|---|---|---|---|
| Twilio (SMS) | ✅ Connected | 2h ago | Test Connection |
| AWS SES (Email) | ✅ Connected | 1d ago | Test Connection |
| Posh Webhooks | ✅ Receiving | 3m ago | — |
| OpenAI / Anthropic | ✅ Connected | 5m ago | Test Connection |
| Firebase (FCM) | ✅ Connected | 1h ago | Test Connection |
| S3 | ✅ Connected | — | — |

- **"Test Connection"** calls a backend endpoint that makes a minimal test call to the service and returns success/error. No keys exposed.
- **"Configure"** links to the AWS Console Secrets Manager page for rotation. Opens in new tab.
- Configuration for non-secret values (LLM model versions, confidence thresholds, feature flags) is stored in `platform_config` and editable in the admin UI.

### 5.10 Local Development Scripts

Following the existing `run-api.sh` pattern:

**`scripts/run-react-admin.sh`**
- Port: **3630** (project-specific convention; Jeff's street address — memorable)
- Creates `.env.local` from `.env.local.template` if not present
- Runs `npm run dev` in `packages/react-admin/`
- Accepts `--env dev|prod` flag to set `NEXT_PUBLIC_API_URL`
- Dev points to `http://localhost:3000` (local API); prod points to `api.industrynight.net`

**`scripts/debug-react-admin.sh`**
- Same as above but sets `NODE_OPTIONS='--inspect'` for Node.js debugger attachment
- Prints debugger URL to console

### 5.11 Event Check-in Comparables (Reference List)

After MVP launch (target: early May 2026), conduct a formal comparison of Industry Night's check-in + networking experience against these platforms:

| Platform | Known For |
|---|---|
| **Zkipster** | Guest list + check-in for upscale events |
| **Splash** | Event marketing + RSVP + check-in |
| **Boomset** | Badge printing + QR check-in |
| **Eventbrite Organizer** | Mass market check-in, phone scanning |
| **DICE.fm** | Music/entertainment ticketing with anti-tout features |
| **Posh** | College party ticketing (our ticket partner) |

Evaluation criteria: check-in speed, connection/networking features, data visibility for organizers, attendee app experience, offline resilience.

### 5.12 API Integration Strategy

**Request Layer:**
- Centralized fetch wrapper (`lib/api/client.ts`)
- Auto-inject Authorization header with JWT
- Error mapping (401 → logout, 403 → forbidden, etc.)
- Request/response logging in dev mode

**Data Fetching:**
- React Query for server state (caching, invalidation, background refetch)
- Zustand stores for client state (selected filters, UI preferences)
- Example: `useQuery(['users', page, filters], () => adminApi.listUsers(...), { staleTime: 5min })`

**Error Handling:**
- Global error boundary shows toast + logs to Sentry (optional)
- Form submission errors shown inline
- Network timeouts trigger retry with exponential backoff

### 5.13 Auth & Session

**Flow:**
1. User enters email + password on login screen
2. API returns `accessToken` + `refreshToken`
3. Both stored in secure HttpOnly cookie (or localStorage if no cookie support)
4. Every request includes Authorization: Bearer {accessToken}
5. On 401, automatically refresh token and retry
6. On refresh token expired, redirect to login
7. Post-login, role-based redirect: eventOps → `/event-ops`; moderator → `/moderation`; platformAdmin → `/`

**Token Refresh:**
- Implement `useAuthRefresh` hook that monitors token expiry
- Proactively refresh 5 minutes before expiry
- Or reactively refresh on 401 response

---

## 6. Backend API Additions Required

The following endpoints must be implemented to support new features. Each is characterized by request/response shape and authorization requirements.

### 6.1 Primary Specialty & Influence

| Endpoint | Method | Purpose | Auth | Notes |
|----------|--------|---------|------|-------|
| `PATCH /users/me` | PATCH | Update primary_specialty_id | Social | Already exists; add field |
| `GET /users/:id/influence` | GET | Get user's influence score | Social | Read-only; populated nightly |

### 6.2 Community Board (Existing, Wire Up)

| Endpoint | Method | Purpose | Auth | Notes |
|----------|--------|---------|------|-------|
| `GET /posts` | GET | List feed with pagination | Social | Add moderation_status filtering (approved only for social) |
| `GET /posts/:id` | GET | Post detail with comments | Social | Already exists |
| `POST /posts` | POST | Create post | Social (verified) | Posts created with is_hidden=false, moderation_status=pending |
| `PATCH /posts/:id` | PATCH | Edit post | Social | Author-only |
| `DELETE /posts/:id` | DELETE | Delete post | Social | Author or admin |
| `POST /posts/:id/like` | POST | Like post | Social (verified) | Idempotent |
| `DELETE /posts/:id/like` | DELETE | Unlike post | Social (verified) | Already exists (bug: bad response shape) |
| `GET /posts/:id/comments` | GET | Get comments | Public | Already exists |
| `POST /posts/:id/comments` | POST | Add comment | Social (verified) | Comments created visible immediately |
| `DELETE /posts/:id/comments/:commentId` | DELETE | Delete comment | Social | Author or admin (MISSING ENDPOINT) |

### 6.3 Jobs Board (New)

| Endpoint | Method | Purpose | Auth | Notes |
|----------|--------|---------|------|-------|
| `GET /jobs` | GET | List jobs with filters | Social | Filter: specialty, remote, rate range, location |
| `GET /jobs/:id` | GET | Job detail | Social | Show applicants if job poster |
| `POST /jobs` | POST | Create job | Social (verified employer) | Requires verified account flag |
| `PATCH /jobs/:id` | PATCH | Edit job | Social (verified employer) | Job poster only |
| `DELETE /jobs/:id` | DELETE | Delete job | Social (verified employer) | Job poster only |
| `POST /jobs/:id/apply` | POST | Apply for job | Social (verified) | Creates job_application record |
| `DELETE /jobs/:id/applications/:appId` | DELETE | Withdraw application | Social | Applicant only |
| `GET /jobs/:id/applications` | GET | List job applications | Social | Job poster only |

### 6.4 Hire Confirmation & Professional Ratings (New)

| Endpoint | Method | Purpose | Auth | Notes |
|----------|--------|---------|------|-------|
| `POST /hire-confirmations` | POST | Initiate hire confirmation | Social (verified) | Either job poster or worker can start |
| `PATCH /hire-confirmations/:id` | PATCH | Confirm/reject hire | Social | Reciprocal party confirmation |
| `GET /hire-confirmations` | GET | List my hire confirmations | Social | Filter by status (pending, confirmed, rejected) |
| `POST /ratings` | POST | Submit rating | Social (verified) | Post-hire only (check hire_confirmations) |
| `GET /ratings` | GET | List ratings for user | Social | Public endpoint; shows on profile |
| `PATCH /ratings/:id` | PATCH | Edit rating | Social | Author only |
| `DELETE /ratings/:id` | DELETE | Delete rating | Social | Author or admin (ToS violation) |

### 6.5 Moderation Pipeline (New Backend Service)

| Component | Purpose | Details |
|-----------|---------|---------|
| **Moderation Queue** | Async job processor | Bull queue or AWS SQS. Jobs: {postId, content, author, timestamp} |
| **Haiku Classifier** | Fast first-pass | Invoke Claude Haiku on post content; returns {category, confidence, action} |
| **Sonnet Classifier** | Detailed review | For ambiguous cases (0.4 < confidence < 0.7); returns {category, confidence, reasoning} |
| **Results Writer** | Persist decisions | Write to moderation_results table (post_id, model, category, confidence, action, created_at) |
| **Post Hydrator** | Update post status | Set posts.moderation_status, is_hidden based on decision; is_hidden=true if rejected |

**LLM Classifier Output Schema:**
```json
{
  "category": "hate_speech" | "nsfw" | "spam" | "harassment" | "safe",
  "confidence": 0.0-1.0,
  "action": "auto_approve" | "auto_reject" | "flag_for_review",
  "reasoning": "Optional explanation for flagged content"
}
```

### 6.6 Event Wrap Report (New)

| Endpoint | Method | Purpose | Auth | Notes |
|----------|--------|---------|------|-------|
| `GET /admin/events/:id/report` | GET | Get generated wrap report | Admin | May be pending LLM generation |
| `PATCH /admin/events/:id/report` | PATCH | Edit report + lock for distribution | Admin | Allows AI-assisted editing before sending |
| `POST /admin/events/:id/report/generate` | POST | Force report generation | Admin | Async; returns job ID |
| `POST /admin/events/:id/report/distribute` | POST | Send to customers with data product | Admin | Email + archive |

### 6.7 Admin Users (New)

| Endpoint | Method | Purpose | Auth | Notes |
|----------|--------|---------|------|-------|
| `GET /admin/admin-users` | GET | List admin accounts | Admin (platformAdmin) | Filter: role, active/inactive |
| `POST /admin/admin-users` | POST | Create admin | Admin (platformAdmin) | Email, name, role, initial password (send reset link) |
| `PATCH /admin/admin-users/:id` | PATCH | Edit admin | Admin (platformAdmin) | Role change, deactivate |
| `DELETE /admin/admin-users/:id` | DELETE | Delete admin | Admin (platformAdmin) | Soft delete (archive); don't cascade |

### 6.8a Job Poster Accounts (New)

| Endpoint | Method | Purpose | Auth | Notes |
|----------|--------|---------|------|-------|
| `POST /job-poster/auth/register` | POST | Job poster applies | Public | Creates pending account; triggers admin review |
| `POST /job-poster/auth/login` | POST | Job poster login | Public | Returns JWT with tokenFamily: 'jobPoster' |
| `POST /job-poster/auth/refresh` | POST | Refresh token | Public | |
| `GET /admin/job-poster-accounts` | GET | List job poster accounts | Admin | Filter: status |
| `PATCH /admin/job-poster-accounts/:id` | PATCH | Approve/suspend/activate | Admin (platformAdmin) | Status lifecycle |
| `GET /admin/job-poster-accounts/:id` | GET | Detail + job metrics | Admin | Show probationary metrics |

### 6.8b Image Assets (New)

| Endpoint | Method | Purpose | Auth | Notes |
|----------|--------|---------|------|-------|
| `POST /admin/image-assets` | POST | Upload image, create asset record | Admin | Multipart; returns assetId + url |
| `GET /admin/image-assets` | GET | Browse asset catalog with filters | Admin | Filter: unused, suggested_for_deletion, event_id |
| `GET /admin/image-assets/cleanup-suggestions` | GET | LLM-suggested deletes with reasons | Admin | Returns grouped suggestions |
| `PATCH /admin/image-assets/:id/archive` | PATCH | Archive image (soft-delete) | Admin | Sets archive_status = 'archived' |
| `DELETE /admin/image-assets/:id` | DELETE | Permanently delete (S3 + DB) | Admin | Requires confirmation; irreversible |
| `POST /users/me/photo` | POST | Upload social user profile photo | Social | Creates image_asset, links to user |

### 6.8c Platform Config & API Keys (New)

| Endpoint | Method | Purpose | Auth | Notes |
|----------|--------|---------|------|-------|
| `GET /admin/config` | GET | List all config keys | Admin (platformAdmin) | Returns {key, value, description, updated_by, updated_at} |
| `PATCH /admin/config/:key` | PATCH | Update config value | Admin (platformAdmin) | Body: {value} |
| `GET /admin/config/api-status` | GET | Check API service connectivity | Admin | Tests Twilio, SES, FCM, LLM, S3 |
| `POST /admin/config/api-status/:service/test` | POST | Test specific service connection | Admin | Returns {success, latency, error} |

### 6.8d Event Ops & Wristband (New)

| Endpoint | Method | Purpose | Auth | Notes |
|----------|--------|---------|------|-------|
| `GET /admin/events/:id/checkins/stream` | GET | SSE stream of real-time check-ins | Admin (eventOps+) | Content-Type: text/event-stream |
| `GET /admin/events/:id/checkins` | GET | Check-in list with wristband status | Admin (eventOps+) | Summary: checked_in count, wristband_issued count |
| `PATCH /admin/events/:id/tickets/:ticketId/wristband` | PATCH | Mark wristband issued | Admin (eventOps+) | Sets wristband_issued_at; triggers FCM push |

### 6.8e Push Notifications (New)

| Endpoint | Method | Purpose | Auth | Notes |
|----------|--------|---------|------|-------|
| `PATCH /users/me` | PATCH | Update FCM token | Social | Already exists; add fcm_token field |

Backend service `packages/api/services/push.ts`:
- `sendPush(userId, title, body, data)` — queries `users.fcm_token`, calls FCM REST API
- Graceful degradation when FCM not configured
- Never throws (push failures logged but non-fatal)

### 6.9 Posh Orders Visibility (New)

| Endpoint | Method | Purpose | Auth | Notes |
|----------|--------|---------|------|-------|
| `GET /admin/posh-orders` | GET | List posh orders | Admin | Filter: reconciliation status (linked, unlinked, needs attention) |
| `GET /admin/posh-orders/:id` | GET | Order detail | Admin | Show linked user + ticket info |
| `PATCH /admin/posh-orders/:id/link` | PATCH | Manually link order to user | Admin | Match phone, create ticket |

### 6.9 Analytics (New)

| Endpoint | Method | Purpose | Auth | Notes |
|----------|--------|---------|------|-------|
| `GET /admin/analytics/influence-scores` | GET | Paginated influence leaderboard | Admin | Sorted descending; show top 100 |
| `GET /admin/analytics/events/:id` | GET | Event-level stats | Admin | Attendance, connections, engagement, specialty breakdown |
| `GET /admin/analytics/trending-users` | GET | Users with rising engagement | Admin | Period: last 7/30 days |

---

## 7. Open Questions (Updated)

Decisions still pending from earlier planning sessions, plus new ones from this round.

### Unresolved Medium Priority

**Q1: React Admin Migration Strategy**
- **Options:**
  - A) Big-bang: Build React to parity, then cut over in one deployment
  - B) Route-by-route: Migrate one domain at a time (events, then customers, then users, etc.)
  - C) Dual-run: Both apps live temporarily; operators choose which to use
- **Recommendation:** Option B (route-by-route) is lower risk. Enables continuous validation with operators.
- **Status:** TBD (open to product owner preference for speed vs. safety)

**Q2: Influence Score Visibility**
- **Options:**
  - A) Completely hidden from users; used only internally for ranking and data products
  - B) Partially visible as badge threshold ("Top 10% Influencer")
  - C) Fully visible with numeric score on profile
- **Risk of C:** Creates gamification / status anxiety dynamics
- **Recommendation:** Option A to start; revisit at Phase 7
- **Status:** TBD

**Q3: Professional Ratings Visibility**
- **Options:**
  - A) Public (visible to all, searchable)
  - B) Verified-to-verified (only verified users can see ratings)
  - C) Hidden (owner + employer only; data products only)
- **Business impact:** A drives trust, may deter low-rated users. B/C preserve privacy.
- **Status:** TBD

**Q5: Community Board Post Types**
- **Current:** general, collaboration, job, announcement (all in one feed)
- **Decision needed:** Confirm jobs stay in separate tab, NOT in community feed
- **Current working assumption:** Separate Jobs tab; community feed = general + collaboration + announcements
- **Status:** Near-resolved; needs confirmation before Phase 5 implementation

**Q6: Verified-to-Verified Connections Outside Events**
- **From open_questions.md:** Can two verified users connect outside events (coffee shop, photoshoot)?
- **Options:**
  - A) Strict: No, connections only at events
  - B) Verified exception: Yes, verified users can connect anytime
  - C) Timed windows: "Open networking" events where verified users can freely connect
- **Decision needed:** Does out-of-event connection increase retention, or dilute the event value prop?
- **Status:** TBD

**Q7: Admin-Added User Testing Workflow**
- **How do admin-added testers get verified without a real event?**
- **Options:** A) Test events with codes that work anytime; B) Admin directly sets status to `verified`; C) `bypass_ticket_check` flag
- **Status:** TBD (low urgency — can use option B as temporary dev workaround)

**Q8: Phone Number Changes**
- **How does a user update their phone number (the login identifier)?**
- **Options:** A) Self-service (verify new number via SMS); B) Admin-only; C) Not supported in MVP
- **Status:** TBD — Option C (not in MVP) is acceptable

### Resolved (Updated — March 2026)

| Decision | Outcome | Date |
|---|---|---|
| Open registration vs. invite-only | Open registration. Verification ladder is the feature gate | March 2026 |
| Posh webhook auto-creating users | No. Posh stores orders; users create accounts. Auto-link by phone | March 2026 |
| Verification-based feature gating | Yes — required backend `requireVerified` middleware | March 2026 |
| venueStaff user role | Removed from `user_role`. Venue staff are `eventOps` admin users | March 2026 |
| RBAC approach | Three separate account tables (users, admin_users, job_poster_accounts) | March 2026 |
| Job poster account type | Separate `job_poster_accounts` table; probationary lifecycle | March 2026 |
| Job poster ↔ Customer relationship | Job poster optionally linked to customer; auto-provisioned on job subscription purchase | March 2026 |
| Image storage architecture | First-class `image_assets` table; LLM cleanup job; archive vs. delete | March 2026 |
| Community post media | Photos yes (max 4 per post, S3 + sharp resize). Videos DEFERRED post-launch | March 2026 |
| Push notifications mechanism | FCM (Firebase Cloud Messaging) for iOS + Android | March 2026 |
| Wristband notification | Push via FCM; deep-links to Who's Here; additive (non-blocking) | March 2026 |
| Analytics compute engine | DuckDB (embedded in Node.js/Python cron); not Apache Spark (overkill) | March 2026 |
| Influence score display | NOT on user profiles; used in data products + search ranking only | March 2026 |
| Job post location fields | location_display, location_city, location_state, location_country, remote_ok | March 2026 |
| Video uploads | DEFERRED post-launch; Instagram is social backup for video content | March 2026 |
| React admin local port | Port 3630 | March 2026 |
| ToS/Privacy timing | Phase 2 (before App Store submission); legal review required before go-live | March 2026 |
| Export My Data vs. Delete Account | NOT prerequisites. Delete Account ships in Phase 0. Export My Data is a very late phase feature (post-MVP) | March 2026 |
| Event check-in comparables | Post-MVP comparison planned (early May 2026) vs. Zkipster, Splash, Boomset, Eventbrite, DICE, Posh | March 2026 |
| A2P 10DLC registration | Deferred — Twilio Verify covers auth path; no non-auth SMS yet | March 2026 |
| Market area filtering | Add to events + users | March 2026 |

---

## 8. Known Bugs & Technical Debt

### Critical (affects user experience)

1. **Token refresh 500 error** (Phase 0)
   - JWT library errors not caught; return 500 instead of 401
   - Users see "error: refresh token" popup instead of clean login
   - Fix: Wrap verifyToken in try/catch, throw UnauthorizedError

2. **Delete Account missing** (Phase 0)
   - Backend works, no UI button
   - App Store compliance risk
   - Fix: Add button to Settings screen

3. **PostsApi.unlikePost crashes** (Phase 0)
   - Casts void response to Map<String, dynamic>
   - Runtime TypeError
   - Fix: Change delete() return type or unlikePost() signature

4. **SQL injection in posts.ts** (Phase 0)
   - userId interpolated instead of parameterized
   - Low risk (JWT signed) but security smell
   - Fix: Use $1 parameter placeholder

5. **Post author never deserializes** (Phase 1)
   - Backend returns flat author_name/author_photo
   - Model expects nested User object
   - Author always null in UI
   - Fix: Update model to use authorName/authorPhoto fields

### Medium

6. **Sponsor/vendor edit endpoints missing** (Phase 3)
   - PATCH /admin/sponsors/:id not implemented
   - PATCH /admin/vendors/:id not implemented
   - Admin UI calls them, gets 404
   - Fix: Implement backend routes

7. **Comment delete endpoint missing** (Phase 0)
   - DELETE /posts/:id/comments/:commentId not implemented
   - Fix: Implement backend route

8. **Photo upload endpoint missing** (Phase 1)
   - POST /users/me/photo not implemented
   - Fix: Implement backend route + S3 integration

9. **S3 image orphaning** (Phase 8)
   - Event delete doesn't trigger S3 delete
   - Images left dangling in S3
   - Fix: Add S3 delete to event delete route

10. **Token refresh missing tokenFamily validation** (Phase 0)
    - POST /auth/refresh doesn't check tokenFamily === 'social'
    - Admin tokens could generate social access tokens
    - Fix: Add check

11. **UserDetailScreen deep link broken** (Admin app)
    - Fails when accessed by URL without GoRouter extra
    - Falls back to loading state that never completes
    - Fix: Fetch user from API when extra is null

### Low (nice-to-have)

12. **Health check doesn't verify DB** (Phase 8)
    - GET /health returns ok without checking DB connectivity
    - Should return 500 if DB unreachable
    - Fix: Add DB ping to health check

13. **No rate limiting** (Phase 8)
    - Any endpoint can be hammered
    - SMS endpoint vulnerable to bombing
    - Fix: Implement token bucket / sliding window rate limiting

14. **Analytics tables empty** (Phase 7)
    - analytics_connections_daily, analytics_users_daily, analytics_events, analytics_influence all exist but no writes
    - Fix: Implement nightly batch jobs

---

## 9. Risk Assessment & Mitigation

### Schedule Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|-----------|
| LLM moderation costs explode | Medium | Cost overrun | Implement confidence-based routing (Haiku for high-confidence cases only). Set budget alerts. Monitor API costs weekly. |
| React admin migration takes longer than 4-6 weeks | Medium | Deadline miss | Run parallel track (Flutter continues; don't deprecate until parity proven). Use time-boxing to identify blockers early. |
| Event wrap report LLM generation fails | Low | Feature unusable | Implement fallback: template-based report if LLM fails. Admin can still edit. Retry with exponential backoff. |

### Technical Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|-----------|
| Moderation queue backlog grows | Medium | Latency increases | Implement alerting on queue depth. Scale Haiku workers horizontally. Prioritize high-engagement posts. |
| Influence metric algorithm is slow | Low | Nightly job times out | Implement incremental updates (update top 1000 daily, rest weekly). Profile algorithm. Use materialized views in Postgres. |
| Posh order auto-linking fails silently | Medium | Support burden | Log all linking attempts. Admin review queue for unlinked orders. Implement manual override UI. |
| Database migration fails | Low | Downtime | Test migrations on staging. Implement down-migration scripts. Brief maintenance window for large schema changes. |

### Product Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|-----------|
| Community board attracts spam/harassment | Medium | User trust damage | Implement LLM moderation pipeline (Phase 4). Human review queue. Clear ToS + enforcement. |
| Jobs board dilutes event attendance | Low | Revenue impact | Monitor event attendance pre/post-jobs launch. Keep jobs tab separate (not in main feed). Emphasize in-person networking value prop. |
| Professional ratings enable retaliation | Low | Legal risk | Require hire confirmation first (mutual verification). Allow ratings removal by IN staff for ToS violation. Implement appeals process. |

---

## 10. Success Metrics & Launch Criteria

### Phase 1 (Social App Completion) Done When:

- [x] Community feed loads and displays real posts
- [x] Post creation works end-to-end
- [x] Search returns real user results
- [x] Delete Account button present and functional
- [x] All critical bugs from Phase 0 fixed
- [x] Stubbed screens replaced with real API calls
- [x] Retention metrics: DAU increase, post engagement increase
- [x] App Store submission passes (Delete Account requirement)

### Phase 3 (React Admin Parity) Done When:

- [ ] React admin feature parity with Flutter confirmed (test checklist)
- [ ] Admin operators have completed training on React UI
- [ ] Performance acceptable (page loads < 2s, no major jank)
- [ ] All critical workflows tested (event create → publish → check-in)
- [ ] Big-bang cutover plan documented and rehearsed
- [ ] Rollback plan tested
- [ ] Big-bang migration executed; Flutter admin deprecated

### Phase 4 (LLM Moderation) Done When:

- [ ] Moderation pipeline processes all new posts within SLA (< 5 min avg)
- [ ] False positive rate < 5% (verified by human audit)
- [ ] Admin review queue functional
- [ ] Metrics dashboard shows moderation effectiveness
- [ ] Platform maintainability improved (admin workload down)

### Phase 5 (Jobs Board) Done When:

- [ ] Job posting flow end-to-end tested
- [ ] Job search working (filter, sort, pagination)
- [ ] Hire confirmation working (both parties can initiate)
- [ ] Admin jobs management complete
- [ ] Revenue: first job posts arriving (optional; nice-to-have metric)

### Phase 7 (Analytics & Data Products) Done When:

- [ ] Analytics dashboard fully functional
- [ ] Influence metric populating nightly with reasonable values
- [ ] Event wrap report generation end-to-end working
- [ ] Customers receiving reports; analytics value demonstrated
- [ ] Data product differentiation clear (why customers buy reports vs. raw data)

---

## 11. Appendix: Virtual/Avatar Attendee Concept

**Concept:** An individual with health constraints (illness, immunocompromise, etc.) attends an IN event virtually via a device (iPad, phone, laptop) held by another attendee, or through video call integration (FaceTime, Teams, Zoom).

**Implementation:** Zero engineering required. The QR system already supports this naturally:

1. Virtual attendee has a ticket and checks in with activation code (via video call or device in attendee's hands)
2. Virtual attendee's QR code is displayed on device
3. Other attendees scan the QR; system creates connection with the virtual attendee
4. Both parties receive connection notifications; connection recorded in database

**Benefits:**
- Accessibility feature (positions IN as inclusive)
- Doesn't reduce event value (still requires physical presence of someone; connection counts)
- Differentiates IN from competitors
- Positive PR / community goodwill

**Positioning:** Document as accessibility innovation. Include in marketing materials. Highlight in early user communications ("IN events are for everyone").

**No schema changes or feature flags required.** Pure operational/community innovation.

---

## 12. References & Related Documents

- **Product Requirements:** docs/product/requirements.md
- **Adversarial Review:** docs/analysis/adversarial_review.md
- **Implementation Audit:** docs/analysis/implementation_audit.md
- **Open Questions:** docs/product/open_questions.md
- **Design Direction:** docs/design/ux_design_direction.md
- **Architecture:** docs/architecture/aws_architecture.md
- **GitHub Issue Tracker:** See issues #1-#30 (tracked bugs and improvements)

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-02-04 | — | Initial implementation plan |
| 1.1 | 2026-02-27 | — | Progress update, resolved decisions |
| 2.0 | 2026-03-22 | Claude | Complete master plan: new requirements (React admin, LLM moderation, jobs, ratings), gap analysis, phased implementation (Phases 0-8), React admin architecture spec, API endpoint inventory, risk assessment, success metrics |
| **2.1** | **2026-03-22** | **Claude** | Architectural decisions from planning session: RBAC three-table design (§2.13, §5.5), venueStaff→eventOps migration, admin_role expansion (moderator + eventOps), image_assets first-class architecture (§2.16, §5.8), push notifications FCM (§2.14, §5.6), Event Ops screen design (§2.15, §5.7), platform_config + llm_usage_log tables added to Phase 0, wristband flow (§6.8d), job_poster_accounts table + probationary lifecycle, image cleanup LLM job, API key management (§5.9), dev scripts port 3630 (§5.10), event check-in comparables (§5.11), ToS/Privacy Phase 2 placement (§2.18), Export My Data moved to Phase 9 (very late), video uploads deferred, DuckDB confirmed for analytics, community post photos yes/videos no, resolved questions table updated (§7) |

