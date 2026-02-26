# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Industry Night is a platform for discovering, promoting, and managing industry night events (hair stylists, makeup artists, photographers, videographers, producers, directors — creative workers). It consists of two apps with a shared backend:

- **Social App** — for creative workers attending events, making QR-code connections, browsing the community feed. Mobile-first (iOS, Android), with web planned.
- **Admin App** — for platform operators managing events, sponsors, vendors, users, and moderation. Web-first, with limited mobile (field ops) planned.

## Tech Stack

- **Social App:** Flutter/Dart (iOS, Android, Web) — `packages/social-app`
- **Admin App:** Flutter/Dart (Web, iOS, Android) — `packages/admin-app`
- **Shared Library:** Flutter/Dart package with models, API clients, constants — `packages/shared`
- **Backend API:** Node.js + Express + TypeScript — `packages/api`
- **Database:** PostgreSQL 15 on AWS RDS (via `pg` library, no ORM)
- **Authentication:** Phone + SMS OTP for social users; email/password for admin users. JWT access/refresh tokens with `tokenFamily` claim.
- **SMS:** Twilio (optional — dev mode returns code in API response)
- **Cloud:** AWS (EKS, ECR, RDS, S3, SES, ALB)
- **Validation:** Zod (backend), Equatable + json_annotation (Flutter)

## Project Structure

```
CLAUDE.md                           # This file
docs/                               # Project memory and documentation
  industry_night_app_developer_context_handoff.md  # Full product requirements
  requirements.md                   # Feature requirements
  implementation_plan.md            # Implementation roadmap
  aws_architecture.md               # AWS infra design
  aws_setup_commands.md             # AWS provisioning commands
  app_creative_direction.md         # UI/UX creative direction
  app_rationale_treatise.md         # Product rationale
  open_questions.md                 # Open design questions
scripts/                            # Operational scripts (Node.js + bash)
  db-reset.js                       # Full database reset (drops all, re-runs migrations + seeds)
  db-scrub-user.js                  # Delete specific users by phone number
  maintenance.sh                    # Toggle k8s maintenance mode
  setup-local.sh                    # Local dev environment setup
  run-api.sh / run-mobile.sh / run-web.sh / debug-api.sh
infrastructure/
  eks/cluster.yaml                  # EKS cluster definition
  k8s/                              # Kubernetes manifests
    namespace.yaml                  # industrynight namespace
    deployment.yaml                 # API deployment + HPA (2-10 replicas)
    service.yaml                    # ClusterIP service
    secrets.yaml                    # Secret template
    ingress.yaml                    # ALB ingress for api.industrynight.net
packages/
  api/                              # Express API server
  shared/                           # Shared Flutter/Dart package
  social-app/                       # Social networking app (iOS, Android, Web)
  admin-app/                        # Admin dashboard app (Web, iOS, Android)
  database/                         # Schema migrations and seeds
.github/workflows/
  api.yml                           # API CI/CD
  mobile.yml                        # Mobile CI
  web.yml                           # Web CI
```

## Database

PostgreSQL 15 on RDS. Schema in `packages/database/migrations/001_initial_schema.sql`.

### Enum types
- `admin_role`: `platformAdmin`
- `user_role`: `user`, `venueStaff`, `platformAdmin`
- `user_source`: `app`, `posh`, `admin`
- `verification_status`: `unverified`, `pending`, `verified`, `rejected`
- `event_status`: `draft`, `published`, `cancelled`, `completed`
- `ticket_status`: `purchased`, `checkedIn`, `cancelled`, `refunded`
- `post_type`: `general`, `collaboration`, `job`, `announcement`
- `audit_action`: `create`, `update`, `delete`, `login`, `logout`, `verify`, `reject`, `ban`, `unban`, `checkin`

### Tables
| Table | Purpose | User FK behavior |
|-------|---------|-----------------|
| `admin_users` | Admin user accounts (email/password) | — |
| `users` | Social user profiles | — |
| `verification_codes` | SMS login codes (phone is PK) | Manual cleanup |
| `specialties` | Reference data (admin-managed) | — |
| `venues` | Event locations | — |
| `events` | Industry night events | — |
| `tickets` | Event tickets (Posh integration) | CASCADE |
| `connections` | QR-scan mutual connections | CASCADE |
| `posts` | Community feed | CASCADE |
| `post_comments` | Comments on posts | CASCADE |
| `post_likes` | Post likes | CASCADE |
| `audit_log` | System audit trail | SET NULL (preserves history) |
| `analytics_connections_daily` | Anonymized connection stats | — |
| `analytics_users_daily` | Anonymized user stats | — |
| `analytics_events` | Event performance | CASCADE |
| `analytics_influence` | Network influence scores | CASCADE |
| `data_export_requests` | GDPR/CCPA export tracking | CASCADE |

