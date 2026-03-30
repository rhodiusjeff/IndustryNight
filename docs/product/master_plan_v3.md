# Industry Night Master Plan v3

**Version:** 3.0
**Date:** March 30, 2026
**Status:** Active Planning — X2-A2 output
**Audience:** Product Owner, Engineering Leadership, CODEX Implementation Agents
**Supersedes:** `docs/product/master_plan_v2.md` (v2.1, March 22, 2026)

---

## v2 → v3: What Changed and Why

This document supersedes master_plan_v2.md following the X2 governance sprint (March 26–30, 2026). v3 incorporates:

1. **Codex execution reality** — Tracks A0 (critical fixes), A1 (community board), A2 (user search/profile), A3 (perks/sponsors), X1 (schema consolidation), and B0 (React admin scaffold) have been run. Implementation state has shifted materially since v2.
2. **Admin nav corrections (Jeff signoff, March 29, 2026)** — Three X2-A1 product decisions locked in:
   - **Tickets:** Top-level nav item AND event-scoped sub-view. Two-layer model confirmed.
   - **Images/Image Catalog:** Top-level nav item AND event-scoped sub-gallery. Two-layer model confirmed.
   - **Markets:** Under Settings, but Settings nav label must be reframed as **"Platform"** (contains platform ops, not user preferences).
3. **Products nav clarification:** Standalone top-level nav item in React (matches Flutter sidebar precedent). Not collapsed under Customers.
4. **CSAM architecture flag** — Image upload pipeline requires a hard-block content scan (AWS Rekognition or equivalent) before S3 write. This is a P0 architecture gap, not in any existing C-track prompt. Flagged here; must be resolved before C3 executes.
5. **Phase status corrections** — Phases 0 and 1 are substantially complete; phases 2–9 remain.

---

## Executive Summary

Industry Night is a platform for creative professionals (hair stylists, makeup artists, photographers, videographers, producers, directors) to discover networking events, make QR-scan connections, and build community. The platform consists of a mobile-first Flutter social app, an admin dashboard (Flutter Web now; migrating to React/Next.js), and a Node.js/PostgreSQL backend on AWS EKS.

As of v3, the platform's transactional loop is fully operational and the social retention features (community, search, perks) are wired up. The focus shifts to: (1) React admin app build-out, (2) backend infrastructure hardening (FCM, image assets, platform config), (3) jobs board and professional ratings, and (4) analytics and data products.

**Theme:** Phase 1 complete → ready to scale → ready to monetize.

---

## 1. Current State Assessment (as of March 30, 2026)

### 1.1 What Works End-to-End

| Category | Status | Notes |
|----------|--------|-------|
| Phone SMS authentication | ✅ Complete | Twilio Verify (prod) / devCode (dev), JWT with token families |
| Event management (admin) | ✅ Complete | Full CRUD, multi-image upload with S3, hero image system, publish gate |
| Event check-in flow | ✅ Complete | Activation code validation (QR scan or manual entry), ticket validation |
| QR networking | ✅ Complete | Instant mutual connections, celebration overlay, auto-verification, polling notifications |
| Admin dashboard | ✅ Complete | Live stats (users, events, connections, posts), user management, event CRUD |
| Posh webhook integration | ✅ Complete | Receives new_order events, stores posh_orders, sends invite SMS/email |
| Community board | ✅ Complete (A1) | Feed, create post, post detail — wired to real API |
| User search + profiles | ✅ Complete (A2) | Search screen, user profile, connections list — wired to real API |
| Perks/sponsors | ✅ Complete (A3) | Perks screen, sponsor detail, discount redemption — wired to real API |
| Schema consolidation | ✅ Complete (X1) | Migrations 001–004 merged into 001_baseline_schema.sql |
| Profile photo upload | ⚠️ API endpoint missing; Flutter UI disabled | `POST /users/me/photo` not implemented; `edit_profile_screen.dart` button is `onPressed: null`; flagged as A2 delivery item |
| Delete account (GoRouter-safe) | ✅ Complete (A0) | Auth-safe delete flow with GoRouter refreshListenable guard |

### 1.2 What's In Progress or Scaffolded

