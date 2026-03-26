# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Industry Night is a platform for discovering, promoting, and managing industry night events (hair stylists, makeup artists, photographers, videographers, producers, directors — creative workers). It consists of two apps with a shared backend:

- **Social App** — for creative workers attending events, making QR-code connections, browsing the community feed. Mobile-first (iOS, Android), with web planned.
- **Admin App** — for platform operators managing events, customers, products, users, and moderation. Web-first, with limited mobile (field ops) planned.

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
- **File uploads:** multer (backend, memory storage) + dart:html FileReader (Flutter web — file_picker silently fails on web)

## Project Structure

```
CLAUDE.md                           # This file
docs/                               # Project memory and documentation
  architecture/                     # Infrastructure & technical design
    aws_architecture.md             # AWS infra design
    aws_setup_commands.md           # AWS provisioning commands
  executive/                        # Stakeholder-facing decks & PDFs
    executive-brief.md              # Executive brief (markdown)
    *.pptx, *.pdf                   # Slide decks and PDF reports
  product/                          # Requirements, plans, design direction
    requirements.md                 # Feature requirements
    implementation_plan.md          # Implementation roadmap
    industry_night_app_developer_context_handoff.md  # Full product requirements
    app_creative_direction.md       # UI/UX creative direction
    app_rationale_treatise.md       # Product rationale
    open_questions.md               # Open design questions
  analysis/                         # Deep-dive reviews & analyses
    social_network_analysis.md      # Social network analysis (technical)
    social_network_analysis_product_owner.md  # Social network analysis (non-technical)
    adversarial_review.md           # Requirements vs. reality audit
    implementation_audit.md         # Implementation audit
  guides/                           # Operational manuals
    scripts_user_guide.md           # Scripts usage guide
    coop.md                         # COOP teardown/rebuild/backup manual
  archive/                          # Historical document versions
scripts/                            # Operational scripts (Node.js + bash)
  migrate.js                        # Apply pending DB migrations (safe to re-run)
  db-reset.js                       # Full database reset (drops all, re-runs migrations + seeds)
  db-scrub-user.js                  # Delete specific users by phone number
  db-uncheckin.js                   # Reset check-in status for dev/testing
  db-unconnect.js                   # Delete connections for dev/testing
  deploy-api.sh                     # Build, push Docker image to ECR, roll out to EKS
  deploy-admin.sh                   # Build Flutter web, sync to S3, invalidate CloudFront
  pf-db.sh                          # Manage kubectl port-forward tunnel to RDS
  maintenance.sh                    # Toggle k8s maintenance mode
  setup-local.sh                    # Local dev environment setup
  run-api.sh / run-mobile.sh / run-admin-app.sh / debug-api.sh
infrastructure/
  eks/cluster.yaml.template         # EKS cluster template (__PLACEHOLDER__ tokens)
  k8s/                              # Kubernetes manifest templates
    namespace.yaml                  # Namespace (templated: __NAMESPACE__, __ENVIRONMENT__)
    deployment.yaml                 # API deployment + HPA (templated)
    service.yaml                    # ClusterIP service (templated)
    secrets.yaml                    # Secret template
    ingress.yaml                    # ALB ingress (templated)
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

PostgreSQL 15 on RDS. Schema built from sequential migrations in `packages/database/migrations/`.

### Migrations
| File | Description |
|------|-------------|
| `001_baseline_schema.sql` | Complete schema: all tables, enums, triggers, indexes (consolidated from original 001-004) |

Future migrations start at `002_*.sql`. Archived originals are in `packages/database/migrations/archive/`.

### Enum types
- `admin_role`: `platformAdmin`
- `user_role`: `user`, `venueStaff`, `platformAdmin`
- `user_source`: `app`, `posh`, `admin` — note: `posh` is currently unused since Posh webhook does NOT auto-create users
- `verification_status`: `unverified`, `pending`, `verified`, `rejected`
- `event_status`: `draft`, `published`, `cancelled`, `completed`
- `ticket_status`: `purchased`, `checkedIn`, `cancelled`, `refunded`
- `post_type`: `general`, `collaboration`, `job`, `announcement`
- `audit_action`: `create`, `update`, `delete`, `login`, `logout`, `verify`, `reject`, `ban`, `unban`, `checkin`
- `product_type`: `sponsorship`, `vendor_space`, `data_product`
- `customer_product_status`: `active`, `expired`, `cancelled`, `pending`
- `sponsorship_tier`: `bronze`, `silver`, `gold`, `platinum`
- `vendor_category`: `food`, `beverage`, `equipment`, `service`, `venue`, `other`
- `redemption_method`: `self_reported`, `code_entry`, `qr_scan`

### Tables
| Table | Purpose | User FK behavior |
|-------|---------|-----------------|
| `admin_users` | Admin user accounts (email/password) | — |
| `users` | Social user profiles | — |
| `verification_codes` | SMS login codes (phone is PK) | Manual cleanup |
| `specialties` | Reference data (admin-managed) | — |
| `venues` | Legacy venue records (new events use venue_name/venue_address text fields directly) | — |
| `events` | Industry night events (venue_name + venue_address as text; no image_url — use event_images) | — |
| `event_images` | Up to 5 images per event; sort_order 0 = hero image | CASCADE |
| `markets` | Geographic/categorical markets (e.g., "Atlanta", "NYC") — events assigned to one market | — |
| `customer_contacts` | Contact persons for a customer (name, title, phone, email) | CASCADE |
| `customer_media` | Brand assets (logos, photos) for a customer — stored in S3 | CASCADE |
| `customers` | Businesses with commercial relationships (replaces sponsors + vendors) | — |
| `products` | Catalog of what IN sells: sponsorships, vendor space, data products | — |
| `customer_products` | Purchases / active relationships (customer + product + optional event) | customer: CASCADE, product: RESTRICT |
| `discounts` | Perks offered by customers to app users | CASCADE |
| `discount_redemptions` | Tracks when users claim perks ("I Used This") — Tier 2 revenue data | CASCADE |
| `posh_orders` | Posh webhook purchases — the canonical ticket for Posh buyers | event: SET NULL, user: SET NULL |
| `tickets` | Walk-in / manual check-in tickets (non-Posh) | CASCADE |
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
| `_migrations` | Migration tracking (filename → applied_at) | — |

**Key:** Deleting a user via `DELETE FROM users WHERE id = $1` cascades to all user data except `audit_log` (SET NULL) and `verification_codes` (must delete manually by phone first).

### Event publishing gate (enforced in PATCH /admin/events/:id)
An event cannot be published unless:
1. `posh_event_id` is set (required to match incoming Posh webhooks)
2. `venue_name` is set
3. At least 1 image exists in `event_images`
4. `market_id` is set (required to categorize event by market; error: `"Cannot publish: Market must be assigned"`)

## API (packages/api)

### Environment Variables

Required: `JWT_SECRET` (min 32 chars)

Optional (with defaults):
- `NODE_ENV` (development), `PORT` (3000)
- `DB_HOST` (localhost), `DB_PORT` (5432), `DB_NAME` (industrynight), `DB_USER` (postgres), `DB_PASSWORD`
- `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_PHONE_NUMBER` — if missing, SMS is skipped (dev-safe)
- `TWILIO_VERIFY_SERVICE_SID` — if set (with account SID + auth token), uses Twilio Verify API for OTP
- `AUTH_ALLOW_DEV_OTP_FALLBACK` (`false` by default) — when `true`, allows local dev OTP fallback (`devCode`) if Twilio Verify is unavailable
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
| `/markets` | routes/markets.ts | `GET /markets` — public list of active markets |
| `/sponsors` | routes/sponsors.ts | Social-facing: active customers with sponsorship products |
| `/discounts` | routes/discounts.ts | Social-facing: active discounts with customer info + redemption |
| `/webhooks` | routes/webhooks.ts | Posh webhook receiver (`POST /posh`) |
| `/admin/auth` | routes/admin-auth.ts | `POST /login`, `POST /refresh`, `GET /me`, `POST /logout` |
| `/admin` | routes/admin.ts | All admin dashboard endpoints (see below) |

### Admin API endpoints (routes/admin.ts)
| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/admin/dashboard` | Stats: users, events, connections, posts |
| `GET` | `/admin/users` | List users (filter by role, verificationStatus, query) |
| `PATCH` | `/admin/users/:id` | Update role, banned, verificationStatus |
| `POST` | `/admin/users` | Add user (phone, name, email, role) |
| `GET` | `/admin/events` | List events with hero_image_url, image_count, partner_count |
| `GET` | `/admin/events/:id` | Event detail with full images[] and partners[] arrays |
| `POST` | `/admin/events` | Create event (name, startTime, endTime, venueName, venueAddress, description, capacity, poshEventId) |
| `PATCH` | `/admin/events/:id` | Update event; enforces publish gate when status → published |
| `DELETE` | `/admin/events/:id` | Delete event (draft status only) |
| `POST` | `/admin/events/:id/images` | Upload image (multipart/form-data, field: image, max 5 per event) |
| `PATCH` | `/admin/events/:id/images/:imageId/hero` | Set image as hero (sort_order swap to 0) |
| `DELETE` | `/admin/events/:id/images/:imageId` | Delete image (removes from S3 + DB; auto-promotes next hero) |
| `GET` | `/admin/images` | Image catalog — all images across all events (with event_name) |
| `DELETE` | `/admin/images/:imageId` | Delete image globally |
| `POST` | `/admin/events/:id/partners` | Add customer+product to event |
| `DELETE` | `/admin/events/:id/partners/:cpId` | Remove partner from event |
| `GET` | `/admin/customers` | List customers (filter: `?q=`, `?hasProductType=`) |
| `GET` | `/admin/customers/:id` | Customer detail with products[], discounts[], redemption stats |
| `POST` | `/admin/customers` | Create customer |
| `PATCH` | `/admin/customers/:id` | Update customer |
| `DELETE` | `/admin/customers/:id` | Delete customer (CASCADE to products + discounts) |
| `GET` | `/admin/products` | List product catalog (filter: `?type=`, `?isStandard=`) |
| `POST` | `/admin/products` | Create product definition |
| `PATCH` | `/admin/products/:id` | Update product definition |
| `DELETE` | `/admin/products/:id` | Delete product (RESTRICT if referenced) |
| `GET` | `/admin/customers/:id/products` | List customer purchases |
| `POST` | `/admin/customers/:id/products` | Record a purchase |
| `PATCH` | `/admin/customers/:id/products/:cpId` | Update purchase status/dates |
| `DELETE` | `/admin/customers/:id/products/:cpId` | Remove purchase |
| `GET` | `/admin/customers/:id/discounts` | List discounts for customer |
| `POST` | `/admin/customers/:id/discounts` | Create discount |
| `PATCH` | `/admin/customers/:id/discounts/:did` | Update discount |
| `DELETE` | `/admin/customers/:id/discounts/:did` | Delete discount |
| `GET` | `/admin/customers/:id/redemptions` | Redemption stats for customer |
| `GET` | `/admin/markets` | List all markets |
| `POST` | `/admin/markets` | Create market |
| `PATCH` | `/admin/markets/:id` | Update market |
| `GET` | `/admin/customers/:id/contacts` | List contacts for customer |
| `POST` | `/admin/customers/:id/contacts` | Add contact |
| `PATCH` | `/admin/customers/:id/contacts/:contactId` | Update contact |
| `DELETE` | `/admin/customers/:id/contacts/:contactId` | Remove contact |
| `GET` | `/admin/customers/:id/media` | List media assets for customer |
| `POST` | `/admin/customers/:id/media` | Upload media asset (multipart, sharp validation) |
| `DELETE` | `/admin/customers/:id/media/:mediaId` | Delete media asset (S3 + DB) |