**Key:** Deleting a user via `DELETE FROM users WHERE id = $1` cascades to all user data except `audit_log` (SET NULL) and `verification_codes` (must delete manually by phone first).

## API (packages/api)

### Environment Variables

Required: `JWT_SECRET` (min 32 chars)

Optional (with defaults):
- `NODE_ENV` (development), `PORT` (3000)
- `DB_HOST` (localhost), `DB_PORT` (5432), `DB_NAME` (industrynight), `DB_USER` (postgres), `DB_PASSWORD`
- `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_PHONE_NUMBER` — if missing, SMS is skipped and devCode returned in response
- `TWILIO_VERIFY_SERVICE_SID` — if set (with account SID + auth token), uses Twilio Verify API for OTP instead of Messages API
- `AWS_REGION`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `S3_BUCKET`, `SES_FROM_EMAIL`
- `POSH_WEBHOOK_SECRET`
- `CORS_ORIGINS` (comma-separated)

### Routes

| Mount | File | Key endpoints |
|-------|------|---------------|
| `/health` | index.ts | `GET /health` |
| `/specialties` | index.ts | `GET /specialties` (public) |
| `/auth` | routes/auth.ts | `POST /request-code`, `POST /verify-code`, `POST /refresh`, `POST /logout`, `GET /me`, `DELETE /me` |
| `/users` | routes/users.ts | `GET /` (search), `GET /:id`, `PATCH /me`, `GET /me/qr`, `DELETE /:id` (admin) |
| `/events` | routes/events.ts | CRUD + attendee management |
| `/connections` | routes/connections.ts | QR-scan connections |
| `/posts` | routes/posts.ts | Community feed CRUD + comments/likes |
| `/sponsors` | routes/sponsors.ts | Sponsor management |
| `/vendors` | routes/vendors.ts | Vendor management |
| `/discounts` | routes/discounts.ts | Discount/perk management |
| `/webhooks` | routes/webhooks.ts | Posh webhook receiver |
| `/admin/auth` | routes/admin-auth.ts | `POST /login`, `POST /refresh`, `GET /me`, `POST /logout` |
| `/admin` | routes/admin.ts | Admin dashboard endpoints (users, stats) |

### Middleware
- `authenticateAdmin` (`middleware/admin-auth.ts`) — verifies JWT with `tokenFamily: 'admin'`, used on all `/admin` routes
- `authenticate` (`middleware/auth.ts`) — verifies JWT, sets `req.user` with `{ userId, role, type }`
- `requireAdmin` (`middleware/admin.ts`) — checks `role` is in `ADMIN_ROLES` (`['platformAdmin']`)
- `requirePlatformAdmin` (`middleware/admin.ts`) — checks `role === 'platformAdmin'` exactly
- `validate` (`middleware/validation.ts`) — Zod schema validation for req body/query/params

### Services
- `sms.ts` — Twilio SMS; exports `twilioAvailable` boolean. If Twilio not configured, `sendVerificationCode` is a no-op
- `email.ts` — AWS SES email
- `posh.ts` — Posh ticketing integration

## Social App (packages/social-app)

### Features (lib/features/)
| Feature | Screens | Description |
|---------|---------|-------------|
| `auth` | `phone_entry_screen`, `sms_verify_screen` | Phone-based login with devCode auto-fill |
| `onboarding` | `profile_setup_screen` | Name, specialties, bio setup |
| `events` | `events_list_screen`, `event_detail_screen`, `activation_code_screen` | Browse and check into events |
| `networking` | `connections_list_screen`, `my_qr_screen`, `qr_scanner_screen` | QR-scan connections |
| `community` | `community_feed_screen`, `create_post_screen`, `post_detail_screen` | Community feed |
| `search` | `search_screen`, `user_profile_screen` | User discovery |
| `profile` | `my_profile_screen`, `settings_screen` | Profile management |
| `perks` | `perks_screen`, `sponsor_detail_screen` | Sponsor perks/discounts |