| Feature | Status | Notes |
|---------|--------|-------|
| React admin scaffold (B0) | ✅ Scaffold complete, 2 blocking items | Login + dashboard real; all other pages ComingSoon; client.ts proxy fix + Playwright port required before PR merge |
| React admin full build (B1–B3) | 🔜 Next | Pending B0 merge; B1 (auth/RBAC) → B2 (event ops) → B3 (admin parity) |
| Push notifications (C2) | 🔜 Pending | After C0 + C1 schema; FCM service + Flutter receiver |
| SSE check-in stream (C1) | 🔜 Pending | Backend SSE endpoint; used by React Event Ops screen (B2) |
| Image assets first-class (C3) | 🔜 Pending | **CSAM scan required before this ships** — see §7 |
| Platform config UI (C4) | 🔜 Pending | Depends on C2/C3 services being available |
| Platform config schema (C0) | ✅ Specced | platform_config table, llm_usage_log, admin_role enum expansions |

### 1.3 What Remains

| Category | Phase Estimate | Track |
|----------|---------------|-------|
| React admin full UI (auth, event ops, all parity screens) | Phase 2 | B1–B3 |
| FCM push notifications | Phase 2 | C2 |
| Image assets architecture + CSAM | Phase 2 | C3 |
| Platform config management | Phase 2 | C4 |
| LLM content moderation pipeline | Phase 3 | D0 |
| Analytics dashboard (admin) | Phase 3 | D1–D2 |
| Jobs board (backend + social UI) | Phase 4 | E0–E1 |
| Hire confirmation + professional ratings | Phase 4 | E2 |
| Job poster portal | Phase 5 | E3 |
| Full-text search (social + admin) | Phase 4+ | F0–F2 |
| Help system | Phase 5 | G0 |
| Professional ratings | Phase 4 | E2 |
| Event wrap reports | Phase 5 | D1 |
| GDPR data export | Phase 5+ | C1 partial |
| Rate limiting + API hardening | Phase 3 | C8 (TBD) |

---

## 2. Requirements Inventory

### 2.1 React Admin App Migration

**Description:** Migrate the admin dashboard from Flutter Web to Next.js (React + TypeScript + shadcn/ui + Tailwind CSS) with dark-first design system.

**Why it matters:** Flutter Web is not optimized for desktop workflows. The desktop experience is sluggish, modal/drawer patterns don't feel native. React is the standard for web admin dashboards.

**Scope:** Large (B0–B3, ~4-6 weeks)

**Current state:** B0 scaffold complete; 2 blocking items before PR merge (client.ts proxy fix, Playwright port). B1–B3 pending.

### 2.2 LLM Content Moderation Pipeline

**Description:** Posts run through asynchronous moderation before appearing. Two-stage pipeline: Haiku (fast, cheap, high-volume) → Sonnet for borderline cases. Confidence-based routing: auto-approve safe content, auto-reject flagrant violations, flag uncertain for human review.

**Scope:** Medium (2-3 weeks, Track D0)

**Dependencies:** Community feed wired (✅ complete via A1). Admin moderation review queue (B3).

### 2.3 Community Board

**Status:** ✅ Complete (Track A1). API wired, real data, post create/detail/like/comment flows working.

**Remaining:** LLM moderation pipeline (D0), comment delete endpoint missing (API gap — see C1), delete own comment in social app.

### 2.4 Jobs Board

**Description:** Structured job postings. Distinct from general community posts. `jobs` table with title, description, specialty, compensation, location, remote flag. Dedicated tab in social app. Search and filter. Employer-verified posting gate.

**Scope:** Medium (3-4 weeks, Tracks E0–E1)

**Dependencies:** Primary specialty (done), hire confirmation (E2), admin jobs management (E-track admin).

### 2.5 Hire Confirmation Flow

**Description:** Either party initiates "I was hired" confirmation. Other party gets notification. Both must confirm. Only after confirmed hire can job poster submit a professional rating.

**Scope:** Small (1-2 weeks, Track E2)

**Dependencies:** Jobs Board (E0-E1).

### 2.6 Professional Ratings

**Description:** Employer-verified reviews locked behind hire confirmation. Rating covers quality, professionalism, communication. Visible on user profiles. LLM-moderated. Feeds data product.

**Scope:** Small-Medium (2 weeks, Track E2)

**Dependencies:** Hire confirmation.

### 2.7 Primary Specialty Designation

**Status:** ✅ Complete — `users.primary_specialty_id` FK exists in schema, profile editing supports selection.

### 2.8 Profile Photo Upload

**Status:** ⚠️ Incomplete. The `uploadProfilePhoto` method exists in `UsersApi` (Dart) and the `profile_photo_url` column exists in the `users` table, but:
- `POST /users/me/photo` API endpoint does **not exist** in `packages/api/src/routes/users.ts`
- Flutter `edit_profile_screen.dart` has `onPressed: null, // photo upload deferred to v1.0`
- No Jest or widget test coverage
- A2 `docs/codex/track-A/A2-user-search-profile.md` spec has been updated to own this as a first-class deliverable.

