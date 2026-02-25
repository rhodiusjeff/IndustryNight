# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Industry Night is a mobile app + companion website for discovering, promoting, and managing industry night events (hair stylists, makeup artists, photographers, videographers, producers, directors — creative workers). The mobile app serves operational users making connections; the website handles administrative functions.

## Tech Stack

- **Mobile App:** Flutter/Dart (iOS first, Android later) — `packages/mobile-app`
- **Web Admin:** Flutter/Dart for web — `packages/web-app`
- **Shared Library:** Flutter/Dart package with models, API clients, constants — `packages/shared`
- **Backend API:** Node.js + Express + TypeScript — `packages/api`
- **Database:** PostgreSQL 15 on AWS RDS (via `pg` library, no ORM)
- **Authentication:** Phone number + SMS verification code (passwordless), JWT access/refresh tokens
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
  mobile-app/                       # Mobile app (iOS/Android)
  web-app/                          # Admin web dashboard
  database/                         # Schema migrations and seeds
.github/workflows/
  api.yml                           # API CI/CD
  mobile.yml                        # Mobile CI
  web.yml                           # Web CI
```

## Database

PostgreSQL 15 on RDS. Schema in `packages/database/migrations/001_initial_schema.sql`.

### Enum types
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
| `users` | Core user profiles | — |
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
| `/admin` | routes/admin.ts | Admin dashboard endpoints (users, stats) |

### Middleware
- `authenticate` (`middleware/auth.ts`) — verifies JWT, sets `req.user` with `{ userId, role, type }`
- `requireAdmin` (`middleware/admin.ts`) — checks `role` is in `ADMIN_ROLES` (`['platformAdmin']`)
- `requirePlatformAdmin` (`middleware/admin.ts`) — checks `role === 'platformAdmin'` exactly
- `validate` (`middleware/validation.ts`) — Zod schema validation for req body/query/params

### Services
- `sms.ts` — Twilio SMS; exports `twilioAvailable` boolean. If Twilio not configured, `sendVerificationCode` is a no-op
- `email.ts` — AWS SES email
- `posh.ts` — Posh ticketing integration

## Mobile App (packages/mobile-app)

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

## Web Admin (packages/web-app)

Admin dashboard for platform operators. Features:
- `auth` — admin login screen
- `dashboard` — stats overview
- `users` — user list, detail, add user (with role dropdown)
- `events` — event list, create, detail
- `sponsors` — sponsor management, discount management
- `vendors` — vendor management
- `moderation` — post moderation, announcements
- `settings` — admin settings

State: `AdminState` provider in `lib/providers/admin_state.dart`

## Shared Package (packages/shared)

### Models (lib/models/) — all use `@JsonSerializable(fieldRename: FieldRename.snake)`
- `User`, `SocialLinks` (user.dart)
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
- `AuthApi` — auth endpoints (requestCode, verifyCode, refreshToken, logout, getCurrentUser, deleteAccount)
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
| `scripts/db-reset.js` | Full DB reset (drop all, re-run migrations + seeds) | `DB_PASSWORD=xxx node scripts/db-reset.js [--skip-k8s] [--yes]` |
| `scripts/db-scrub-user.js` | Delete specific users by phone | `DB_PASSWORD=xxx node scripts/db-scrub-user.js [--skip-k8s] [--yes] +15551234567` |
| `scripts/maintenance.sh` | Toggle k8s maintenance mode | `./scripts/maintenance.sh on/off` |
| `scripts/setup-local.sh` | Local dev environment setup | `./scripts/setup-local.sh` |

DB scripts use `pg` from `packages/api/node_modules` (no separate install needed). They auto-start kubectl port-forward unless `--skip-k8s` is passed.

## Development

### Running locally
```bash
# API (needs port-forward to RDS or local PG)
cd packages/api && npm run dev

# Mobile (iOS simulator)
cd packages/mobile-app && flutter run

# Web admin
cd packages/web-app && flutter run -d chrome
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
- Fonts: Space Grotesk downloaded to `packages/mobile-app/assets/fonts/`

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

- **Phone-based identity:** Users authenticate via SMS code sent to phone number — no passwords
- **Dual-platform Flutter:** Single Flutter codebase targets mobile (iOS first) and web admin
- **Role separation:** Mobile app for end users; web for platform admins
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
