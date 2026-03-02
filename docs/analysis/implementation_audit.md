# Implementation Audit — Industry Night Platform

**Date:** 2026-03-01
**Branch:** `integration` (post-merge of `feature/admin-event-management`, PR #11)
**Methodology:** Automated code-level audit of every file across all four packages, cross-referenced against requirements docs and commit history.

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [API Backend](#2-api-backend)
3. [Social App](#3-social-app)
4. [Admin App](#4-admin-app)
5. [Shared Package](#5-shared-package)
6. [Bugs & Critical Issues](#6-bugs--critical-issues)
7. [Security Findings](#7-security-findings)
8. [Requirements Gap Analysis](#8-requirements-gap-analysis)
9. [Technical Debt](#9-technical-debt)
10. [Prioritized Action Plan](#10-prioritized-action-plan)

---

## 1. Executive Summary

### What Works End-to-End
- Phone-based auth (request code → verify → token pair → auto-refresh on 401)
- Admin auth (email/password → admin token pair → token family isolation)
- Event browsing, detail with multi-image carousel, ticket display
- Ticket-gated event check-in with activation code (QR scan or manual entry)
- Instant QR connections with celebration overlay, auto-verification, polling notifications
- Admin dashboard with live stats
- Admin user management (list, detail, add, ban, verify, role change)
- Admin event lifecycle (create, edit, detail, images, sponsors, publish gate, delete)
- Admin ticket management (issue, delete, refund stub)
- S3 image upload/delete with hero image system
- Posh webhook receiver (stores orders, sends invite SMS/email)
- Remember-me login, app icons, logo on splash/login

### What's Stubbed (UI exists, no API wiring)
- Community feed (hardcoded fake posts)
- Search screen (hardcoded fake results)
- User profile view (entirely static)
- Create post screen (simulates with delay, no API call)
- Post detail screen (static content)
- Perks/sponsors screen (hardcoded fake sponsors)
- Sponsor detail screen (static content)
- Admin moderation: posts list (100% fake data)
- Admin moderation: announcements (100% fake data)

### What's Missing Entirely
- Profile photo upload (UI button exists, backend route missing)
- Social links editing (model exists, no UI)
- Delete account button (backend works, no UI — App Store compliance risk)
- Push notifications
- Event bookmarks/saves
- Map view for events
- Event filtering (by day, venue type, perks)
- "Who's Going" / "Who's Here" event social tabs
- Audit log viewer (admin)
- Analytics dashboard (admin)
- Admin user CRUD for admin accounts
- Vendor-to-event association
- Comment deletion

### Scorecard

| Component | Complete | Partial | Stub | Missing |
|-----------|----------|---------|------|---------|
| API Routes (40 total) | 32 | 3 | 0 | 5 |
| Social App Screens (20) | 11 | 3 | 6 | 0 |
| Admin App Screens (21) | 16 | 3 | 2 | 0 |
| Shared Models (10) | 10 | 0 | 0 | 0 |
| Shared API Clients (8) | 5 | 3 | 0 | 3 missing classes |

---

## 2. API Backend

### 2.1 Route Inventory

#### Auth (`/auth`) — COMPLETE
| Method | Path | Status |
|--------|------|--------|
| POST | `/auth/request-code` | COMPLETE — dual-mode Twilio Verify (prod) / local DB (dev) |
| POST | `/auth/verify-code` | COMPLETE — auto-creates user on first verify |
| POST | `/auth/refresh` | COMPLETE — **but see Critical Issue #1** |
| POST | `/auth/logout` | COMPLETE — no-op server-side (client clears tokens) |
| GET | `/auth/me` | COMPLETE |
| DELETE | `/auth/me` | COMPLETE — cleans up verification_codes then CASCADE |

#### Admin Auth (`/admin/auth`) — COMPLETE
| Method | Path | Status |
|--------|------|--------|
| POST | `/admin/auth/login` | COMPLETE — bcrypt, tokenFamily: 'admin' |
| POST | `/admin/auth/refresh` | COMPLETE — validates tokenFamily === 'admin' |
| GET | `/admin/auth/me` | COMPLETE |
| POST | `/admin/auth/logout` | COMPLETE |

#### Users (`/users`) — PARTIAL (2 missing routes)
| Method | Path | Status |
|--------|------|--------|
| GET | `/users` | COMPLETE — text + specialty filters, pagination |
| GET | `/users/:id` | COMPLETE — full column set |
| PATCH | `/users/me` | COMPLETE — dynamic updates, auto-computes profile_completed |
| GET | `/users/me/qr` | COMPLETE |
| DELETE | `/users/:id` | COMPLETE — admin-only |
| POST | `/users/me/photo` | **MISSING** — Flutter client calls this, will 404 |
| POST | `/users/me/verification` | **MISSING** — Flutter client calls this, will 404 |

#### Events (`/events`) — COMPLETE
| Method | Path | Status |
|--------|------|--------|
| GET | `/events` | COMPLETE — status + upcoming filters, hero image subquery |
| GET | `/events/my-tickets` | COMPLETE — user's tickets across all events |
| GET | `/events/:id` | COMPLETE — full detail with images + sponsors |
| GET | `/events/:id/tickets` | COMPLETE |
| GET | `/events/:id/my-ticket` | COMPLETE — returns best valid ticket |
| POST | `/events/:id/checkin` | COMPLETE — validates code, requires ticket, increments count |

#### Connections (`/connections`) — COMPLETE
| Method | Path | Status |
|--------|------|--------|
| GET | `/connections` | COMPLETE — full user_a + user_b via json_build_object |
| POST | `/connections` | COMPLETE — canonical ordering, auto-verify, enriched response |
| DELETE | `/connections/:id` | COMPLETE |

Note: Two `// TODO: Log to audit_log` comments in connections.ts (create + delete).

#### Posts (`/posts`) — COMPLETE (1 missing sub-route)
| Method | Path | Status |
|--------|------|--------|
| GET | `/posts` | COMPLETE — **SQL injection risk (see Security #1)** |
| GET | `/posts/:id` | COMPLETE — same SQL issue |
| POST | `/posts` | COMPLETE |
| PATCH | `/posts/:id` | COMPLETE — author-only |
| DELETE | `/posts/:id` | COMPLETE — author or admin |
| POST | `/posts/:id/like` | COMPLETE — idempotent |
| DELETE | `/posts/:id/like` | COMPLETE |
| GET | `/posts/:id/comments` | COMPLETE — no auth required (public) |
| POST | `/posts/:id/comments` | COMPLETE |
| DELETE | `/posts/:id/comments/:commentId` | **MISSING** — Flutter client calls this, will 404 |

#### Sponsors (`/sponsors`) — COMPLETE (social-facing)
| Method | Path | Status |
|--------|------|--------|
| GET | `/sponsors` | COMPLETE — lists active sponsors |
| GET | `/sponsors/:id` | COMPLETE — includes active discounts; missing 404 check |

#### Vendors (`/vendors`) — COMPLETE (social-facing)
| Method | Path | Status |
|--------|------|--------|
| GET | `/vendors` | COMPLETE |

#### Discounts (`/discounts`) — COMPLETE (social-facing)
| Method | Path | Status |
|--------|------|--------|
| GET | `/discounts` | COMPLETE — date-range filtering |

#### Webhooks (`/webhooks`) — COMPLETE
| Method | Path | Status |
|--------|------|--------|
| POST | `/webhooks/posh` | COMPLETE — HMAC-SHA256 verification, delegates to posh.ts |

#### Admin (`/admin`) — PARTIAL (4 missing routes)
| Method | Path | Status |
|--------|------|--------|
| GET | `/admin/dashboard` | COMPLETE |
| GET | `/admin/users` | COMPLETE |
| PATCH | `/admin/users/:id` | COMPLETE — no audit logging |
| POST | `/admin/users` | COMPLETE — no phone normalization |
| GET | `/admin/events` | COMPLETE |
| GET | `/admin/events/:id` | COMPLETE — with ticket counts |
| POST | `/admin/events` | COMPLETE — auto-generates activation code |
| PATCH | `/admin/events/:id` | COMPLETE — publish gate enforced |
| DELETE | `/admin/events/:id` | COMPLETE — draft-only; **S3 images orphaned** |
| POST | `/admin/events/:id/images` | COMPLETE — max 5, sharp resize 800px JPEG 80% |
| PATCH | `/admin/events/:id/images/:imageId/hero` | COMPLETE |
| DELETE | `/admin/events/:id/images/:imageId` | COMPLETE — S3 + DB, auto-promotes hero |
| POST | `/admin/events/:id/sponsors` | COMPLETE — idempotent |
| DELETE | `/admin/events/:id/sponsors/:sponsorId` | PARTIAL — rowCount bug (see Bug #3) |
| GET | `/admin/tickets` | COMPLETE — global list with filters |
| GET | `/admin/events/:id/tickets` | COMPLETE |
| POST | `/admin/events/:id/tickets` | COMPLETE — duplicate check |
| DELETE | `/admin/events/:id/tickets/:ticketId` | COMPLETE |
| PATCH | `/admin/events/:id/tickets/:ticketId/refund` | PARTIAL — status change only, no payment |
| GET | `/admin/images` | COMPLETE |
| DELETE | `/admin/images/:imageId` | COMPLETE — does NOT auto-promote hero |
| GET | `/admin/sponsors` | COMPLETE |
| POST | `/admin/sponsors` | PARTIAL — no validation, no logo_url field |
| PATCH | `/admin/sponsors/:id` | **MISSING** — documented but not implemented |
| GET | `/admin/sponsors/:id/discounts` | **MISSING** — documented but not implemented |
| POST | `/admin/sponsors/:id/discounts` | **MISSING** — documented but not implemented |
| GET | `/admin/vendors` | COMPLETE |
| POST | `/admin/vendors` | PARTIAL — no validation |
| PATCH | `/admin/vendors/:id` | **MISSING** — documented but not implemented |

### 2.2 Middleware — All COMPLETE
| Middleware | Status | Notes |
|-----------|--------|-------|
| `authenticate` | COMPLETE | Does NOT check tokenFamily (social routes accept admin tokens) |
| `optionalAuth` | COMPLETE | Silently continues without token |
| `authenticateAdmin` | COMPLETE | Validates tokenFamily === 'admin', blocks social tokens |
| `requireAdmin` | COMPLETE | Checks role in ADMIN_ROLES |
| `requirePlatformAdmin` | COMPLETE | Checks role === 'platformAdmin' |
| `validate` | COMPLETE | Zod validation with structured errors |

### 2.3 Services — All COMPLETE
| Service | Status | Notes |
|---------|--------|-------|
| `sms.ts` | COMPLETE | Twilio Verify + general SMS; graceful degradation |
| `email.ts` | COMPLETE | SES in prod, console.log in dev |
| `storage.ts` | COMPLETE | S3 upload/delete with ACL: 'public-read'; graceful degradation |
| `posh.ts` | COMPLETE | Processes new_order, upserts posh_orders, sends invites |

### 2.4 Token Refresh — Root Cause of "error: refresh token" Popup

**The Problem:**
When `POST /auth/refresh` is called with an expired refresh token, `verifyToken(refreshToken)` throws a raw `JsonWebTokenError` or `TokenExpiredError` from the `jsonwebtoken` library. This error is NOT an `AppError` instance, so the global error handler catches it as a generic error and returns:
```
500 Internal Server Error
{ message: "Internal server error" }
```

The Flutter `ApiClient` sees a non-401 error (it's a 500) and does NOT trigger the token expired flow — instead it surfaces the error message to the user as a popup.

**The Fix:**
Wrap `verifyToken(refreshToken)` in a try/catch that converts JWT errors to `UnauthorizedError('Invalid or expired refresh token')`, which returns a clean 401. Same fix needed in `admin-auth.ts`.

**Additional issue:** `POST /auth/refresh` does NOT validate `tokenFamily === 'social'`. An admin refresh token could be used to generate a new social access token. The admin refresh route correctly validates `tokenFamily === 'admin'`.

---

## 3. Social App

### 3.1 Screen Inventory

#### Auth — COMPLETE
| Screen | Status | Notes |
|--------|--------|-------|
| PhoneEntryScreen | COMPLETE | Validation, remember-me, logo, devCode passthrough |
| SmsVerifyScreen | COMPLETE | 6-digit input, auto-submit, devCode auto-fill, resend |

#### Onboarding — PARTIAL
| Screen | Status | Notes |
|--------|--------|-------|
| ProfileSetupScreen | PARTIAL | Name/email/bio/specialties work; **photo picker is a no-op** (`// TODO`); **no social links input** |

#### Events — COMPLETE
| Screen | Status | Notes |
|--------|--------|-------|
| EventsListScreen | COMPLETE | API-wired, sorts ticketed first, pull-to-refresh |
| EventDetailScreen | COMPLETE | Multi-image carousel, ticket card, check-in gating, sponsor chips |
| ActivationCodeScreen | COMPLETE | QR scan + manual entry, avoids notifyListeners bug |
| EventCard widget | COMPLETE | Hero image, ticket badge overlay |

#### Networking — COMPLETE
| Screen | Status | Notes |
|--------|--------|-------|
| ConnectTabScreen | COMPLETE | Three-state UI (active event / upcoming ticket / no tickets) |
| QrScannerScreen | COMPLETE | Instant connect, celebration overlay, 409 handling |
| ConnectionsListScreen | COMPLETE | Pull-to-refresh, swipe-to-delete, navigate to profile |
| NetworkingState | COMPLETE | 4-second polling, new connection detection, celebration trigger |
| DigitalCard widget | COMPLETE | QR code, avatar, specialties, verified badge |
| NewConnectionOverlay | COMPLETE | Confetti, elastic animation, auto-dismiss 5s |

#### Community — STUB
| Screen | Status | Notes |
|--------|--------|-------|
| CommunityFeedScreen | **STUB** | Renders 10 hardcoded fake PostCards. `PostsApi` exists but is not called. |
| CreatePostScreen | **STUB** | Text field with validation. `// TODO: Implement API call` — simulates with 1s delay. Image picker no-op. |
| PostDetailScreen | **STUB** | Entirely static — hardcoded author, time, content, counts. No API. Comment input is a no-op. |

#### Search — STUB
| Screen | Status | Notes |
|--------|--------|-------|
| SearchScreen | **STUB** | Search field + specialty chips exist. Results are 10 hardcoded fake ListTiles. `UsersApi.searchUsers()` not called. |
| UserProfileScreen | **STUB** | Entirely static — hardcoded name, bio, stats (Events: 12, Connections: 156). Connect button no-op. Social links no-ops. `UsersApi.getUser()` not called. |

#### Profile — PARTIAL
| Screen | Status | Notes |
|--------|--------|-------|
| MyProfileScreen | PARTIAL | Live data from AppState. Edit works. **"Get Verified" button is no-op.** "My Events" and "Saved Posts" are no-ops. |
| EditProfileScreen | PARTIAL | Pre-fills, validates, saves via API. Change detection with discard dialog. **Photo picker is no-op.** No social links editing. |
| SettingsScreen | PARTIAL | Phone display, logout works. **No Delete Account button (App Store compliance risk).** Notification toggles are hardcoded. Help/Terms/Privacy links are no-ops. |

#### Perks — STUB
| Screen | Status | Notes |
|--------|--------|-------|
| PerksScreen | **STUB** | Hardcoded "Featured" perk, 5 fake "Sponsor N" cards. No API. |
| SponsorDetailScreen | **STUB** | Hardcoded sponsor name/description, 2 fake discount codes. Clipboard copy works. |

### 3.2 State Management

**AppState (global):** Tracks auth state, current user, active event, loading/error. All auth and profile methods are API-wired. Token auto-refresh is wired via `ApiClient.onTokenExpired`.

**NetworkingState (scoped to ShellRoute):** Tracks connections, polling, new connection detection, celebration state. Fully wired to ConnectionsApi.

**Missing state management:**
- No posts/community state (no feed loading, caching, or pagination)
- No search state (no debounced queries or results)
- No sponsors/perks state (no data loading)
- No notification preferences state

### 3.3 API Wiring Summary

| API Client | Screens Using It | Screens That Should But Don't |
|-----------|-----------------|-------------------------------|
| AuthApi | PhoneEntry, SmsVerify, AppState | — |
| UsersApi | EditProfile, AppState | SearchScreen, UserProfileScreen, ProfileSetup (photo) |
| EventsApi | EventsList, EventDetail, ActivationCode, ConnectTab | — |
| ConnectionsApi | NetworkingState → QrScanner, ConnectionsList, ConnectTab | — |
| PostsApi | **NONE** | CommunityFeed, CreatePost, PostDetail |
| (no SponsorApi) | — | PerksScreen, SponsorDetailScreen |
| (no VendorsApi) | — | (future vendor display) |
| (no DiscountsApi) | — | (part of perks) |

### 3.4 Platform Readiness
- **iOS:** Production-ready. CocoaPods integrated, deployment target iOS 14.0, all native permissions configured.
- **Android:** Build-ready. Standard Flutter Android setup.
- **Web:** Partial. `dart:html` FileReader used in admin app (not social), but web platform is configured.

---

## 4. Admin App

### 4.1 Screen Inventory

#### Auth — COMPLETE
| Screen | Status | Notes |
|--------|--------|-------|
| AdminLoginScreen | COMPLETE | Email/password, error display, token storage |

#### Dashboard — COMPLETE
| Screen | Status | Notes |
|--------|--------|-------|
| DashboardScreen | COMPLETE | 4 stat cards (users, events, connections, posts) from real API; 3 recent activity cards hardcoded |

#### User Management — COMPLETE
| Screen | Status | Notes |
|--------|--------|-------|
| UsersListScreen | COMPLETE | Search, filter by role/status, DataTable with actions |
| UserDetailScreen | COMPLETE | Full profile, actions (ban, verify, role change), tickets section. **Bug: breaks when accessed by URL without GoRouter extra** |
| AddUserScreen | COMPLETE | Phone, name, email, role — wired to API |

#### Event Management — COMPLETE
| Screen | Status | Notes |
|--------|--------|-------|
| EventsListScreen | COMPLETE | DataTable with status chips, image count, sponsor count, row actions |
| EventFormScreen | COMPLETE | Unified create/edit. Activation code auto-generated. DateTime pickers. |
| EventDetailScreen | COMPLETE | Two-column layout. Images section (upload, preview, hero selection, delete). Sponsors section (add popup, remove chips). Status transitions. Activation code display. Ticket counts. |
| ImageCatalogScreen | COMPLETE | Grid of all images, multi-select, bulk delete |

#### Ticket Management — COMPLETE
| Screen | Status | Notes |
|--------|--------|-------|
| EventTicketsScreen | COMPLETE | DataTable with status, issue dialog, delete, refund |
| GlobalTicketsScreen | COMPLETE | Cross-event ticket list with filters |

#### Sponsor Management — PARTIAL
| Screen | Status | Notes |
|--------|--------|-------|
| SponsorsListScreen | COMPLETE | DataTable with tier, active status, row actions |
| SponsorFormScreen | COMPLETE (client-side) | Create works. **Edit calls PATCH endpoint that doesn't exist in backend — will 404.** |
| DiscountsScreen | PARTIAL | Lists discounts. Create works. **No edit or delete for discounts.** Backend routes for list/create also missing in admin.ts. |

#### Vendor Management — PARTIAL
| Screen | Status | Notes |
|--------|--------|-------|
| VendorsListScreen | COMPLETE | DataTable with category, active status |
| VendorFormScreen | COMPLETE (client-side) | Create works. **Edit calls PATCH endpoint that doesn't exist — will 404.** contactPhone silently dropped on update. |

#### Moderation — STUB
| Screen | Status | Notes |
|--------|--------|-------|
| PostsListScreen | **STUB** | 100% fake data — hardcoded posts, no API integration |
| AnnouncementsScreen | **STUB** | 100% fake data — hardcoded announcements, no API integration |

#### Settings — PARTIAL
| Screen | Status | Notes |
|--------|--------|-------|
| AdminSettingsScreen | PARTIAL | Logout works. Notification, maintenance, two-factor toggles are all no-ops. |

### 4.2 Admin App Bugs
1. **UserDetailScreen loading spinner forever** when accessed by URL without GoRouter `extra` (deep link or page refresh)
2. **VendorFormScreen** silently drops `contactPhone` on update
3. **StatCard** uses deprecated `withOpacity()` instead of `withValues(alpha:)`

---

## 5. Shared Package

### 5.1 Models — All In Sync
All 10 models have correct serialization, all `.g.dart` files are current, all match their API response shapes.

| Model | Fields | Serialization | Notes |
|-------|--------|---------------|-------|
| AdminUser | 7 | camelCase (correct for admin API) | |
| User + SocialLinks | 18 + 4 | snake_case | |
| Event + EventSponsor | 22 + 4 | snake_case | EventSponsor is manual fromJson |
| EventImage | 6 | snake_case | |
| Connection | 7 | snake_case | Nested user objects are partial (~11 of 18 fields) |
| Ticket | 17 | snake_case | Covers all response shapes |
| Post + PostComment | 13 + 6 | snake_case | **Author data mismatch (see Bug #4)** |
| Sponsor | 9 | snake_case | |
| Vendor | 11 | snake_case | |
| Discount | 13 | snake_case | Nested `sponsor` field always null from current endpoints |

### 5.2 API Client Coverage

| Client | Methods | All Routes Covered? | Issues |
|--------|---------|--------------------|----|
| AuthApi | 6 | YES | |
| AdminAuthApi | 4 | YES | |
| AdminApi | 29 | YES (client-side) | 2 methods call non-existent backend routes (updateSponsor, updateVendor) |
| UsersApi | 6 | NO | 2 methods call non-existent routes (uploadProfilePhoto, submitVerification) |
| EventsApi | 7 | NO | 1 method calls non-existent route (getEventHistory) |
| ConnectionsApi | 3 | YES | |
| PostsApi | 9 | NO | 1 method calls non-existent route (deleteComment); unlikePost has runtime bug |
| **SponsorApi** | — | **CLASS MISSING** | Social-facing `/sponsors` endpoints have no client |
| **VendorsApi (social)** | — | **CLASS MISSING** | Social-facing `/vendors` endpoint has no client |
| **DiscountsApi** | — | **CLASS MISSING** | Social-facing `/discounts` endpoint has no client |

### 5.3 API Response Shape Mismatches
1. **Post.author** — backend returns flat `author_name`/`author_photo` fields; model expects nested `User` object. `post.author` will always be null.
2. **PostComment.author** — same issue.
3. **Discount.sponsor** — backend returns flat `sponsor_name`/`sponsor_logo`; model expects nested `Sponsor` object. Always null.

### 5.4 Stale Test
`test/models_test.dart` — User fromJson test uses camelCase keys but model expects snake_case. Will fail if run.

---

## 6. Bugs & Critical Issues

### Critical (affects user experience or correctness)

**Bug #1: Token refresh returns 500 instead of 401**
- **Files:** `packages/api/src/routes/auth.ts:134`, `packages/api/src/routes/admin-auth.ts:81`
- **Impact:** When refresh token expires, user sees "error: refresh token" popup instead of clean re-login flow
- **Root cause:** `verifyToken()` throws raw JWT library error, not caught as `AppError`, falls to generic 500 handler
- **Fix:** Wrap in try/catch, throw `UnauthorizedError('Invalid or expired refresh token')`

**Bug #2: PostsApi.unlikePost() runtime crash**
- **File:** `packages/shared/lib/api/posts_api.dart:97-101`
- **Impact:** Unliking a post will throw TypeError
- **Root cause:** `ApiClient.delete()` returns `void` but `unlikePost` casts result to `Map<String, dynamic>`
- **Fix:** Change `ApiClient.delete` to return response body, or change `unlikePost` to not expect a return value

**Bug #3: Admin sponsor unlink 404 check never fires**
- **File:** `packages/api/src/routes/admin.ts:553`
- **Impact:** Unlinking a non-existent sponsor silently succeeds instead of returning 404
- **Root cause:** `query()` returns `rows[]` not full pg result; `(result as any).rowCount` is always undefined
- **Fix:** Check `rows.length` or use raw pool.query() for the result object

### High (blocks features or compliance)

**Bug #4: Post author data never deserializes**
- **Files:** `packages/api/src/routes/posts.ts`, `packages/shared/lib/models/post.dart`
- **Impact:** Community feed will show no author names/photos even when API-wired
- **Root cause:** Backend returns flat `author_name`/`author_photo`, model expects nested `author: User`
- **Fix:** Either change backend to return nested object, or add `authorName`/`authorPhoto` fields to Post model

**Bug #5: No Delete Account UI (App Store compliance)**
- **Impact:** Apple requires apps with account creation to offer account deletion
- **Backend:** `DELETE /auth/me` works correctly
- **AppState:** `deleteAccount()` method is wired
- **Gap:** No button in Settings or Profile screens to trigger it

**Bug #6: UserDetailScreen fails on direct URL access (admin app)**
- **Impact:** Deep links and browser refresh break user detail page
- **Root cause:** Loads user from GoRouter `extra` (in-memory), falls back to loading state that never completes if extra is null
- **Fix:** Fall back to API call `getUser(id)` when extra is null (same pattern as EventDetailScreen)

### Medium

**Bug #7: Sponsor edit and vendor edit will 404**
- Backend `PATCH /admin/sponsors/:id` and `PATCH /admin/vendors/:id` routes don't exist
- Admin app UI calls these routes — edit operations silently fail or error

**Bug #8: Admin global image delete doesn't auto-promote hero**
- `DELETE /admin/images/:imageId` deletes from S3 + DB but doesn't check if deleted image was the hero
- Per-event `DELETE /admin/events/:id/images/:imageId` correctly auto-promotes

---

## 7. Security Findings

### High Priority

**Security #1: SQL injection in posts.ts**
- **File:** `packages/api/src/routes/posts.ts`
- **Impact:** `userId` from JWT is interpolated into SQL string instead of using parameterized query
- **Risk:** If JWT payload were tampered (unlikely with proper signing), SQL injection possible
- **Fix:** Use `$N` parameter placeholder for userId in the posts query

**Security #2: Social refresh doesn't validate tokenFamily**
- **File:** `packages/api/src/routes/auth.ts` refresh endpoint
- **Impact:** An admin refresh token could generate a social access token
- **Risk:** Low (requires having an admin token), but violates token family isolation
- **Fix:** Add `payload.tokenFamily === 'social'` check

### Medium Priority

**Security #3: Social routes accept admin tokens**
- `middleware/auth.ts` does not check `tokenFamily` — admin tokens pass authentication on social endpoints
- `middleware/admin-auth.ts` correctly blocks social tokens on admin routes
- **Risk:** Admin users can access social endpoints (arguably acceptable but asymmetric)

**Security #4: Comments endpoint is unauthenticated**
- `GET /posts/:id/comments` has no `authenticate` middleware
- Anyone can read comments without a token

**Security #5: No rate limiting**
- No rate limiting on any endpoint (auth, webhooks, API calls)
- `POST /auth/request-code` could be used for SMS bombing

---

## 8. Requirements Gap Analysis

### Requirements Evolved (Original → Current Reality)

The project evolved significantly from the original handoff document. Key pivots:
- **Hospitality workers → Creative professionals** (hair, makeup, photography, etc.)
- **Email auth → Phone SMS OTP** (social), email/password (admin only)
- **Venue-managed events → Platform-managed** with Posh integration
- **Request/accept connections → Instant QR connections** (no confirmation step)
- **Walk-in check-in → Ticket-gated check-in** (must have pre-existing ticket)
- **Open registration → Invite-only** (must have Posh ticket or admin-added)

### Implemented Requirements (by area)

| Area | Implemented | Notes |
|------|------------|-------|
| Auth/Access Control | 90% | Missing: invite-only gate (any phone can create account via SMS verify) |
| User Profiles | 70% | Missing: photo upload, social links editing, verification document submission |
| Verification System | 80% | 3-step verify works (ticket + code + connection). Missing: feature gating matrix, limited access mode |
| QR Networking | 95% | Fully working. Missing: "both must be at same event" check (only checks active event, not matching events) |
| Event Social | 40% | Check-in works. Missing: Who's Going, Who's Here tabs |
| Community Board | 10% | Backend routes complete. UI is 100% stubbed. |
| Search | 10% | Backend route complete. UI is 100% stubbed. |
| Sponsors & Perks | 40% | Backend + admin CRUD done. Social display 100% stubbed. Missing: sponsor tiers in social app, "powered by" placement |
| Vendors | 30% | Backend + admin CRUD done. No event-vendor association. No social display. |
| Event Management (admin) | 90% | Full lifecycle. Missing: duplicate event, event analytics, recurring events |
| User Management (admin) | 85% | Full CRUD. Missing: banned users filtered view, audit logging on actions |
| Content Moderation (admin) | 5% | Screens exist as stubs. No API integration. |
| Analytics | 0% | Tables exist in DB. No dashboard, no queries. |
| Push Notifications | 0% | Not started |
| In-App Ticketing | 0% | Phase 2 — not started |

### Unimplemented Requirements From requirements.md

| ID | Requirement | Effort | Notes |
|----|-------------|--------|-------|
| R-1 | Invite-only / ticket-only, no open signup | Medium | Currently any phone can create account. Need to check against posh_orders or admin-added users table. |
| R-4 | "Not in system" message directs to posh.vip | Small | UI change in verify-code flow |
| R-6 | Posh webhook creates user record | Medium | Currently stores posh_order only, does NOT create user. By design — but contradicts requirement. |
| R-12 | Limited access mode for unverified users | Medium | Feature gating matrix not implemented |
| R-15 | Activation code valid only during event time window | Small | Backend may already enforce this — needs verification |
| R-22 | QR code only active when checked in | Done | Implemented via hasActiveEvent gating |
| R-26 | Both users must be checked in to same event | Small | Currently only checks that scanner has active event, not that scanned user does too |
| R-31 | "Who's Going" tab | Medium | Backend endpoint needed + UI |
| R-32 | "Who's Here" tab | Medium | Backend endpoint needed + UI |
| R-39 | Community board: verified users only | Small | Gate already exists conceptually but feed is stubbed |
| R-41 | Admin announcements (highlighted posts) | Medium | Post model has isPinned/type=announcement, no admin UI to create them |
| R-44-48 | Sponsor tiers with visibility rules | Medium | Tiers exist in model. Social app doesn't differentiate by tier. |
| R-51 | Vendors associated with specific events | Medium | No event_vendors junction table or API |
| R-52 | Sponsor discounts: verified users only | Small | Gating not implemented |
| R-63 | Admin creates events in IN backend | Done | |
| R-74 | Banned users list view | Small | Filter exists, no dedicated screen |
| R-80 | Duplicate event for recurring | Small | API: copy event fields to new row. UI: "Duplicate" button. |
| R-87-90 | Post moderation tools, report system | Medium | Backend: needs report endpoint. Admin: stub screens need wiring. |
| R-92 | Admin users management | Medium | No screen to add/edit/delete admin users |
| R-93 | Audit log viewer | Medium | audit_log table exists, no admin screen to view it |

---

## 9. Technical Debt

### Backend
1. **S3 image orphaning** — event delete CASCADEs DB rows but doesn't delete S3 objects
2. **No API tests** — Jest configured, zero test files
3. **Health check doesn't verify DB** — `GET /health` returns ok without checking DB connectivity
4. **No rate limiting** on any endpoint
5. **No down-migrations** — can't roll back schema changes
6. **No migrate.js in CI/CD** — migrations are manual pre-deploy step
7. **Missing audit logging** — connection create/delete, user updates in admin have TODO comments
8. **Posh→ticket reconciliation** — manual admin ticket issuance bridges the gap, but no automated path from posh_order to ticket
9. **Admin sponsor create** accepts no validation schema and no logo_url
10. **No token blacklist** — logout is a no-op; compromised tokens valid until expiry

### Frontend (both apps)
1. **Stale test file** — `packages/shared/test/models_test.dart` will fail
2. **No widget tests** — zero test files in either app
3. **Specialties hardcoded** — client has static list despite backend `/specialties` endpoint existing
4. **AppState monolith** — single ChangeNotifier for all app state; will become unwieldy
5. **No offline support** — no local caching, every screen re-fetches on mount

### Infrastructure
1. **No post-deploy smoke tests**
2. **No staging environment** — integration branch has no dedicated deployment
3. **Pending API redeploy** — connections.ts enriched POST response and users.ts full column SELECT changes are on integration but not yet deployed

---

## 10. Prioritized Action Plan

### P0 — Fix Before Next Release

| # | Item | Effort | Impact |
|---|------|--------|--------|
| 1 | Fix token refresh 500 → 401 error | Small | Eliminates user-facing "error: refresh token" popup |
| 2 | Add Delete Account button to Settings | Small | App Store compliance (Apple requirement) |
| 3 | Fix SQL injection in posts.ts | Small | Security — parameterize userId |
| 4 | Fix PostsApi.unlikePost() TypeError | Small | Runtime crash prevention |
| 5 | Deploy pending API changes | Small | connections + users fixes already on integration |

### P1 — Wire Up Existing Code (Screens exist, API exists, just needs connecting)

| # | Item | Effort | Impact |
|---|------|--------|--------|
| 6 | Wire CommunityFeedScreen to PostsApi | Medium | Activates community feature |
| 7 | Wire SearchScreen to UsersApi.searchUsers() | Medium | Activates user discovery |
| 8 | Wire UserProfileScreen to UsersApi.getUser() | Small | Makes profile viewing work |
| 9 | Wire CreatePostScreen to PostsApi.createPost() | Small | Completes community posting |
| 10 | Wire PostDetailScreen to PostsApi | Medium | Comments, likes, author data |
| 11 | Fix Post author data shape mismatch | Small | Backend returns flat fields, model expects nested |
| 12 | Create SponsorApi + DiscountsApi clients | Medium | Enables social perks display |
| 13 | Wire PerksScreen + SponsorDetailScreen to API | Medium | Activates perks feature |

### P2 — Implement Missing Backend Routes

| # | Item | Effort | Impact |
|---|------|--------|--------|
| 14 | POST /users/me/photo (profile photo upload) | Medium | Enables profile photos |
| 15 | PATCH /admin/sponsors/:id (sponsor editing) | Small | Unblocks admin sponsor management |
| 16 | PATCH /admin/vendors/:id (vendor editing) | Small | Unblocks admin vendor management |
| 17 | GET/POST /admin/sponsors/:id/discounts | Small | Unblocks admin discount management |
| 18 | DELETE /posts/:id/comments/:commentId | Small | Enables comment deletion |

### P3 — Feature Completion

| # | Item | Effort | Impact |
|---|------|--------|--------|
| 19 | Profile photo picker (onboarding + edit) | Medium | Core profile feature |
| 20 | Social links editing UI | Small | Completes profile management |
| 21 | Wire admin moderation screens to API | Medium | Post moderation, announcements |
| 22 | "Who's Going" / "Who's Here" event tabs | Large | Event social features |
| 23 | Invite-only access control (check posh_orders/admin-added on verify) | Medium | Core access control requirement |
| 24 | Same-event connection validation | Small | Security — both users should be at same event |
| 25 | Duplicate event feature (admin) | Small | Time-saver for recurring events |
| 26 | Admin audit log viewer | Medium | Accountability/compliance |
| 27 | Fix UserDetailScreen deep link issue | Small | Admin UX |

### P4 — Technical Debt & Hardening

| # | Item | Effort | Impact |
|---|------|--------|--------|
| 28 | Add rate limiting (especially auth endpoints) | Medium | Security |
| 29 | Fix S3 orphaning on event delete | Small | Storage cleanup |
| 30 | Add DB connectivity to /health | Small | Monitoring |
| 31 | Write API tests (auth flow, cascade deletes, publish gate) | Large | Quality |
| 32 | Wire migrate.js into CI/CD | Small | Deployment safety |
| 33 | Add tokenFamily check to social refresh | Small | Security |
| 34 | Fix stale models_test.dart | Small | Test hygiene |

---

## Appendix A: File Counts by Package

| Package | Dart/TS Files | Lines (approx) |
|---------|--------------|----------------|
| packages/api/src/ | 16 | ~3,500 |
| packages/social-app/lib/ | 32 | ~6,000 |
| packages/admin-app/lib/ | 30 | ~7,500 |
| packages/shared/lib/ | 22 | ~3,000 |
| packages/database/migrations/ | 4 | ~400 |
| scripts/ | 12 | ~1,500 |

## Appendix B: Database Tables vs Usage

| Table | Used By | Status |
|-------|---------|--------|
| users | Auth, profiles, connections, posts, tickets | Active |
| admin_users | Admin auth | Active |
| verification_codes | SMS auth | Active |
| events | Event management, check-in | Active |
| event_images | Image management | Active |
| event_sponsors | Sponsor linking | Active |
| tickets | Check-in, admin management | Active |
| posh_orders | Webhook storage | Active |
| connections | QR networking | Active |
| posts | Community feed | Active (backend only; UI stubbed) |
| post_comments | Comments | Active (backend only; UI stubbed) |
| post_likes | Likes | Active (backend only; UI stubbed) |
| sponsors | Sponsor management | Active |
| vendors | Vendor management | Active |
| discounts | Discount management | Partial (admin create only, no edit/delete) |
| venues | Legacy | Unused (venue_name/venue_address on events) |
| audit_log | Audit trail | Partially populated (auth events only) |
| analytics_connections_daily | Analytics | **Unused** — table exists, no writes |
| analytics_users_daily | Analytics | **Unused** — table exists, no writes |
| analytics_events | Analytics | **Unused** — table exists, no writes |
| analytics_influence | Analytics | **Unused** — table exists, no writes |
| data_export_requests | GDPR/CCPA | **Unused** — table exists, no writes |
| specialties | Reference data | Active (read-only; no admin management UI) |
| _migrations | Migration tracking | Active |