### 2.9 Influence Score

**Description:** Nightly PageRank-variant weighted by attendance, connections, post engagement. Displayed on user profiles. Powers search ranking and data products.

**Scope:** Medium (Track D2)

**Dependencies:** Community feed stable + analytics tables populated.

### 2.10 Event Ops Screen (React Admin)

**Description:** Mobile-optimized section of React admin. Live check-in SSE stream, wristband confirmation flow, QR tablet mode, Posh order exceptions queue. Roles: `eventOps`, `platformAdmin`.

**Scope:** Large (Track B2)

**Dependencies:** SSE endpoint (C1), wristband endpoint (C1), FCM (C2).

### 2.11 Admin User Management (RBAC)

**Description:** Three admin roles — `platformAdmin`, `moderator`, `eventOps`. Admin users managed via `/admin/admin-users` endpoints. Job poster accounts via `/admin/job-poster-accounts`. Role-gated routes in React admin via `<RequirePermission>` wrapper.

**Scope:** B1 (auth), B3 (admin users screen)

**Status:** `authenticateAdmin` + `requirePlatformAdmin` middleware complete. React auth screen pending B1.

### 2.12 Posh Orders Screen

**Description:** Admin view of all Posh webhook orders with reconciliation status. Exception queue for unlinked orders (buyer has no app account). Link exception to user by phone.

**Scope:** B3

**Dependencies:** `GET /admin/posh-orders` endpoint (missing — see §6.4 API Gaps).

### 2.13 Analytics + Event Wrap Reports

**Description:** Nightly analytics jobs (connections_daily, users_daily, events, influence). Analytics dashboard in React admin. Event wrap report: auto-generated 24h post-event, LLM-drafted, admin-editable, distributed to data product customers.

**Scope:** Large (Tracks D1-D2)

**Dependencies:** Community + events stable.

### 2.14 Full-Text Search

**Description:** PostgreSQL full-text search for users (by specialty, name, city). Admin global search (users + events + orders). Search ranking weighted by influence score.

**Scope:** Medium (Track F)

**Dependencies:** Influence score.

### 2.15 Image Assets Architecture

**Description:** First-class `image_assets` table replacing raw S3 URL storage. Every uploaded image tracked with metadata (dimensions, file size, MIME type), pHash for near-duplicate detection, LLM tagging (Haiku), and lifecycle management (active → archived → deleted).

**CSAM flag:** See §7. Hard-block required before this ships.

**Scope:** Large (Track C3)

### 2.16 Push Notifications (FCM)

**Description:** Firebase Cloud Messaging for iOS/Android. Three use cases: new connection, wristband confirmation, job application updates. Fully additive — FCM failures never block primary flows.

**Scope:** Medium (Track C2)

**Dependencies:** C0 (fcm_token column on users), C1 (wristband endpoint).

---

## 3. Implementation Phases

### Phase 0: Critical Fixes (✅ Complete — Track A0)

Schema consolidation (X1), profile photo upload, delete account (GoRouter-safe), comment delete endpoint, unlike bug fix, connection polling fix, profile image display.

### Phase 1: Social Retention (✅ Substantially Complete)

| Feature | Track | Status |
|---------|-------|--------|
| Community board wired | A1 | ✅ |
| User search + profiles | A2 | ✅ |
| Perks / sponsors / redemptions | A3 | ✅ |

**Remaining in Phase 1:** LLM moderation (D0), influence nightly job (D2 part).

### Phase 2: React Admin + Backend Infrastructure (In Progress)

| Feature | Track | Status |
|---------|-------|--------|
| React admin scaffold | B0 | ✅ (2 blocking pre-merge items) |
| Schema foundation (admin_role, fcm_token, platform_config) | C0 | ✅ Specced |
| SSE check-in stream + wristband endpoint | C1 | Pending |
| FCM push notifications | C2 | Pending |
| Image assets + CSAM | C3 | Pending (CSAM gate) |
| Platform config management | C4 | Pending |
| React admin auth + RBAC | B1 | Pending B0 merge |
| React admin event ops screen | B2 | Pending B1 + C1 + C2 |
| React admin full parity | B3 | Pending B1 |

**Phase 2 gate:** B0 blocking items resolved → B1 begins. C tracks can run in parallel with B1.

### Phase 3: Moderation + Analytics

| Feature | Track | Status |
|---------|-------|--------|
| LLM moderation pipeline | D0 | Pending Phase 1 stable |
| Analytics nightly jobs | D1 | Pending Phase 1 stable |
| Analytics React admin dashboard | D2 | Pending D1 |
| Influence score (nightly batch) | D2 | Pending D1 |
| Rate limiting + API hardening | TBD | Parallel to Phase 3 |