### Middleware
- `authenticateAdmin` (`middleware/admin-auth.ts`) — verifies JWT with `tokenFamily: 'admin'`, used on all `/admin` routes
- `authenticate` (`middleware/auth.ts`) — verifies JWT, sets `req.user` with `{ userId, role, type }`
- `requireAdmin` (`middleware/admin.ts`) — checks `role` is in `ADMIN_ROLES` (`['platformAdmin']`)
- `requirePlatformAdmin` (`middleware/admin.ts`) — checks `role === 'platformAdmin'` exactly
- `validate` (`middleware/validation.ts`) — Zod schema validation for req body/query/params; applies parsed values (including defaults/transforms) back to req

### Services
- `sms.ts` — Twilio SMS; exports `twilioAvailable`, `sendSms(phone, message)`. Gracefully degrades in dev (console.log only).
- `email.ts` — AWS SES email; exports `sendEmail({to, subject, html, text})`, `sendWelcomeEmail`.
- `storage.ts` — S3 image upload/delete; exports `uploadImage(buffer, filename, folder)`, `deleteImage(url)`, `s3Available`. Uses `ACL: 'public-read'` for browser-accessible images. Gracefully degrades in dev (returns placeholder URL when S3 not configured).
- `posh.ts` — Posh webhook handler; processes `new_order` events, writes to `posh_orders`, sends invite SMS + email. Does NOT auto-create users.