### Key files
- `lib/main.dart` — entry point, creates AppState + MaterialApp
- `lib/app.dart` — MaterialApp.router with GoRouter (created once in initState, NOT rebuilt on notifyListeners)
- `lib/config/routes.dart` — GoRouter config with auth redirects (`refreshListenable: appState`)
- `lib/providers/app_state.dart` — global state via ChangeNotifier (auth, profile, loading, errors)
- `lib/shared/theme/app_theme.dart` — dark theme

### State management
- `Provider` + `ChangeNotifier` pattern
- `AppState` is the single global provider
- API clients are `late final` on AppState: `authApi`, `usersApi`, `eventsApi`, `connectionsApi`, `postsApi`

## Admin App (packages/admin-app)

Admin dashboard for platform operators. Authentication: email/password (separate `admin_users` table).

Features:
- `auth` — admin login screen
- `dashboard` — stats overview
- `users` — user list, detail, add user (with role dropdown)
- `events` — event list, create, detail
- `sponsors` — sponsor management, discount management
- `vendors` — vendor management
- `moderation` — post moderation, announcements
- `settings` — admin settings

State: `AdminState` provider in `lib/providers/admin_state.dart`
- Properties: `currentAdmin` (AdminUser?), `isLoggedIn`, `isLoading`, `error`
- API clients: `adminAuthApi` (AdminAuthApi), `adminApi` (AdminApi)
- Auth: `login(email, password)`, `logout()`, `initialize()` (token restore + refresh)

## Shared Package (packages/shared)

### Models (lib/models/) — use `@JsonSerializable(fieldRename: FieldRename.snake)` except where noted
- `AdminUser` (admin_user.dart) — admin dashboard user (email/password auth). Uses `@JsonSerializable()` (camelCase) because the admin-auth API returns camelCase keys.
- `User`, `SocialLinks` (user.dart) — social app user (phone OTP auth)
- `Event` (event.dart)
- `Connection` (connection.dart)
- `Ticket` (ticket.dart)
- `Post`, `PostComment` (post.dart)
- `Sponsor` (sponsor.dart)
- `Vendor` (vendor.dart)
- `Discount` (discount.dart)

After modifying any model, regenerate `.g.dart` files:
```bash
cd packages/shared && dart run build_runner build --delete-conflicting-outputs
```

### API Clients (lib/api/)
- `ApiClient` — base HTTP client with token management and debug logging
- `AdminAuthApi` — admin auth endpoints (login, refreshToken, getCurrentAdmin, logout)
- `AuthApi` — social auth endpoints (requestCode, verifyCode, refreshToken, logout, getCurrentUser, deleteAccount)
- `UsersApi` — user search, profile updates, photo upload
- `EventsApi` — event listing and details
- `ConnectionsApi` — connection management
- `PostsApi` — community feed
- `AdminApi` — admin dashboard endpoints

### Constants (lib/constants/)
- `verification_status.dart` — `VerificationStatus` enum, `UserRole` enum, `UserSource` enum
- `specialties.dart` — specialty display names mapping

### Utils (lib/utils/)
- `validators.dart` — phone number validation and normalization
- `formatters.dart` — display formatting helpers
- `storage.dart` — `SecureStorage` wrapper for flutter_secure_storage (tokens, userId, phone)

## Infrastructure

### AWS
- **Region:** us-east-1
- **EKS cluster:** industrynight (defined in `infrastructure/eks/cluster.yaml`)
- **ECR repo:** `047593684855.dkr.ecr.us-east-1.amazonaws.com/industrynight-api`
- **RDS:** PostgreSQL 15
- **Domain:** `api.industrynight.net` (ALB ingress with ACM SSL)
- **AWS Profile:** `industrynight-admin`

### Kubernetes
- **Namespace:** `industrynight`
- **Deployment:** `industrynight-api` (2 replicas min, 10 max via HPA)
- **Resources:** 256Mi-512Mi memory, 250m-500m CPU per pod
- **Health:** liveness + readiness probes on `/health`
- **Secrets:** `industrynight-secrets` (DB_PASSWORD, JWT_SECRET, Twilio creds, etc.)
- **DB Proxy:** `db-proxy` pod for port-forwarding: `kubectl port-forward pod/db-proxy 5432:5432 -n industrynight`