### Phase 4: Jobs Board

| Feature | Track | Status |
|---------|-------|--------|
| Jobs schema + backend | E0 | Pending Phase 1 stable |
| Jobs board Flutter UI | E1 | Pending E0 |
| Hire confirmation + ratings | E2 | Pending E1 |
| Full-text search (social + admin) | F0–F2 | Parallel to Phase 4 |

### Phase 5: Job Poster Portal + Event Wrap Reports

| Feature | Track | Status |
|---------|-------|--------|
| Job poster account portal | E3 | Pending E2 |
| Event wrap reports | D1 (late) | Pending analytics stable |

### Phase 6: Data Products + GDPR

| Feature | Track | Status |
|---------|-------|--------|
| Data product delivery | D1 | Pending wrap reports |
| GDPR data export | C1 (partial) | Post-MVP |

---

## 4. Intentional Divergences: Flutter Admin vs. React Admin

This section documents where the React admin intentionally diverges from the Flutter admin precedent, and where it aligns. These are binding decisions — TEs should not deviate without TC approval.

| Area | Flutter Admin | React Admin | Decision | Rationale |
|------|--------------|-------------|----------|-----------|
| Tickets nav | Top-level (TicketsListScreen at `/tickets`) | **Top-level AND event-scoped** | ✅ Two-layer model | (Jeff signoff, X2-A1) Ticket list needs both global view (reconciliation, search) and per-event view (who attended this specific event). |
| Images nav | Top-level (ImageCatalogScreen at `/images`) | **Top-level AND event-scoped** | ✅ Two-layer model | (Jeff signoff, X2-A1) Image catalog provides cross-event management; event-scoped gallery is the upload/hero workflow. |
| Markets nav | Top-level under SETTINGS section | **Sub-tab under Platform Settings** | ✅ Under Platform | (Jeff signoff, X2-A1) Markets is platform ops, not user preference — correctly placed in Settings node. |
| Settings label | "Settings" (vague) | **"Platform"** | ✅ Reframe | (Jeff signoff, X2-A1) Contains platform operations sub-tabs: General, Markets, Audit Log, Platform Config, API Key Status. |
| Products nav | Top-level (ProductCatalogScreen at `/products`) | **Top-level** | ✅ Same as Flutter | v2 §5.3 incorrectly collapsed Products under Customers. Flutter top-level precedent is correct — products are a catalog, not customer-scoped. |
| Moderation nav | Posts + Announcements (separate nav items) | **Single "Moderation" section** | ✅ Intentional consolidation | React groups both into one section (B0 permissions.ts). |
| Event Ops screen | Missing | **New top-level section** | ✅ New | Mobile-optimized section for venue operations staff. |
| Analytics screen | Missing | **New top-level section** | ✅ New | Platform intelligence; platformAdmin only. |
| Posh Orders screen | Missing | **New top-level section** | ✅ New | Posh order reconciliation and exception queue. |
| Jobs Board screen | Missing | **New top-level section** | ✅ New | Job listing management for E-track. |

---

## 5. React Admin App — Architecture Spec (v3)

### 5.1 Technology Stack

*(Unchanged from v2)*

- **Framework:** Next.js 14+ (App Router)
- **UI Library:** shadcn/ui components (built on Radix UI + Tailwind CSS)
- **Styling:** Tailwind CSS with custom design tokens (dark-first)
- **State Management:** React Query (server state) + Zustand (client state) or Context API
- **Animation:** Framer Motion for transitions, drawer slide-ins, toast animations
- **Deployment:** Docker container → ECR → EKS (same pattern as API)
- **Build:** Vercel's Next.js toolchain; SWC for transpilation
- **TypeScript:** Strict mode; generated types from API schema (openapi-typescript)

### 5.2 Design System

*(Unchanged from v2)*

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

### 5.3 Navigation Structure (v3 — Authoritative)

Navigation is role-gated. The sidebar structure below is the **binding specification** as of March 30, 2026. It supersedes the v2 §5.3 nav structure and B0's `permissions.ts`. TEs implementing B1–B3 must follow this nav structure exactly.

**Design change from v2:** "Settings" renamed to "Platform" throughout. Tickets and Image Catalog are now explicitly listed as top-level nav items.