## Social App (packages/social-app)

### Features (lib/features/)
| Feature | Screens | Description |
|---------|---------|-------------|
| `auth` | `phone_entry_screen`, `sms_verify_screen` | Phone-based login with devCode auto-fill |
| `onboarding` | `profile_setup_screen` | Name, specialties, bio setup |
| `events` | `events_list_screen`, `event_detail_screen`, `activation_code_screen` | Browse and check into events |
| `networking` | `connect_tab_screen`, `connections_list_screen`, `qr_scanner_screen` | QR-scan connections with instant connect, celebration overlay, and polling-based notifications (connect tab is center nav icon) |
| `community` | `community_feed_screen`, `create_post_screen`, `post_detail_screen` | Community feed |
| `search` | `search_screen`, `user_profile_screen` | User discovery |
| `profile` | `my_profile_screen`, `edit_profile_screen`, `settings_screen` | Profile management |
| `perks` | `perks_screen`, `sponsor_detail_screen` | Customer perks/discounts with redemption tracking |

### Key files
- `lib/main.dart` — entry point, creates AppState + MaterialApp
- `lib/app.dart` — MaterialApp.router with GoRouter (created once in initState, NOT rebuilt on notifyListeners)
- `lib/config/routes.dart` — GoRouter config with auth redirects (`refreshListenable: appState`)
- `lib/providers/app_state.dart` — global state via ChangeNotifier (auth, profile, loading, errors)
- `lib/shared/theme/app_theme.dart` — dark theme

### State management
- `Provider` + `ChangeNotifier` pattern
- `AppState` is the single global provider
- API clients are `late final` on AppState: `authApi`, `usersApi`, `eventsApi`, `connectionsApi`, `postsApi`, `perksApi`

## Admin App (packages/admin-app)

Admin dashboard for platform operators. Authentication: email/password (separate `admin_users` table).

### Features
| Feature | Screens | Description |
|---------|---------|-------------|
| `auth` | `admin_login_screen` | Email/password login |
| `dashboard` | `dashboard_screen` | Stats overview |
| `users` | `users_list_screen`, `user_detail_screen`, `add_user_screen` | Full user management |
| `events` | `events_list_screen`, `event_form_screen`, `event_detail_screen`, `image_catalog_screen` | Full event lifecycle |
| `customers` | `customers_list_screen`, `customer_form_screen`, `customer_detail_screen`, `discounts_screen` | Customer CRM + discount management |
| `products` | `product_catalog_screen`, `product_form_screen` | Product catalog management |
| `moderation` | `posts_list_screen`, `announcements_screen` | Post moderation (stub) |
| `settings` | `admin_settings_screen` | Admin settings |