### Deployment workflow
```bash
# 1. Authenticate
AWS_PROFILE=industrynight-admin aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin 047593684855.dkr.ecr.us-east-1.amazonaws.com

# 2. Build
cd packages/api
docker build --platform linux/amd64 -t 047593684855.dkr.ecr.us-east-1.amazonaws.com/industrynight-api:latest .

# 3. Push
docker push 047593684855.dkr.ecr.us-east-1.amazonaws.com/industrynight-api:latest

# 4. Rollout
AWS_PROFILE=industrynight-admin kubectl rollout restart deployment/industrynight-api -n industrynight
AWS_PROFILE=industrynight-admin kubectl rollout status deployment/industrynight-api -n industrynight
```

## Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `scripts/seed-admin.js` | Create initial admin user | `node scripts/seed-admin.js --email x --name y --password z` |
| `scripts/db-reset.js` | Full DB reset (drop all, re-run migrations + seeds) | `DB_PASSWORD=xxx node scripts/db-reset.js [--skip-k8s] [--yes]` |
| `scripts/db-scrub-user.js` | Delete specific users by phone | `DB_PASSWORD=xxx node scripts/db-scrub-user.js [--skip-k8s] [--yes] +15551234567` |
| `scripts/maintenance.sh` | Toggle k8s maintenance mode | `./scripts/maintenance.sh on/off` |
| `scripts/setup-local.sh` | Local dev environment setup | `./scripts/setup-local.sh` |

DB scripts use `pg` from `packages/api/node_modules` (no separate install needed). They auto-start kubectl port-forward unless `--skip-k8s` is passed.

### Executive Brief Generator

`scripts/generate-exec-brief.py` generates a 13-slide PowerPoint presentation at `docs/Industry Night - Executive Brief.pptx`. Dark theme, purple accents, widescreen (16:9).

**Slides:** Title, What Is IN, How It Works, Timeline, Codebase Metrics, Built (Backend/DB), Built (Apps), Infrastructure, Architecture Decisions, Implementation Status, Current WIP + Next, Tech Debt, Summary.

**To regenerate:**
```bash
python3 -m venv /tmp/pptx-env && source /tmp/pptx-env/bin/activate && pip install python-pptx
python3 scripts/generate-exec-brief.py
```