```
Sidebar Navigation (role visibility noted):
├── Dashboard [platformAdmin, moderator, eventOps]
│   └── Stats overview, recent activity
├── Event Ops [eventOps, platformAdmin] ← Mobile-optimized section
│   ├── Live Check-in Feed (SSE real-time stream)
│   ├── Wristband Confirmation (tap to confirm)
│   ├── QR Tablet Mode (full-screen check-in QR)
│   └── Posh Order Exceptions (unlinked orders queue)
├── Users [moderator, platformAdmin]
│   ├── Social Users (list, search, filter, detail, ban, verify)
│   ├── Admin Users (CRUD — platformAdmin only)
│   └── Job Poster Accounts (list, approve, suspend — Phase 4+)
├── Events [eventOps, platformAdmin]
│   ├── Event List (status, image count, partner count)
│   ├── Create Event
│   └── Event Detail (images + partners inline; event-scoped ticket list; event-scoped image gallery)
├── Tickets [platformAdmin, eventOps] ← TOP-LEVEL (two-layer model)
│   ├── All Tickets (global list — search, filter by event, status, type)
│   └── [Per-event sub-view reached from Events → Event Detail → Tickets tab]
├── Image Catalog [platformAdmin] ← TOP-LEVEL (two-layer model)
│   ├── All Images (cross-event grid — search, filter by event, bulk delete)
│   └── [Per-event sub-gallery reached from Events → Event Detail → Images tab]
├── Customers [platformAdmin]
│   ├── List (filter by product type, market)
│   ├── Add Customer
│   └── Customer Detail (products, discounts, redemption stats, contacts, media)
├── Products [platformAdmin] ← TOP-LEVEL (standalone catalog)
│   ├── Product Catalog (all sponsorship/vendor/data product definitions)
│   ├── Add Product
│   └── Product Detail / Edit
├── Jobs Board [moderator, platformAdmin] ← Phase 4+
│   ├── Job Listings (review, approve, manage)
│   └── Hire Confirmations
├── Moderation [moderator, platformAdmin]
│   ├── Posts Review Queue (LLM confidence scores, flag/approve/reject)
│   ├── Ratings Review Queue (Phase 4+)
│   └── Announcements (create + manage)
├── Posh Orders [eventOps, platformAdmin]
│   ├── All Orders (reconciliation status)
│   └── Exception Queue (unlinked orders)
├── Analytics [platformAdmin] ← Phase 3+
│   ├── Overview Dashboard
│   ├── Influence Scores (leaderboard)
│   ├── Event Reports (wrap reports)
│   └── Data Products
└── Platform [platformAdmin] ← Renamed from "Settings"
    ├── General (label: Platform; contains platform-wide settings)
    ├── Markets (geographic/categorical market management)
    ├── Audit Log (view history — filter by action, actor, date)
    ├── Platform Config (LLM settings, feature flags — inline edit)
    └── API Key Status (service connectivity, Test Connection buttons)

Top Bar:
├── Search (global user/event/order search — Phase 4+)
├── Notifications (placeholder)
└── User Menu (logout, role display)
```

**Route mapping:**

| Route | Screen | Role |
|-------|--------|------|
| `/login` | LoginPage | Public |
| `/` | DashboardPage | All |
| `/event-ops` | EventOpsPage | eventOps, platformAdmin |
| `/users` | UsersPage | moderator, platformAdmin |
| `/users/:id` | UserDetailPage | moderator, platformAdmin |
| `/users/add` | AddUserPage | platformAdmin |
| `/admin-users` | AdminUsersPage | platformAdmin |
| `/events` | EventsPage | eventOps, platformAdmin |
| `/events/create` | EventCreatePage | platformAdmin |
| `/events/:id` | EventDetailPage | eventOps, platformAdmin |
| `/events/:id/edit` | EventEditPage | platformAdmin |
| `/tickets` | TicketsPage | eventOps, platformAdmin |
| `/images` | ImageCatalogPage | platformAdmin |
| `/customers` | CustomersPage | platformAdmin |
| `/customers/add` | CustomerCreatePage | platformAdmin |
| `/customers/:id` | CustomerDetailPage | platformAdmin |
| `/customers/:id/edit` | CustomerEditPage | platformAdmin |
| `/customers/:id/discounts` | DiscountsPage | platformAdmin |
| `/products` | ProductsPage | platformAdmin |
| `/products/add` | ProductCreatePage | platformAdmin |
| `/products/:id/edit` | ProductEditPage | platformAdmin |
| `/jobs` | JobsPage | moderator, platformAdmin |
| `/moderation` | ModerationPage | moderator, platformAdmin |
| `/posh-orders` | PoshOrdersPage | eventOps, platformAdmin |
| `/analytics` | AnalyticsPage | platformAdmin |
| `/platform` | PlatformSettingsPage | platformAdmin |
| `/platform/markets` | MarketsPage | platformAdmin |
| `/platform/audit-log` | AuditLogPage | platformAdmin |
| `/platform/config` | PlatformConfigPage | platformAdmin |
| `/platform/api-status` | ApiStatusPage | platformAdmin |