### Event management screens
- **`event_form_screen.dart`** — Unified create + edit form. Pass `Event? event` (null = create mode). After create: navigates to `/events/:id`. After edit: pops back.
- **`event_detail_screen.dart`** — Full detail loaded from API on init (no `extra` needed). Inline image upload (dart:html FileReader), image preview modal, hero image selection (star icon), inline partner management (add customer+product via popup, remove via chip), status transition buttons, activation code display. Two-column layout.
- **`image_catalog_screen.dart`** — Grid of all uploaded images across all events. Multi-select + bulk delete.

### Admin app routes (lib/config/routes.dart)
| Route | Screen |
|-------|--------|
| `/login` | AdminLoginScreen |
| `/` | DashboardScreen |
| `/users` | UsersListScreen |
| `/users/add` | AddUserScreen |
| `/users/:id` | UserDetailScreen (User? via extra) |
| `/events` | EventsListScreen |
| `/events/create` | EventFormScreen() |
| `/events/:id` | EventDetailScreen(eventId) — loads from API |
| `/events/:id/edit` | EventFormScreen(event: Event? via extra) |
| `/images` | ImageCatalogScreen |
| `/customers` | CustomersListScreen |
| `/customers/add` | CustomerFormScreen() |
| `/customers/:id` | CustomerDetailScreen(customerId) — loads from API |
| `/customers/:id/edit` | CustomerFormScreen(customer: Customer? via extra) |
| `/customers/:id/discounts` | DiscountsScreen(customerId) |
| `/products` | ProductCatalogScreen |
| `/products/add` | ProductFormScreen() |
| `/products/:id/edit` | ProductFormScreen(product: Product? via extra) |
| `/moderation/posts` | PostsListScreen |
| `/moderation/announcements` | AnnouncementsScreen |
| `/settings` | AdminSettingsScreen |

### State
`AdminState` provider in `lib/providers/admin_state.dart`
- Properties: `currentAdmin` (AdminUser?), `isLoggedIn`, `isLoading`, `error`
- API clients: `adminAuthApi` (AdminAuthApi), `adminApi` (AdminApi)
- Auth: `login(email, password)`, `logout()`, `initialize()` (token restore + refresh)

## Shared Package (packages/shared)

### Models (lib/models/) — use `@JsonSerializable(fieldRename: FieldRename.snake)` except where noted
- `AdminUser` (admin_user.dart) — admin dashboard user (email/password auth). Uses `@JsonSerializable()` (camelCase) because the admin-auth API returns camelCase keys.
- `User`, `SocialLinks` (user.dart) — social app user (phone OTP auth)
- `Event` (event.dart) — includes `venueName`, `venueAddress`, `poshEventId`, `heroImageUrl`, `imageCount`, `partnerCount`, `images List<EventImage>?` (detail only), `partners List<EventPartner>?` (detail only), `copyWith`. No `imageUrl` or `venueId` dependency.
- `EventImage` (event_image.dart) — `id`, `eventId`, `url`, `sortOrder`, `uploadedAt`, `eventName?` (catalog only)
- `EventPartner` — lightweight partner summary embedded in Event (customerId, name, logoUrl, productType, tier, vendorCategory); manual fromJson
- `Connection` (connection.dart)
- `Ticket` (ticket.dart)
- `Post`, `PostComment` (post.dart)
- `Customer` (customer.dart) — unified business entity (replaces Sponsor + Vendor)
- `Product` (product.dart) — catalog item (sponsorship, vendor_space, data_product)
- `CustomerProduct` (customer_product.dart) — purchase record (customer + product + optional event)
- `Discount` (discount.dart) — `customerId` (was sponsorId), with `customerName`, `customerLogo` for social display
- `DiscountRedemption` (discount_redemption.dart) — tracks perk usage

After modifying any model, regenerate `.g.dart` files:
```bash
cd packages/shared && dart run build_runner build --delete-conflicting-outputs
```

### API Clients (lib/api/)
- `ApiClient` — base HTTP client with token management, debug logging, and `uploadFile` (multipart)
- `AdminAuthApi` — admin auth endpoints (login, refreshToken, getCurrentAdmin, logout)
- `AuthApi` — social auth endpoints (requestCode, verifyCode, refreshToken, logout, getCurrentUser, deleteAccount)
- `UsersApi` — user search, profile updates, photo upload
- `EventsApi` — event listing and details (social app)
- `ConnectionsApi` — connection management
- `PostsApi` — community feed
- `AdminApi` — all admin dashboard endpoints including event CRUD, image management, customer/product/discount CRUD, event partner management
- `PerksApi` — social-side endpoints: sponsors, discounts, redemptions

### Constants (lib/constants/)
- `verification_status.dart` — `VerificationStatus` enum, `UserRole` enum, `UserSource` enum
- `specialties.dart` — specialty display names mapping

### Utils (lib/utils/)
- `validators.dart` — phone number validation and normalization
- `formatters.dart` — display formatting helpers
- `storage.dart` — `SecureStorage` wrapper for flutter_secure_storage (tokens, userId, phone)

## Infrastructure

### Environments

Two environments in the same AWS account, isolated by naming convention. All scripts accept `--env dev|prod` (default: **dev**).