**To update for a weekly brief:** Edit the data values directly in `scripts/generate-exec-brief.py`:
- `REPORT_DATE` / `PERIOD` — auto-set from `date.today()`, update `PERIOD` string
- Slide 4 (Timeline) — add new milestones to the `milestones` list
- Slide 5 (Metrics) — update `stats` and `stats2` number values, update `add_table_data` LOC counts
- Slide 6-7 (What's Built) — add new bullet items to card text frames
- Slide 10 (Status) — update `phases` list statuses and colors (`GREEN`=done, `AMBER`=partial, `ACCENT_LIGHT`=in progress, `MID_GRAY`=not started)
- Slide 11 (WIP/Next) — update current branch work and next items
- Slide 12 (Tech Debt) — add/remove rows from the table data

The companion markdown brief is at `docs/executive-brief.md`.

### COOP Scripts (scripts/coop/)

Infrastructure lifecycle management — tear down AWS to save costs, rebuild from scratch, backup/restore data. Full documentation in `docs/coop.md`.

| Script | Purpose | Usage |
|--------|---------|-------|
| `scripts/coop/coop.sh` | Controller (single entry point) | `./scripts/coop/coop.sh <command>` |
| `scripts/coop/config.sh` | Shared constants and helpers | Sourced by other scripts |
| `scripts/coop/infra-status.sh` | Color-coded AWS resource status | `./scripts/coop/coop.sh status` |
| `scripts/coop/db-export.sh` | Database backup (pg_dump + per-table) | `./scripts/coop/coop.sh export` |
| `scripts/coop/db-import.sh` | Database restore (full or selective) | `./scripts/coop/coop.sh import <dir>` |
| `scripts/coop/infra-teardown.sh` | Tear down EKS + RDS (~$160→$3/mo) | `./scripts/coop/coop.sh teardown` |
| `scripts/coop/infra-rebuild.sh` | Rebuild all infra from scratch | `./scripts/coop/coop.sh rebuild` |

Key commands:
```bash
./scripts/coop/coop.sh status                                    # What's running? What's it costing?
./scripts/coop/coop.sh teardown                                  # Export data + tear down (saves ~$155/mo)
./scripts/coop/coop.sh rebuild --import backups/YYYY-MM-DD_HHMMSS  # Rebuild + restore data
```

## Development

### Running locally
```bash
# API (needs port-forward to RDS or local PG)
cd packages/api && npm run dev

# Social app (iOS simulator)
cd packages/social-app && flutter run

# Admin app (web)
cd packages/admin-app && flutter run -d chrome
```

### DevCode system (simulator testing without Twilio)
When `TWILIO_VERIFY_SERVICE_SID` is not set (or Twilio credentials are missing entirely):
1. Backend generates its own 6-digit code, stores it in `verification_codes` table
2. Returns `{ message: "Verification code sent", devCode: "123456" }` on `/auth/request-code`
3. Flutter `phone_entry_screen` captures `devCode` from response
4. Passes it to `sms_verify_screen` which auto-fills the code field
5. Auto-submits after a short delay

When `TWILIO_VERIFY_SERVICE_SID` is set (production):
- Twilio Verify API handles code generation, delivery, and verification
- No codes stored in local DB; no `devCode` in response

### iOS setup
- Deployment target: iOS 14.0
- Platform created via `flutter create --platforms=ios`
- Fonts: Inter downloaded to `packages/social-app/assets/fonts/`

## Key Gotchas

1. **snake_case JSON:** PostgreSQL returns `snake_case` column names. All Dart `@JsonSerializable()` annotations MUST include `fieldRename: FieldRename.snake`. Without it, `DateTime.parse(json['createdAt'])` throws because the key is actually `created_at`.

2. **GoRouter singleton:** `GoRouter` must be created once in `initState()` of the app widget, NOT inside a `Consumer<AppState>` that rebuilds on every `notifyListeners()`. GoRouter's `refreshListenable` parameter handles auth state re-evaluation.

3. **Twilio Verify:** When `TWILIO_VERIFY_SERVICE_SID` is set, the Twilio Verify API handles OTP code generation, delivery, and checking. Without it, SMS is a no-op and the verification code is returned in the API response (devCode mode for simulator testing).

4. **User deletion cascade:** `DELETE FROM users WHERE id = $1` cascades to all related tables. But you MUST delete `verification_codes` separately first (keyed by phone, not user ID).

5. **Flutter theme classes:** Use `CardThemeData` (not `CardTheme`), `DialogThemeData` (not `DialogTheme`). Use `Color.withValues(alpha: 0.5)` (not `withOpacity`).

6. **build_runner:** After changing any model in `packages/shared/lib/models/`, run: `cd packages/shared && dart run build_runner build --delete-conflicting-outputs`

## Roles

| Role | Value | Admin middleware | Permissions |
|------|-------|-----------------|-------------|
| User | `user` | Denied | Browse events, make connections, post to feed |
| Venue Staff | `venueStaff` | Denied | Check in attendees at venues |
| Platform Admin | `platformAdmin` | Allowed | Full access: user management, moderation, events, settings |

`requireAdmin` and `requirePlatformAdmin` both currently gate on `platformAdmin` only. `ADMIN_ROLES` is an array to allow future role additions.

## Architecture Decisions

- **Phone-based identity:** Social users authenticate via SMS code sent to phone number — no passwords
- **Email-based admin auth:** Admin users authenticate via email/password, stored in a separate `admin_users` table
- **Two-app architecture:** Social app (mobile-first) and Admin app (web-first), each targeting iOS, Android, and Web
- **Shared package:** Both apps share `packages/shared` for models, API clients, and utilities
- **JWT token families:** Tokens include `tokenFamily: 'social'|'admin'` to prevent cross-app token use
- **No ORM:** Direct SQL via `pg` library with parameterized queries
- **CASCADE deletes:** All user FKs use CASCADE except audit_log (SET NULL to preserve history)
- **Open registration:** First SMS verify auto-creates user if phone not found
- **QR networking:** Connections are instant and mutual on QR scan (no request/accept flow)

## Documentation

The `docs/` directory is the project memory:
- `industry_night_app_developer_context_handoff.md` — Full product requirements and MVP scope
- `requirements.md` — Feature requirements
- `implementation_plan.md` — Implementation roadmap
- `aws_architecture.md` — AWS infrastructure design
- `aws_setup_commands.md` — AWS provisioning commands
- `app_creative_direction.md` — UI/UX creative direction
- `app_rationale_treatise.md` — Product rationale
- `open_questions.md` — Open design questions
- `coop.md` — COOP scripts user manual (teardown/rebuild/backup/restore)

## Context Refresh & Knowledge Transfer

**Important for Claude:** The project owner may return after extended breaks and will have lost context on what was built, why decisions were made, and how the operational tooling works. When this happens:

1. **Don't assume knowledge.** If the user asks about infrastructure, COOP scripts, deployment, or any operational topic, start by pointing them to the relevant docs (`docs/coop.md`, `docs/aws_architecture.md`, etc.) and offer a walkthrough rather than jumping straight into commands.

2. **Offer a refresher.** If the user seems uncertain or asks broad questions like "how does this work again?" or "what do we have?", proactively suggest walking through the system together. A good sequence:
   - Run `./scripts/coop/coop.sh status` to show current AWS state
   - Review what's running, what's hibernated, what it costs
   - Walk through any scripts or systems relevant to what they want to do

3. **Pending knowledge transfer items.** The following topics should be turned into a structured lesson plan when the user is ready. The goal is hands-on understanding, not just documentation:
   - **AWS/EKS/K8s fundamentals:** What the cluster is, what pods/deployments/services/ingress do, how kubectl works, what eksctl manages vs what kubectl manages
   - **COOP system:** How teardown/rebuild works, what gets deleted vs preserved, how database backups work, how to verify a restore
   - **Database operations:** Migrations system (`_migrations` table, `migrate.sh`), how schema changes propagate, the FK cascade design, how to safely modify the schema
   - **CI/CD pipeline:** What the GitHub Actions workflows do, how code gets from PR to production, what's automated vs manual. **Known gaps:** no migration runner in deploy, no API tests, health check doesn't verify DB connectivity
   - **Deployment process:** Docker build, ECR push, K8s rollout, how to debug a failed deploy, how to rollback
   - **Local development:** How to run everything locally, devCode system, port-forwarding to RDS

4. **Known technical debt / future work:**
   - CI/CD: Add K8s Job pre-deploy migration runner to `api.yml`
   - CI/CD: Write API tests (Jest is configured but no tests exist)
   - CI/CD: Add DB connectivity check to `/health` endpoint
   - CI/CD: Add post-deploy smoke tests
   - Migrations: Create down-migration files for rollback capability

## Testing Plan

**Trigger phrase:** "tell me about Flutter app testing" or "let's build the test suite"

### API Tests (Jest) — Priority: build after admin app login is working
Start with the flows where a silent regression would corrupt data or lock users out:
1. **Auth flow:** request-code → verify-code → token issued → refresh → logout
2. **User deletion cascade:** delete user → verify all FK tables cleaned, audit_log preserved (SET NULL), verification_codes cleaned separately
3. **Admin auth:** login → JWT with `tokenFamily: 'admin'` → admin routes accessible → social token rejected on admin routes
4. **Role-based access:** user token can't hit admin routes, admin token can't hit social routes
5. **Token family isolation:** social tokens rejected by admin middleware, admin tokens rejected by social middleware

Jest is already configured in `packages/api` — no test files exist yet. Tests should run against a real test database (not mocks) to verify actual SQL behavior including CASCADE deletes.

### Flutter Widget Tests — Priority: build alongside API tests
Per-screen tests for form validation, state transitions, and navigation. Focus on:
- **Admin app:** Login form validation, auth state transitions, route guards
- **Social app:** Profile setup validation, event list rendering, connection flow state

### Physical/Manual Testing — requires humans or future embodied agents
Cannot be automated — requires real devices in physical proximity:
- QR scan → mutual connection created (two devices)
- Event check-in with activation code (at venue)
- Full onboarding flow on physical device
- Push notifications, deep links, camera permissions

### What's explicitly NOT tested
- ~~devCode system~~ — deprecated, not worth testing. Physical devices used for mobile testing.