### 5.4 RBAC Architecture

*(Extension of v2 §5.5)*

Three token families, three separate account tables:

| Account Type | Table | Auth Method | Token Family | Portal |
|---|---|---|---|---|
| Social users | `users` | Phone + SMS OTP | `social` | Flutter social app |
| Admin/ops staff | `admin_users` | Email + password | `admin` | React admin app |
| Job poster employers | `job_poster_accounts` | Email + password | `jobPoster` | Separate React job poster portal (Phase 5) |

**Admin roles (`admin_role` enum):**
- `platformAdmin` — full access to all sections
- `moderator` — Users (read) + Moderation (write) + Dashboard
- `eventOps` — Event Ops + Events (read/write) + Tickets + Posh Orders + Dashboard

**Job poster account lifecycle:** `pending → probationary → active → suspended`

**Permissions pattern:** `lib/permissions.ts` in React admin wraps each section with `<RequirePermission permission="admin:events:write">`. Sidebar items are filtered by role; unauthorized direct URL access → silent redirect to permitted home screen.

### 5.5 Component Inventory

*(Unchanged from v2 §5.4)*

**Layout:** Sidebar, TopBar, MainContent, Modal/Drawer/Sheet

**Data:** DataTable, DataGrid, Card, Badge

**Form:** Input, Textarea, Select, Checkbox, DateTime picker, FileUpload

**Feedback:** Toast, Alert, Skeleton, EmptyState, ErrorBoundary

### 5.6 Push Notifications Architecture

*(Unchanged from v2 §5.6)*

FCM via `firebase_messaging`. Token lifecycle: app launch → `getToken()` → `PATCH /users/me` → `onTokenRefresh` updates. Backend `sendPush(userId, title, body, data)` in `services/push.ts`. Fire-and-forget; failures non-fatal.

**Use cases (in priority order):**
1. New QR connection — triggers immediately on connection creation
2. Wristband confirmation — triggers when staff taps "Issue Wristband"
3. Job application status update (Phase 4+)
4. Hire confirmation request (Phase 4+)
5. Moderation decision (Phase 3+)

### 5.7 Event Ops Screen Design

*(Unchanged from v2 §5.7)*

Mobile-optimized section. Real-time SSE check-in stream (`GET /admin/events/:id/checkins/stream`). Wristband confirmation flow (optimistic UI). QR tablet mode (full-screen activation code). Posh exception queue with user-link action.

### 5.8 Image Assets Architecture

*(Updated from v2 §5.8 — CSAM gate added)*

First-class `image_assets` table replaces direct S3 URL storage. Upload flow now passes through a content scan before S3 write. See **§7 CSAM Architecture Flag** for the unresolved architecture decision.

**Upload flow (v3 — with CSAM gate):**
```
Admin/user selects file
  → POST /admin/images (multipart)
  → Server: sharp resize + compress
  → Server: CSAM scan (AWS Rekognition or equivalent) ← HARD BLOCK — rejected images never reach S3
  → Server: if scan fails → 422 response, no S3 write
  → Server: upload to S3
  → Server: create image_assets record (s3_key, url, size, dimensions, pHash)
  → Server: optionally trigger LLM tagging job (async, low priority)
  → Response: { assetId, url, similarImages? }
```

**Entity FK pattern (unchanged):**
- `event_images.image_asset_id` → `image_assets.id`
- `customers.logo_image_asset_id` → `image_assets.id`
- `users.profile_image_asset_id` → `image_assets.id`

### 5.9 API Key & Secrets Management

*(Unchanged from v2 §5.9)*

Secrets live exclusively in AWS Secrets Manager → K8s env vars. Admin Settings (now "Platform → API Key Status") shows connection status only. "Test Connection" calls upstream. "Configure" links to AWS Console. Non-secret values (LLM model versions, feature flags) in `platform_config`.

### 5.10 Local Development Scripts

*(Unchanged from v2 §5.10)*