| | Dev | Prod |
|---|---|---|
| EKS cluster | `industrynight-dev` (1 node) | `industrynight-prod` (2 nodes) |
| K8s namespace | `industrynight-dev` | `industrynight` |
| HPA | 1-2 pods | 2-10 pods |
| RDS | `industrynight-db-dev` | `industrynight-db` |
| S3 assets | `industrynight-assets-dev` | `industrynight-assets-prod` |
| S3 admin web | `industrynight-web-admin-dev` | `industrynight-web-admin` |
| Secrets Manager | `industrynight/database-dev` | `industrynight/database` |
| API domain | `dev-api.industrynight.net` | `api.industrynight.net` |
| Admin domain | `dev-admin.industrynight.net` | `admin.industrynight.net` |
| ECR tag | `:dev` | `:latest` |
| CloudFront (prod) | (see dev.env) | `E196TNDGV555BI` |

Environment config files: `scripts/coop/environments/{dev,prod}.env`
Shared config: `scripts/coop/config.sh` (AWS account, region, ECR repo, helpers)

### AWS
- **Account:** 047593684855
- **Region:** us-east-1
- **ECR repo:** `047593684855.dkr.ecr.us-east-1.amazonaws.com/industrynight-api` (shared, tags: `:dev`, `:latest`)
- **ACM cert:** wildcard `*.industrynight.net` (covers both environments)
- **DNS:** Cloudflare (not Route 53) — CNAMEs for both environments
- **AWS Profile:** `industrynight-admin`

### Kubernetes
- **Manifests:** `infrastructure/k8s/` — templated with `__PLACEHOLDER__` tokens, applied via `apply_k8s_manifest()` in config.sh
- **Cluster template:** `infrastructure/eks/cluster.yaml.template` — generated per-environment via `generate_cluster_config()`
- **Resources:** 256Mi-512Mi memory, 250m-500m CPU per pod
- **Health:** liveness + readiness probes on `/health`
- **DB Proxy:** `db-proxy` pod for port-forwarding: `./scripts/pf-db.sh [--env dev|prod] start`

### Deployment workflow
```bash
# All commands default to dev. Add --env prod for production.

# Apply pending DB migrations first (always before deploying new API code)
DB_PASSWORD=xxx node scripts/migrate.js

# Build, push, and roll out the API
./scripts/deploy-api.sh                       # dev
./scripts/deploy-api.sh --env prod            # prod

# Build and deploy admin web app to S3/CloudFront
./scripts/deploy-admin.sh                     # dev
./scripts/deploy-admin.sh --env prod          # prod
```

## Scripts

All infrastructure scripts support `--env dev|prod` (default: dev). Node.js scripts pick up the target environment via `IN_NAMESPACE`, `IN_DEPLOYMENT`, and `IN_AWS_PROFILE` environment variables exported by `load_environment()` in config.sh.

| Script | Purpose | Usage |
|--------|---------|-------|
| `scripts/seed-admin.js` | Create initial admin user | `node scripts/seed-admin.js --email x --name y --password z` |
| `scripts/migrate.js` | Apply pending migrations (safe to re-run) | `DB_PASSWORD=xxx node scripts/migrate.js [--skip-k8s] [--dry-run] [--status]` |
| `scripts/db-reset.js` | Full DB reset (drop all, re-run migrations + seeds) | `DB_PASSWORD=xxx node scripts/db-reset.js [--skip-k8s] [--yes]` |
| `scripts/db-scrub-user.js` | Delete specific users by phone | `DB_PASSWORD=xxx node scripts/db-scrub-user.js [--skip-k8s] [--yes] +15551234567` |
| `scripts/db-uncheckin.js` | Reset check-in status for dev/testing | `DB_PASSWORD=xxx node scripts/db-uncheckin.js [--skip-k8s] [--yes] +15551234567` |
| `scripts/db-unconnect.js` | Delete connections for dev/testing | `DB_PASSWORD=xxx node scripts/db-unconnect.js [--skip-k8s] [--yes] +15551234567` |
| `scripts/deploy-api.sh` | Build Docker image, push to ECR, roll out to EKS | `./scripts/deploy-api.sh [--env dev\|prod] [--skip-build] [--status]` |
| `scripts/deploy-admin.sh` | Build admin web app, sync to S3, invalidate CloudFront | `./scripts/deploy-admin.sh [--env dev\|prod] [--skip-build] [--status]` |
| `scripts/pf-db.sh` | Manage kubectl port-forward tunnel to RDS | `./scripts/pf-db.sh [--env dev\|prod] start\|stop\|status` |
| `scripts/maintenance.sh` | Toggle k8s maintenance mode | `./scripts/maintenance.sh [--env dev\|prod] on/off` |
| `scripts/setup-local.sh` | Local dev environment setup | `./scripts/setup-local.sh` |

DB scripts use `pg` from `packages/api/node_modules` (no separate install needed). They auto-start kubectl port-forward unless `--skip-k8s` is passed.

### Executive Brief Generator

`scripts/doc-generation/generate-exec-brief.py` generates a 14-slide PowerPoint presentation at `docs/executive/Industry Night - Executive Brief.pptx`. Dark theme, purple accents, widescreen (16:9).

**To regenerate:**
```bash
python3 -m venv /tmp/pptx-env && source /tmp/pptx-env/bin/activate && pip install python-pptx
python3 scripts/doc-generation/generate-exec-brief.py
```

### COOP Scripts (scripts/coop/)

Infrastructure lifecycle management — tear down AWS to save costs, rebuild from scratch, backup/restore data. All commands accept `--env dev|prod` (default: dev). Full documentation in `docs/guides/coop.md`.