Port: **3630** (memorable: Jeff's street address). `scripts/run-react-admin.sh` creates `.env.local` from template and starts dev server.

---

## 6. Backend API Additions Required

### 6.1 Primary Specialty & Influence

*(Same as v2 §6.1)*

| Endpoint | Status |
|----------|--------|
| `PATCH /users/me` — primary_specialty_id | ✅ Complete |
| `GET /users/:id/influence` | Pending (Track D2) |

### 6.2 Community Board

*(Same as v2 §6.2 — partially complete)*

| Endpoint | Status |
|----------|--------|
| `GET /posts` | ✅ Complete |
| `GET /posts/:id` | ✅ Complete |
| `POST /posts` | ✅ Complete |
| `PATCH /posts/:id` | ✅ Complete |
| `DELETE /posts/:id` | ✅ Complete |
| `POST /posts/:id/like` | ✅ Complete |
| `DELETE /posts/:id/like` | ✅ (bug fixed A0) |
| `GET /posts/:id/comments` | ✅ Complete |
| `POST /posts/:id/comments` | ✅ Complete |
| `DELETE /posts/:id/comments/:commentId` | ❌ **Missing — Track C1** |

### 6.3 Jobs Board (Pending — Track E0)

| Endpoint | Method | Auth | Status |
|----------|--------|------|--------|
| `GET /jobs` | GET | Social | Pending E0 |
| `GET /jobs/:id` | GET | Social | Pending E0 |
| `POST /jobs` | POST | Social (verified employer) | Pending E0 |
| `PATCH /jobs/:id` | PATCH | Social (verified employer) | Pending E0 |
| `DELETE /jobs/:id` | DELETE | Social (verified employer) | Pending E0 |
| `POST /jobs/:id/apply` | POST | Social (verified) | Pending E0 |
| `DELETE /jobs/:id/applications/:appId` | DELETE | Social | Pending E0 |
| `GET /jobs/:id/applications` | GET | Social | Pending E0 |

### 6.4 Admin API Gaps (Not yet in admin.ts)

| Endpoint | Purpose | Track |
|----------|---------|-------|
| `GET /admin/posh-orders` | List all Posh orders with reconciliation status | B3 |
| `GET /admin/posh-orders/exceptions` | Unlinked Posh orders (no user account) | B3 |
| `PATCH /admin/posh-orders/:id/link` | Link Posh order to a user account | B3 |
| `GET /admin/events/:id/checkins/stream` | SSE check-in stream | C1 |
| `PATCH /admin/events/:eventId/attendees/:ticketId/wristband` | Mark wristband issued | C1 |
| `PATCH /users/me/device-token` | Register FCM device token | C1 |
| `GET /admin/admin-users` | List admin accounts | B3 |
| `POST /admin/admin-users` | Create admin | B3 |
| `PATCH /admin/admin-users/:id` | Edit admin role/status | B3 |
| `DELETE /admin/admin-users/:id` | Soft-delete admin | B3 |
| `GET /admin/platform-config` | Read config | C4 |
| `PATCH /admin/platform-config/:key` | Update config | C4 |
| `GET /admin/system-status` | Service health check | C4 |

### 6.5 Hire Confirmation + Ratings (Pending — Track E2)

*(Same as v2 §6.4)*

### 6.6 Event Wrap Report (Pending — Track D1)

*(Same as v2 §6.6)*

---

## 7. CSAM Architecture Flag (Unresolved — P0 Gate on C3)

**Status:** Architecture decision required before Track C3 (image assets) executes.

**Issue:** The platform accepts image uploads from social users (profile photos) and admin users (event images, customer logos). No content scanning is currently applied. This is a legal liability and App Store compliance risk.

**Requirement:** A hard-block content scan must occur before any user-supplied image is written to S3. The scan must:
- Reject CSAM with certainty (zero false-negative tolerance)
- Block with `422 Unprocessable Content` — no partial writes to S3
- Be synchronous in the upload request path (not async/eventual)
- Log scan decisions for audit trail (not scan results — never store flagged content metadata)

**Options under evaluation:**

| Option | Pros | Cons |
|--------|------|------|
| **AWS Rekognition** (ModerationLabels) | Native AWS, no data leaves VPC, configurable confidence thresholds, low latency | Not CSAM-specific; requires tuning; additional cost |
| **PhotoDNA** (Microsoft) | Industry gold standard for CSAM detection; used by Thorn/NCMEC | Enterprise licensing; API latency; not self-hosted |
| **Google Cloud Vision SafeSearch** | Good coverage, easy integration | Data leaves AWS; GDPR considerations |
| **NCMEC Hash Database** | Purpose-built for CSAM; zero false positives for known material | Only catches known CSAM; novel material bypasses; requires NCMEC partnership |

**Recommended approach:** AWS Rekognition as the MVP gate (blocks explicit content broadly) + NCMEC hash matching for known CSAM. Both run synchronously; either failing → block.

**Decision needed from Jeff before C3 executes:**
1. Which scan service(s) to use
2. Confidence thresholds for Rekognition blocking
3. Whether to surface a dedicated C5 prompt (CSAM scan service setup) before C3

**Impact on track sequencing:** C3 is currently sequenced after C2. If CSAM service selection is delayed, C3 slides right. C3 blocking does not block B1–B2, but does block the image upload flow used in event management. Current Flutter image upload (pre-C3) continues to serve as fallback until C3 ships.

---

## 8. Schema Migration Plan (v3)

### Current State (post-X1)

| Migration | Status | Contents |
|-----------|--------|---------|
| `001_baseline_schema.sql` | ✅ Active | All tables, enums, triggers (consolidated from original 001-004) |

### Planned Migrations

| Migration | Track | Status | Contents |
|-----------|-------|--------|---------|
| `002_phase0_foundation.sql` | C0 | Pending | `admin_role` expansion (moderator, eventOps), `users.fcm_token`, `tickets.wristband_issued_at`, `platform_config`, `llm_usage_log` |
| `003_sse_wristband.sql` | C1 | Pending | SSE-related schema changes (if any), `wristband_issued_at` index additions |
| `004_fcm_extras.sql` | C2 | Pending | FCM operational columns if needed (probably none beyond C0) |
| `005_image_assets.sql` | C3 | Pending (**CSAM gate**) | `image_assets` table, indexes, migration of `event_images` data, drop `event_images` |
| `006_jobs_schema.sql` | E0 | Pending | `jobs`, `job_applications`, `hire_confirmations`, `professional_ratings`, `job_poster_accounts`, `user_agreements` tables |
| `007_analytics.sql` | D1 | Pending | `analytics_*` tables population; `analytics_influence` |

*Note: Migration numbers are provisional. Track C will assign actual numbering at execution time based on what's in the migrations directory.*

---

## 9. App Store + Deployment Checklist

**Orientation lock:** iOS and Android locked to portrait for social app. Handled by platform runner config.

**iOS deployment target:** iOS 14.0 minimum.

**Push notification entitlements:** `aps-environment` entitlement required in iOS provisioning. `GoogleService-Info.plist` not committed. Firebase setup in `packages/social-app/firebase-setup.md` (to be created in C2).

**TestFlight:** `scripts/deploy-ios-testflight.sh` exists. Run only after local QA pass.

**React admin:** Docker → ECR → EKS. `scripts/deploy-admin.sh` handles S3 sync + CloudFront invalidation for web distribution.

---

## 10. Architecture Decisions Log

*(Additions since v2)*

| Decision | Date | Decided By | Decision | Rationale |
|----------|------|-----------|---------|-----------|
| Tickets nav: two-layer model | 2026-03-29 | Jeff | Top-level AND event-scoped sub-view | Needs global reconciliation + per-event attendance view; neither alone is sufficient |
| Images nav: two-layer model | 2026-03-29 | Jeff | Top-level AND event-scoped sub-gallery | Image catalog for management; event-scoped for upload/hero workflow |
| Markets placement | 2026-03-29 | Jeff | Under "Platform" nav section | Markets is platform configuration, not user preference; belongs with operators |
| Settings → Platform rename | 2026-03-29 | Jeff | "Platform" (or "Platform Settings") | Current "Settings" label misrepresents the content; reframe as platform operations |
| Products nav: standalone | 2026-03-29 | TC (X2-A1) | Top-level (same as Flutter) | v2 §5.3 incorrectly collapsed Products under Customers; catalog is a top-level concept |
| CSAM gate on C3 | 2026-03-30 | TC (X2-A2) | Hard-block required before C3 executes | Legal liability + App Store compliance; cannot defer to post-MVP |
| Venue as text fields | (pre-v2) | Jeff | `venue_name` + `venue_address` as text on events | No Venue FK for new events; venues table is legacy |
| Open registration | (pre-v2) | Jeff | First SMS verify auto-creates user | No invite gate for social app |
| No DMs | (pre-v2) | Jeff | No direct messaging feature | Connections are the networking artifact; DMs create moderation burden |
| QR connections: mutual + instant | (pre-v2) | Jeff | No request/accept flow | Simulates in-person exchange; scanner gets celebration overlay |
| Posh as canonical ticket | (pre-v2) | Jeff | `posh_orders` is the ticket record | Walk-in tickets in `tickets` table; Posh buyers NOT auto-created as users |

---

*Document status: v3.0 complete. Next review: after B3 completes (admin parity). X2-B will assess B0 re-run verdict, B1 unblocking, and C3 sequencing.*