| Script | Purpose | Usage |
|--------|---------|-------|
| `scripts/coop/coop.sh` | Controller (single entry point) | `./scripts/coop/coop.sh [--env dev\|prod] <command>` |
| `scripts/coop/config.sh` | Shared constants, helpers, `load_environment()` | Sourced by other scripts |
| `scripts/coop/environments/*.env` | Environment-specific values (dev.env, prod.env) | Sourced by `load_environment()` |
| `scripts/coop/setup-dev-persistent.sh` | One-time dev persistent resources (S3, Secrets, CF, DNS) | `./scripts/coop/setup-dev-persistent.sh` |
| `scripts/coop/infra-status.sh` | Color-coded AWS resource status | `./scripts/coop/coop.sh status` |
| `scripts/coop/db-export.sh` | Database backup (pg_dump + per-table) | `./scripts/coop/coop.sh export` |
| `scripts/coop/db-import.sh` | Database restore (full or selective) | `./scripts/coop/coop.sh import <dir>` |
| `scripts/coop/infra-teardown.sh` | Tear down EKS + RDS | `./scripts/coop/coop.sh teardown` |
| `scripts/coop/infra-rebuild.sh` | Rebuild all infra from scratch (creates cluster at K8s 1.35) | `./scripts/coop/coop.sh rebuild` |
| `scripts/coop/eks-upgrade.sh` | In-place sequential K8s version upgrade (no teardown) | `./scripts/coop/coop.sh upgrade` |

Key commands:
```bash
./scripts/coop/coop.sh status                                             # Dev status (default)
./scripts/coop/coop.sh --env prod status                                  # Prod status
./scripts/coop/coop.sh teardown                                           # Tear down dev
./scripts/coop/coop.sh rebuild --import backups/dev/YYYY-MM-DD_HHMMSS    # Rebuild dev + restore
./scripts/coop/coop.sh upgrade                                            # Upgrade dev cluster in-place to K8s 1.35
./scripts/coop/coop.sh --env prod upgrade --dry-run                       # Preview prod upgrade path
```

## Git Workflow

### Branch strategy

```
feature/your-feature  →  integration  →  master
```

- **`master`** — production only. Never commit directly. Only receives merges from `integration` via PR.
- **`integration`** — staging / ongoing development. All feature branches merge here first via PR.
- **feature branches** — one branch per feature or fix, branched off `integration`.

Both `master` and `integration` are protected:
- Direct pushes are blocked (PRs required)
- 1 approving review required before merge
- Force pushes and branch deletion blocked
- Admins can bypass in genuine emergencies (e.g. syncing diverged branches), but this should be rare

### Day-to-day workflow

```bash
# 1. Start new work from integration
git checkout integration && git pull
git checkout -b feature/my-feature

# 2. Do work, commit locally
git add <files>
git commit -m "..."

# 3. Push and open PR → integration
git push -u origin feature/my-feature
gh pr create --base integration

# 4. After PR is reviewed and merged to integration,
#    open a separate PR from integration → master to ship to production
gh pr create --base master --head integration
```

### Releasing to production

Open a PR from `integration` → `master`. This is the only path to production. The PR title should summarize what's being shipped (e.g. "Release: event image management + Posh webhook").

### GitHub issue labels

Package labels for routing issues to the right area:
- `pkg:social-app` — Flutter social app (iOS/Android/Web)
- `pkg:admin-app` — Flutter admin dashboard
- `pkg:api` — Node.js/Express backend
- `pkg:database` — Schema, migrations, seeds
- `pkg:shared` — Shared Dart package
- `pkg:infra` — AWS, Kubernetes, CI/CD

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

### DevCode system (magic test phone prefix)
Phone numbers starting with `+1555555` (NANPA reserved fictional prefix) use local devCode verification, bypassing Twilio. Controlled by `ENABLE_MAGIC_TEST_PREFIX`:
- **`ENABLE_MAGIC_TEST_PREFIX=true`** (dev k8s via dev.env): magic prefix active
- **`ENABLE_MAGIC_TEST_PREFIX=false`** (prod k8s via prod.env): magic prefix hard-blocked
- **`NODE_ENV=test`** (local Jest): magic prefix active regardless of env var
- **Not set / unrecognised value**: magic prefix inactive (safe default)

Use cases:
- **Automated tests:** Run without Twilio credentials
- **Dev environment:** Use real Twilio for manual testing with real phones, use magic prefix for scripted tests
- **Production:** Hard-blocked — `isTestPhone()` returns false when `ENABLE_MAGIC_TEST_PREFIX=false`

**Magic prefix behavior:**
1. `POST /auth/request-code` with `+1555555xxxx` → generates 6-digit code, stores in `verification_codes`, returns `{ devCode: "123456" }`
2. `POST /auth/verify-code` with `+1555555xxxx` → checks local DB, not Twilio Verify

**Real phone behavior (when Twilio configured):**
1. `POST /auth/request-code` → Twilio Verify sends SMS, no `devCode` in response
2. `POST /auth/verify-code` → Twilio Verify validates code

**Fallback (no Twilio, real phone):**
- If `AUTH_ALLOW_DEV_OTP_FALLBACK=true`: uses local devCode path
- Otherwise: returns 503 "SMS verification is unavailable"

### iOS setup
- Deployment target: iOS 14.0
- Platform created via `flutter create --platforms=ios`
- Fonts: Inter downloaded to `packages/social-app/assets/fonts/`

## Key Gotchas

1. **snake_case JSON:** PostgreSQL returns `snake_case` column names. All Dart `@JsonSerializable()` annotations MUST include `fieldRename: FieldRename.snake`. Without it, `DateTime.parse(json['createdAt'])` throws because the key is actually `created_at`.

2. **GoRouter singleton:** `GoRouter` must be created once in `initState()` of the app widget, NOT inside a `Consumer<AppState>` that rebuilds on every `notifyListeners()`. GoRouter's `refreshListenable` parameter handles auth state re-evaluation.

3. **Magic test phone prefix:** Phone numbers `+1555555xxxx` use local devCode verification when `ENABLE_MAGIC_TEST_PREFIX=true` (dev k8s) or `NODE_ENV=test` (local Jest). Hard-blocked when `ENABLE_MAGIC_TEST_PREFIX=false` (prod k8s). Do not assume it's active just because you're not in production — the env var must be explicitly set.

4. **User deletion cascade:** `DELETE FROM users WHERE id = $1` cascades to all related tables. But you MUST delete `verification_codes` separately first (keyed by phone, not user ID).

5. **Flutter theme classes:** Use `CardThemeData` (not `CardTheme`), `DialogThemeData` (not `DialogTheme`). Use `Color.withValues(alpha: 0.5)` (not `withOpacity`).

6. **build_runner:** After changing any model in `packages/shared/lib/models/`, run: `cd packages/shared && dart run build_runner build --delete-conflicting-outputs`

7. **Event detail screen:** `EventDetailScreen` takes only `eventId` — it loads the full event (with images + partners) from the API on init. Do NOT pass `event` as a `GoRouter` extra; the detail route was intentionally redesigned to always fetch fresh data.

8. **S3 image uploads:** `storage.ts` gracefully degrades when `S3_BUCKET` is not set — it returns a placeholder URL. In production, ensure `AWS_REGION`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `S3_BUCKET` are all set in the K8s secrets. The S3 bucket must have Object Ownership = `BucketOwnerPreferred` and public ACLs unblocked for `ACL: 'public-read'` to work.

9. **Posh webhook payload:** The real Posh `new_order` payload has flat buyer fields (`account_first_name`, `account_phone`, etc.) and an `items[]` array — NOT nested `buyer` object. See `posh.ts` for the correct interface.

10. **Event image_url column removed:** Migration 004 drops `events.image_url` and replaces it with the `event_images` table. The migration backfills existing data automatically. Do not reference `image_url` on events anywhere.

11. **Flutter Web FileReader:** `FileReader.readAsArrayBuffer()` returns `NativeUint8List` on the DDC runtime (debug mode), NOT `ByteBuffer`. Always cast `reader.result as Uint8List` directly — never `as ByteBuffer`.

12. **Dialog context:** When using `showDialog`, always use `dialogContext` from the builder callback for `Navigator.pop()`, not the parent widget's `context`. Using the wrong context pops the underlying screen instead of the dialog.

13. **GoRouter refreshListenable + push/pop:** Never call `notifyListeners()` on GoRouter's `refreshListenable` (e.g. `AppState`) during an active `push<T>`/`pop(T)` cycle. It triggers route re-evaluation which can orphan the push future, causing the awaiting screen to never receive the result. Defer state changes that call `notifyListeners()` until after the push/pop completes.

14. **JWT auto-refresh:** `ApiClient.onTokenExpired` must be wired up in `AppState` constructor. Access tokens expire after 15 minutes; without auto-refresh, users get "invalid or expired token" errors on any API call after that window.

15. **Multi-environment `--env` flag:** All infrastructure scripts default to `dev`. Production requires explicit `--env prod`. Shell scripts use `parse_env_flag()` + `load_environment()` from config.sh. Node.js scripts read `IN_NAMESPACE`, `IN_DEPLOYMENT`, `IN_AWS_PROFILE` environment variables (exported by `load_environment()`). K8s manifests use `__PLACEHOLDER__` tokens substituted at apply time via `apply_k8s_manifest()`.

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
- **QR networking:** Connections are instant and mutual on QR scan (no request/accept flow, no confirmation step). Scanner gets immediate celebration overlay. Scanned user gets notified via 4-second polling on `GET /connections`. Both users auto-verified on first connection.
- **Venue as text fields:** `venue_name` and `venue_address` are plain text on `events` — no first-class Venue FK for new events. The `venues` table remains for legacy data only.
- **posh_orders as tickets:** Posh webhook purchases write to `posh_orders`, which IS the canonical ticket record. The `tickets` table is for walk-in/manual check-ins. Posh buyers are NOT auto-created as users — they receive an invite to download the app.
- **Publish gate:** Events require Posh event ID + venue name + at least 1 image + market assignment before they can be published. Enforced at the API layer in `PATCH /admin/events/:id`. Error when market missing: `"Cannot publish: Market must be assigned"`.
- **Image catalog:** All event images are queryable globally (`GET /admin/images`) for reuse and cleanup, in addition to per-event access.
- **Hero image:** `sort_order = 0` in `event_images` designates the hero (first image shown in social app). Admins can swap hero via star icon. Deleting the hero auto-promotes the next image.
- **Unified customer model:** Sponsors and vendors are both "customers" who buy different "products." The `customers` table replaces separate `sponsors` and `vendors` tables. A product catalog (`products`) defines what IN sells (sponsorships, vendor space, data products). `customer_products` tracks purchases. This supports the three revenue tiers: logo placement ($500-2K), audience access ($2-5K), data partnerships ($5-20K/quarter).
- **Discount redemption tracking:** The "I Used This" button in the social app records self-reported redemptions in `discount_redemptions`. This conversion data transforms logo placements (Tier 1) into provable audience access (Tier 2). Unique constraint prevents duplicate redemptions per user per discount.

## Documentation

The `docs/` directory is the project memory, organized into subfolders:
- `docs/architecture/` — AWS infrastructure design and provisioning
- `docs/executive/` — Stakeholder-facing decks, PDFs, and executive briefs
- `docs/product/` — Product requirements, implementation plans, design direction
- `docs/analysis/` — Deep-dive reviews (adversarial, social network, implementation audit)
- `docs/guides/` — Operational manuals (scripts usage, COOP teardown/rebuild)
- `docs/archive/` — Historical document versions

## Context Refresh & Knowledge Transfer

**Important for Claude:** The project owner may return after extended breaks and will have lost context on what was built, why decisions were made, and how the operational tooling works. When this happens:

1. **Don't assume knowledge.** If the user asks about infrastructure, COOP scripts, deployment, or any operational topic, start by pointing them to the relevant docs (`docs/guides/coop.md`, `docs/architecture/aws_architecture.md`, etc.) and offer a walkthrough rather than jumping straight into commands.

2. **Offer a refresher.** If the user seems uncertain or asks broad questions like "how does this work again?" or "what do we have?", proactively suggest walking through the system together. A good sequence:
   - Run `./scripts/coop/coop.sh status` to show current AWS state
   - Review what's running, what's hibernated, what it costs
   - Walk through any scripts or systems relevant to what they want to do

3. **Pending knowledge transfer items.** The following topics should be turned into a structured lesson plan when the user is ready. The goal is hands-on understanding, not just documentation:
   - **AWS/EKS/K8s fundamentals:** What the cluster is, what pods/deployments/services/ingress do, how kubectl works, what eksctl manages vs what kubectl manages
   - **COOP system:** How teardown/rebuild works, what gets deleted vs preserved, how database backups work, how to verify a restore
   - **Database operations:** Migrations system (`_migrations` table, `scripts/migrate.js`), how schema changes propagate, the FK cascade design, how to safely modify the schema
   - **CI/CD pipeline:** What the GitHub Actions workflows do, how code gets from PR to production, what's automated vs manual. **Known gaps:** no migration runner in deploy, no API tests, health check doesn't verify DB connectivity
   - **Deployment process:** `./scripts/deploy-api.sh` handles Docker build + ECR push + K8s rollout. Always run `scripts/migrate.js` before deploying API code that depends on new schema.
   - **Local development:** How to run everything locally, devCode system, port-forwarding to RDS

4. **Known technical debt / future work:**
   - CI/CD: Wire `scripts/migrate.js` into `api.yml` as a pre-deploy K8s Job (runner script exists, just not wired into CI yet)
   - CI/CD: Add more API test coverage (Jest tests exist for health, auth/middleware, customers; need auth flow, user cascade, event publish gate, Posh webhook)
   - CI/CD: Add DB connectivity check to `/health` endpoint
   - CI/CD: Add post-deploy smoke tests
   - Migrations: Create down-migration files for rollback capability
   - Admin app: Posh orders view (see who bought tickets, reconcile with IN accounts)
   - Admin app: Event check-in management (scan activation codes, view checked-in attendees)

## Testing Plan

**Trigger phrase:** "tell me about Flutter app testing" or "let's build the test suite"

### API Tests (Jest) — uses testcontainers (PostgreSQL in Docker)
Tests run against a real PostgreSQL container (not mocks) with the full migration applied. Run with `cd packages/api && npx jest`.

**Existing test suites (70 tests, all passing):**
- `health.test.ts` — health endpoint + specialties
- `middleware.test.ts` — token family separation, auth header validation, admin auth login
- `customers.test.ts` — 30 tests: customer CRUD, product catalog, customer products, discounts, discount redemptions, event partners, social sponsor/discount endpoints, redemption analytics

**Still needed:**
1. **Auth flow:** request-code → verify-code → token issued → refresh → logout
2. **User deletion cascade:** delete user → verify all FK tables cleaned, audit_log preserved (SET NULL), verification_codes cleaned separately
3. **Event publish gate:** PATCH status=published fails without poshEventId, venueName, market_id, and at least 1 image
4. **Posh webhook:** POST /webhooks/posh with real payload structure → posh_orders row created → invite sent

### Flutter Widget Tests — Priority: build alongside API tests
Per-screen tests for form validation, state transitions, and navigation. Focus on:
- **Admin app:** Login form validation, auth state transitions, route guards, event form validation
- **Social app:** Profile setup validation, event list rendering, connection flow state

### Physical/Manual Testing — requires humans or future embodied agents
Cannot be automated — requires real devices in physical proximity:
- QR scan → mutual connection created (two devices)
- Event check-in with activation code (at venue)
- Full onboarding flow on physical device
- Push notifications, deep links, camera permissions

### What's explicitly NOT tested
- ~~devCode system~~ — deprecated, not worth testing. Physical devices used for mobile testing.
