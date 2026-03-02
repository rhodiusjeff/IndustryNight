# Adversarial Review — Requirements vs. Reality

**Date:** 2026-03-01
**Baseline documents:** `requirements.md` (v1.8), `industry_night_app_developer_context_handoff.md`, `implementation_plan.md` (v1.1)
**Methodology:** Every claim in the requirements and implementation plan was compared against the actual codebase. Code-level evidence cited for each finding.

---

## Verdict Summary

The platform's **happy-path infrastructure is solid** — auth works, events work, QR connections work, admin management works, image uploads work. But the implementation deviates from requirements in several **structurally significant** ways, some of which undermine core product assumptions.

| Category | Score |
|----------|-------|
| Core infrastructure (auth, API, DB, deploy) | Strong |
| Admin tooling | Strong |
| Event lifecycle (create → publish → check-in → connect) | Strong |
| Access control & feature gating | **Critical gap** |
| Social features (community, search, perks) | Stub only |
| Requirements fidelity | ~60% |
| implementation_plan.md accuracy | ~75% (overstates completion) |

---

## 1. The Big Three — Structural Gaps

These aren't missing buttons or unfinished screens. These are **architectural deviations** from the requirements that change the product's identity.

### 1.1 Open Registration (contradicts core premise)

**Requirement (§4.1):** "The app is invite-only / ticket-only. No open signup." Phone not in system → "Purchase a ticket at posh.vip."

**Reality:** ANY phone number can create an account. `POST /auth/verify-code` (`auth.ts:85-99`) auto-creates a user with `source='app'` for any phone number that successfully verifies an SMS code. There is **no check** against `posh_orders`, no check against an admin-added whitelist, no rejection path.

**Evidence:** `auth.ts` lines 86-98:
```typescript
let user = await queryOne('SELECT id, role FROM users WHERE phone = $1', [phone]);
if (!user) {
  user = await queryOne(
    'INSERT INTO users (phone, source) VALUES ($1, $2) RETURNING id, role',
    [phone, 'app']
  );
}
```

**Impact:** The entire value proposition of exclusivity — "buy a ticket to join the community" — is not enforced. Anyone with a phone number can create an account, set up a profile, browse events, and (once they have an activation code) check in and make connections.

**Why this matters strategically:** The requirements positioned ticket purchase as both a revenue driver AND a trust/quality gate. Without enforcement, the community is open to anyone who hears about the app. This may be intentional for beta/testing, but it's not documented as such.

**Decision needed:** Is this a conscious soft launch decision ("let anyone in for now, gate later"), or an oversight? If intentional, the requirements doc should be updated to reflect it. If not, this is P0.

> **DECISION (2026-03-01):** Open registration adopted as the correct model. Rationale:
> - Open registration turns the events list into a marketing funnel (browse → get excited → buy ticket)
> - Verification (attend + connect) is a stronger trust gate than a payment gate
> - Walk-in scenario requires low-friction onboarding at the door (phone → SMS → done in 30s)
> - Posh ticket purchases auto-link to user accounts by phone number on registration
> - The verification ladder (registered → checked_in → verified) becomes the feature gate, not registration
>
> **Action items:**
> - #12 — Normalize phone in `posh_orders` for auto-linking
> - #13 — Auto-link Posh orders to users on registration
> - #14 — Implement verification-based feature gating
> - #15 — Update `requirements.md` to reflect this model
> - #16 — Deep-link to event after Posh auto-link (walk-in scenario UX)

---

### 1.2 No Feature Gating by Verification Status

**Requirement (§4.3):** Detailed feature access matrix:
- `registered` → browse events, set up profile, search creatives
- `checked_in` → QR networking, Who's Going/Here
- `verified` → community board, sponsor discounts, QR networking (persists)

**Reality:** `verification_status` is a data field on the `users` table. It is **read and written** (auto-verified on first connection) but it **never gates access** to anything. No middleware, no route guard, no conditional check anywhere in the API checks `verification_status` before allowing an action.

**Evidence:** The `authenticate` middleware (`middleware/auth.ts`) checks JWT validity and extracts `userId`/`role` — it never queries or checks `verification_status`. No route handler in `posts.ts`, `sponsors.ts`, `discounts.ts`, or `connections.ts` checks verification status.

**Impact:** The three-tier verification model (registered → checked_in → verified) exists conceptually but is **not enforced at any layer**. An unverified user can call every API endpoint that a verified user can. The only actual gate is "must be checked into an event" for QR scanning — and that's enforced client-side by the Flutter app, not server-side.

**Why this matters strategically:** The verification ladder is a behavioral incentive system. "Attend an event to unlock community board" drives attendance. "Make a connection to unlock discounts" drives networking. Without enforcement, there's no incentive gradient.

> **DECISION (2026-03-01):** Backend gating confirmed as required. Current client-side gating (Flutter state) is insufficient — API must enforce verification status server-side. Tracked in #14.
>
> Current state: all gating is frontend only (e.g. `ConnectTabScreen` checks `hasActiveEvent`). The API accepts any authenticated request regardless of `verification_status`. This must be locked down with `requireVerified` middleware on community board, discounts, and sponsor detail routes.

---

### 1.3 Posh Webhook Does Not Create Users (contradicts requirement)

**Requirement (§5):** "Posh webhook → IN backend creates user record (phone, email from webhook)" and "IN sends welcome email with app download link"

**Reality:** The Posh webhook (`posh.ts`) stores a record in `posh_orders` and sends an invite SMS/email to the buyer. It does **NOT** create a `users` row. The `CLAUDE.md` documents this as intentional: "Posh buyers are NOT auto-created as users — they receive an invite to download the app."

**Impact:** This was a deliberate design decision, and there's a reasonable argument for it (users should create their own profile). But combined with Gap 1.1 (open registration), the intended flow breaks down:

| Intended flow | Actual flow |
|---------------|-------------|
| Buy Posh ticket → webhook creates user → user logs in | Buy Posh ticket → webhook stores order → user logs in → auto-created (but order not linked) |
| No ticket → phone not in system → rejected | No ticket → phone not in system → auto-created anyway |

The `posh_orders` table has data. The `users` table has data. But **there is no reconciliation** between them. A Posh buyer and their app account are disconnected unless an admin manually issues a ticket.

**Decision needed:** Should the Posh webhook create users (as originally required), or should the open-registration model be kept and the invite-only requirement dropped?

> **DECISION (2026-03-01):** Posh webhook NOT creating users is correct. The data model intentionally separates `posh_orders` (purchases) from `users` (app accounts). Users create their own accounts via open registration.
>
> The missing piece is **reconciliation**: when a user registers, auto-link any matching `posh_orders` by phone number and create `tickets` rows. This also covers the walk-in scenario (buy ticket on Posh → show up → download app at door → register → auto-linked → check in).
>
> Three reconciliation triggers:
> 1. **On registration** — query `posh_orders` by phone, auto-create tickets (#13)
> 2. **On check-in attempt** — fallback check if no ticket found (#13)
> 3. **At webhook time** — if user already exists with matching phone, auto-create ticket then too (#13)
>
> Prerequisite: phone normalization in `posh_orders` (#12)
>
> The original requirement "webhook creates user record" is retired. Updated in #15.

---

## 2. Requirements Fulfilled vs. Not Fulfilled

### 2.1 MVP Scope Items (from requirements.md §9)

| # | MVP Item | Status | Notes |
|---|----------|--------|-------|
| 1 | Webhook receiver for Posh "order created" events | **Done** | Works correctly |
| 2 | User pre-registration from webhook data | **Retired** | Replaced by auto-link on registration (#13). Posh stores order; user creates own account. |
| 3 | Welcome email with app download link | **Done** | Sends invite SMS + email |
| 4 | Invite-only login (phone must be in system) | **Retired** | Replaced by open registration + verification gating (#14, #15) |
| 5 | Phone-based SMS authentication | **Done** | Twilio Verify in prod, devCode in dev |
| 6 | Admin can manually add users | **Done** | `POST /admin/users` |
| 7 | Profile creation (name, bio, specialty, social links) | **Partial** | Name/bio/specialties work. Photo upload missing. Social links on model but no edit UI. |
| 8 | Limited access mode for unverified users | **Not done** | Verification gating tracked in #14 |
| 9 | Event management (admin creates events with activation codes) | **Done** | Full CRUD, images, sponsors, publish gate |
| 10 | Activation code entry screen | **Done** | QR scan + manual entry |
| 11 | Code validation (ticket + code + time window) | **Partial** | Ticket + code validated. Time window NOT validated (no schema support). |
| 12 | Personal QR code for networking | **Done** | |
| 13 | QR scanner to connect with others | **Done** | Instant connection, celebration overlay |
| 14 | My Connections list | **Done** | Pull-to-refresh, swipe-to-delete |
| 15 | First connection triggers verified status | **Done** | Auto-verify on first connection |
| 16 | Event code entry at each event | **Done** | |
| 17 | "Who's Going" — connections with tickets | **Deferred** | Product owner reviewing; implement with feature flag (hide/show) |
| 18 | "Who's Here" — connections checked in | **Deferred** | Same as #17; build together behind feature flag |
| 19 | QR networking enabled only while checked in | **Partial** | Client-side gate only. Server doesn't validate. |
| 20 | Upcoming events list | **Done** | |
| 21 | Creative search by specialty | **Not done** | Backend endpoint exists. UI is hardcoded stub. |
| 22 | Profile viewing with social link outs | **Not done** | UI is hardcoded stub. |
| 23 | Community Board (verified users only) | **Not done** | Backend exists. UI is stub. No verification gate. See Posts implementation plan below. |
| 24 | Admin announcements | **Not done** | Post model supports it. No admin UI to create. |
| 25 | Sponsor discount codes (verified users only) | **Not done** | Backend exists. Social UI is stub. No verification gate. |
| 26 | Add users manually | **Done** | |
| 27 | Create/manage events with activation codes | **Done** | |
| 28 | Post announcements | **Not done** | No admin UI |
| 29 | Moderate content | **Not done** | Admin screens are stubs |
| 30 | Manage sponsors (by tier) | **Partial — adequate for MVP** | Create works. Edit/delete deferred pending product owner requirements on sponsor/vendor/perks/discounts model. |
| 31 | Manage vendors | **Partial — adequate for MVP** | Create works. Edit/delete deferred pending product owner requirements. |
| 32 | Assign sponsors/vendors to events | **Partial — adequate for MVP** | Sponsors: done. Event-vendor association deferred pending product owner requirements. |
| 33 | Manage sponsor discount codes | **Deferred** | Awaiting product owner input on sponsor/vendor/perks/discounts requirements. |

**Scorecard (revised):** 13 done / 5 partial-adequate / 5 not done / 2 deferred (feature flag) / 2 deferred (product owner) / 2 retired / 4 not done (tracked) = **~55% done or adequate, ~85% resolved or tracked**

> **NOTE (2026-03-01):** Sponsors, vendors, perks, and discounts (items 25, 30-33) require product owner input on detailed requirements before further implementation. Current CRUD is adequate for MVP. The product owner will have significant input on these features as the product evolves.

> **NOTE (2026-03-01):** Community Board / Posts (item 23) needs a detailed implementation path. See §2.3 below.

---

### 2.2 Data Model Deviations

| Required (from requirements.md §8) | Implemented? | Notes |
|-------------------------------------|-------------|-------|
| `bypass_ticket_check` on users | **No** | Column does not exist in any migration |
| `code_valid_start` / `code_valid_end` on events | **No** | Columns do not exist. Time window enforcement impossible at DB layer. |
| `EventCheckIn` table | **No** | Check-in tracked via tickets table `status = 'checkedIn'`, not separate table |
| `EventVendor` junction table | **No** | Vendors cannot be associated with events |
| `Event.status` includes `cancelled` | **Yes** | Enum: draft, published, cancelled, completed |
| `Post.is_announcement` | **Yes** | Model has `is_pinned` field. Type enum includes `announcement`. |
| `Sponsor.social_links` | **No** | Only `website_url`, no social_links JSON |
| `Sponsor.tier` | **Yes** | Enum field exists |

> **NOTE (2026-03-01) — Data model deviations assessment:**
> - `bypass_ticket_check` — **Retired.** Not needed in open registration model.
> - `code_valid_start`/`code_valid_end` — **OBE.** Event lifecycle (published → completed status) serves as the time gate. No columns needed.
> - `EventCheckIn` table — **Acceptable deviation.** Tracking check-in via `tickets.status = 'checkedIn'` is simpler and works. Separate table is unnecessary.
> - `EventVendor` junction — **Deferred** pending product owner requirements on vendor model.
> - `Sponsor.social_links` — **Deferred** pending product owner requirements on sponsor model.

---

### 2.3 Community Board / Posts — Implementation Path

The community feed is the most substantial social feature still in stub state. Here's the current inventory and a best-practices implementation plan.

#### What exists today

| Layer | Status | Details |
|-------|--------|---------|
| **DB tables** | Complete | `posts` (with type, is_pinned, is_hidden, like_count, comment_count), `post_comments`, `post_likes` |
| **API routes** | Complete (with bugs) | Full CRUD, like/unlike, comments. Bugs: SQL injection (#3 in audit), unlikePost response (#2 in audit), comments unauthenticated (#4 security). Missing: `DELETE /comments/:id`. |
| **Shared model** | Complete (with shape mismatch) | `Post`, `PostComment` models. `Post.author` expects nested `User` object but API returns flat `author_name`/`author_photo` — author will always be null. |
| **Shared API client** | Complete (with bug) | `PostsApi` with all methods. `unlikePost()` will TypeError (casts void to Map). `deleteComment()` calls non-existent endpoint. |
| **Social app screens** | 100% stub | `CommunityFeedScreen`: 10 hardcoded fake cards. `CreatePostScreen`: Future.delayed fake. `PostDetailScreen`: all static. |
| **PostCard widget** | Complete | Well-structured, accepts real data params. Ready to wire. |

#### Bug fixes (prerequisites — do these first)

| # | Fix | File | Effort |
|---|-----|------|--------|
| B1 | Parameterize `userId` in SQL (SQL injection) | `posts.ts` lines 40, 63 | Small |
| B2 | Fix `unlikePost()` — `ApiClient.delete()` returns void, can't cast to Map | `posts_api.dart:96-101` | Small — change `delete()` to return response body, or return void and re-fetch |
| B3 | Add `authenticate` middleware to `GET /posts/:id/comments` | `posts.ts:203` | Small |
| B4 | Add `DELETE /posts/:id/comments/:commentId` endpoint | `posts.ts` | Small |

#### Data shape fix (required before wiring)

The API returns flat author fields:
```json
{ "author_name": "Jane", "author_photo": "https://..." }
```

The Dart model expects a nested `User` object:
```dart
final User? author;  // always null because key "author" doesn't exist in response
```

**Recommended fix (social app best practice):** Add lightweight author display fields to the `Post` model rather than nesting a full `User` object. Social feeds should carry only the display data they need — not full user records.

```dart
// Add to Post model:
final String? authorName;
final String? authorPhoto;
final String? authorSpecialty;  // useful for display
```

This matches what the API returns and avoids an extra query to hydrate a full User. The `author` field can be kept for future use (profile tap deep-link already has `authorId`).

Same fix needed for `PostComment.author` → `authorName`/`authorPhoto`.

#### Implementation chunks (in order)

**Chunk 1: Backend fixes + data shape alignment**
- Fix B1-B4 above
- Optionally: add `u.specialties, u.verification_status` to posts query for richer feed display
- Add verification gating: `requireVerified` middleware on `POST /posts`, `GET /posts` (or gate at Flutter layer if soft-launch preference)
- Effort: Small (1 work session)

**Chunk 2: CommunityState provider**
- Create `CommunityState extends ChangeNotifier` (follows `NetworkingState` pattern)
- Properties: `List<Post> posts`, `bool isLoading`, `String? error`, `bool hasMore` (pagination)
- Methods:
  - `loadFeed({PostType? filter, bool refresh = false})` — calls `PostsApi.getFeed()`, appends or replaces
  - `createPost(String content, PostType type)` — calls API, prepends to list
  - `likePost(String id)` / `unlikePost(String id)` — **optimistic update** (toggle immediately, revert on error)
  - `deletePost(String id)` — remove from list
- Scope to community tab's `ShellRoute` (same pattern as `NetworkingState`)
- Effort: Medium (1 work session)

**Chunk 3: Wire CommunityFeedScreen**
- Convert from `StatelessWidget` to `StatefulWidget` (or consume `CommunityState` via Provider)
- On init: `communityState.loadFeed()`
- Pull-to-refresh: `RefreshIndicator` → `loadFeed(refresh: true)`
- Infinite scroll: `ScrollController` listener → `loadFeed()` when near bottom
- Post type filter: chip row at top (General / Jobs / Collabs) — all types already supported
- Empty state: "Be the first to post!" when feed is empty
- Verification gate: if user not verified, show gate UI instead of feed ("Attend an IN event to unlock community")
- Like tap: `communityState.likePost(id)` (optimistic)
- Post tap: navigate to `/community/post/:id`
- Author tap: navigate to `/users/:authorId`
- Effort: Medium (1 work session)

**Chunk 4: Wire CreatePostScreen**
- Replace `Future.delayed` with `communityState.createPost(content, type)`
- Add post type selector (chips or dropdown — general/job/collaboration)
- On success: `context.pop()` — feed auto-refreshes via provider
- Image upload: defer to later (backend `POST /posts` doesn't accept images yet; schema has `image_urls` array but no upload flow)
- Effort: Small (half session)

**Chunk 5: Wire PostDetailScreen**
- Convert to `StatefulWidget`, load from `PostsApi.getPost(postId)` on init
- Load comments: `PostsApi.getComments(postId)`
- Like/unlike: optimistic toggle with icon state (filled heart vs outline)
- Comment input: `TextEditingController` → `PostsApi.addComment(postId, content)` → prepend to list
- Delete comment: swipe-to-delete on own comments (once B4 endpoint exists)
- Author tap: navigate to `/users/:authorId`
- Relative time display: use `timeago` package or simple formatter ("2h ago", "yesterday")
- Effort: Medium (1 work session)

**Chunk 6: Post overflow menu + report (future)**
- Three-dot menu on PostCard: "Report", "Hide", "Delete" (own posts), "Delete" (admin)
- Report endpoint: `POST /posts/:id/report` — creates report record, increments report_count
- Hide: client-side only (filter from feed)
- This is best done after the admin moderation screens are wired
- Effort: Medium

#### Social app best practices applied

| Practice | How it applies |
|----------|---------------|
| **Optimistic updates** | Like/unlike toggles immediately. Reverts on API error. |
| **Infinite scroll** | Offset-based pagination (backend already supports `limit`/`offset`). Load 20 posts at a time. |
| **Pull-to-refresh** | `RefreshIndicator` reloads from offset 0. |
| **Relative timestamps** | "2h ago", "yesterday", "Mar 1" — never raw ISO dates. |
| **Author context** | Name + photo + specialty on every post. Tap navigates to profile. |
| **Post type filtering** | Chip row at top. Filters feed by type param. |
| **Verification gate** | "Unlock community by attending an event" — drives event attendance. |
| **Empty state** | Welcoming message, not a blank screen. |
| **Error state** | "Couldn't load feed. Tap to retry." with retry button. |

---

## 3. Implementation Plan Accuracy Audit

The implementation plan (`implementation_plan.md`) marks phases with completion status. Here's the truth:

| Phase | Claimed Status | Actual Status | Discrepancy |
|-------|---------------|---------------|-------------|
| 1A: Foundation | Complete | **Accurate** | Auth, API, DB all working |
| 1B: Core Mobile App | Complete | **Accurate** | Login, profile, events all working |
| 1C: Verification & QR | Complete | **Accurate** | QR scan, connections, auto-verify all working |
| 1D: Event Social | Partial | **Accurate** | Who's Going/Here not built |
| **1E: Community Board** | **Complete** | **INACCURATE — should be "Stub"** | Screens exist with zero API calls. Feed shows 10 hardcoded fake posts. Create post simulates with `Future.delayed`. Post detail is entirely static. |
| **1F: Creative Search** | **Complete** | **INACCURATE — should be "Stub"** | Search screen shows 10 hardcoded fake ListTiles. User profile is entirely static. Backend endpoint exists but is never called. |
| 2A: Admin Foundation | Complete | **Accurate** | Login, dashboard, user management working |
| 2B: Admin Events | Complete | **Accurate** | Full lifecycle working |
| **2C: Admin Sponsors** | **Complete** | **INACCURATE — should be "Partial"** | Create works. `PATCH /admin/sponsors/:id` endpoint missing. `GET/POST /admin/sponsors/:id/discounts` endpoints missing. |
| **2D: Admin Vendors** | **Complete** | **INACCURATE — should be "Partial"** | Create works. `PATCH /admin/vendors/:id` endpoint missing. |
| 2E: Admin Moderation | Stub | **Accurate** | Correctly marked as stub |

**4 of 11 phases overstate their completion status.** The implementation plan should be corrected.

---

## 4. Contradictions Between Documents

### 4.1 Context Handoff vs. Requirements (intentional pivots)

These are **acknowledged pivots** that happened during development. They're reasonable but the original handoff doc still references the old assumptions.

| Context Handoff | Requirements / Current | Assessment |
|----------------|----------------------|------------|
| Hospitality workers (bartenders, servers, DJs) | Creative professionals (hair, makeup, photo) | Intentional pivot. Handoff doc is outdated. |
| Email + social auth | Phone SMS OTP | Intentional pivot. Better for mobile-first. |
| Venue-managed events | Platform-managed with Posh | Intentional pivot. Centralized control. |
| City selection + map view | Single city (NYC), no map | Scope reduction. Map view is a gap. |
| Filter by day/venue/perks | No filtering | Significant missing feature — see market area note below. |
| Save/bookmark events | Not implemented | Missing feature. |
| Recurring events | Manual recreation | Missing "duplicate event" feature. |
| Venue profiles/onboarding | No venue entity (text fields on events) | Intentional simplification. |

> **DECISION (2026-03-01) — Market area filtering:**
> Events should be filtered by market area. The user selects their home market in their profile, and the events list defaults to that market. Users can browse other markets (creatives travel between markets for work).
>
> Implementation:
> - Add `market_area` enum to DB (e.g. `nyc`, `la`, `miami` — 2-3 to start, relatively static)
> - Add `market_area` column to `events` table
> - Add `market_area` column to `users` table (user's home market, selectable in profile/onboarding)
> - Events list defaults to user's market, with a selector to browse others
> - Admin event form includes market area selection
>
> Tracked in #19.

### 4.2 Requirements vs. CLAUDE.md (conflicting documentation)

| requirements.md says | CLAUDE.md says | Which is right? |
|---------------------|---------------|-----------------|
| "Posh webhook creates user record" | "Posh buyers are NOT auto-created as users" | **CLAUDE.md is correct.** Posh stores orders; users create own accounts. Auto-link by phone (#13). Decided in §1.3. |
| "Phone not in system → reject" | No mention of rejection | **CLAUDE.md is correct (by omission).** Open registration adopted. Decided in §1.1. |
| "bypass_ticket_check flag for admin-added users" | No mention | **Retired.** Not needed in open registration model. Decided in §2.2. |
| "Code valid only during event time window" | No mention of time window | **OBE.** Event lifecycle (published → completed) serves as the time gate. Admin marks event completed after it ends. Activation code becomes unusable when status changes. No `code_valid_start/end` columns needed. |

> **DECISION (2026-03-01) — Activation code time window:**
> The `code_valid_start`/`code_valid_end` columns from the requirements data model are **not needed**. The event's published status IS the time window. Events are temporal — they appear when published and fall off the user's screen when completed. The admin flipping status to `completed` invalidates the activation code. The only edge case (late check-in before admin marks complete) is an acceptable operational gap, not worth schema changes.

### 4.3 Requirements vs. Requirements (internal contradictions)

| §4.3 says | §4.1 says | Status |
|-----------|-----------|--------|
| "registered" users can browse events and set up profile | "Phone must be in system to log in" | **Resolved.** Open registration means anyone can register. The "registered" state is simply "has an account." No conflict with open registration model. |
| Feature access matrix lists Community Board as "verified only" | §4.7 says "Access: Verified users only (both viewing and posting)" | **Resolved — consistent, enforcement tracked.** Both say verified-only. Backend `requireVerified` middleware will enforce (#14). |

> **NOTE (2026-03-01):** All §4 contradictions are now resolved by decisions made in §1 and §2. The requirements doc update (#15) will align §4.1 and §4.3 with the open registration + verification gating model.

---

## 5. Security Enforcement Gap

The requirements describe a layered trust model:

```
Ticket purchase → Account creation → Event attendance → Activation code → Connection → Verification
```

Each layer was meant to increase trust and unlock features. Here's what's actually enforced:

| Layer | Enforced? | How |
|-------|----------|-----|
| Ticket purchase → Account | **No** | Anyone can create account |
| Account → JWT token | **Yes** | SMS OTP |
| JWT → API access | **Yes** | `authenticate` middleware |
| Activation code → Check-in | **Yes** | Server validates code + ticket |
| Check-in → QR networking | **Client-side only** | Flutter gates UI. Server allows any authenticated POST. |
| Connection → Verification | **Yes** | Auto-verify on first connection |
| Verification → Feature unlock | **No** | No server-side gating |
| Same-event check for connections | **No** | `eventId` is optional, not validated |

**Bottom line:** Of the 8 trust layers in the requirements, 3 are fully enforced (JWT auth, activation code validation, auto-verify), 1 is client-side only, and 4 are not enforced at all.

> **DECISION (2026-03-01) — Security posture assessment:**
> The current security posture is generally appropriate for the development stage. Several items are already tracked:
> - **Ticket purchase → Account:** Intentionally open (decided in §1.1). Not a security gap — it's the adopted model.
> - **Verification → Feature unlock:** Backend gating tracked in #14.
> - **Check-in → QR networking:** Client-side gate is acceptable for now; server-side enforcement is a nice-to-have (low abuse risk at current scale).
> - **Same-event check:** `eventId` optional by design. Low risk — would require knowing another user's QR code AND the API endpoint. Not worth the complexity until user base grows.
>
> **Pre-MVP launch security review required (tracked in #20):**
> A dedicated security analysis must be conducted before true MVP launch covering:
> 1. **SQL injection audit** — Known issue in `posts.ts` (B1 in §2.3). Full sweep of all route handlers for parameterized query compliance.
> 2. **Attack surface analysis** — API endpoint enumeration, rate limiting assessment, input validation completeness.
> 3. **Bot/spam resilience** — Can bad actors create dummy accounts at scale? Can bots poison the community feed? SMS OTP is a natural rate limiter but the analysis should quantify the cost-of-attack.
> 4. **Authentication edge cases** — Token expiry handling, refresh token rotation, session invalidation on password/phone change.
> 5. **Data exposure** — Are any endpoints returning more user data than necessary? PII in logs?
>
> Current mitigations already in place: SMS OTP (expensive to automate), JWT with token families, CASCADE deletes for data cleanup, parameterized queries (mostly), HTTPS everywhere.

---

## 6. What Was Built That Wasn't Required

Not all deviations are gaps. Some things were built that go beyond or diverge from requirements:

| Feature | Required? | Assessment |
|---------|-----------|------------|
| Multi-image upload with hero system | No (original had single image_url) | **Good addition** — better event presentation |
| Image catalog (global image browser) | No | **Good addition** — admin convenience |
| Ticket management (admin issue/delete/refund) | No (Posh was supposed to handle tickets) | **Good addition** — needed for manual operations |
| S3 with public-read ACL | No specification | **Correct implementation** |
| Remember-me login | Not specified | **Good addition** — UX improvement |
| Celebration overlay on QR connect | Not specified | **Good addition** — delightful UX |
| Polling-based new connection notification | Not specified | **Good addition** — real-time feel without WebSockets |
| DevCode system for simulator testing | Not specified | **Good addition** — developer productivity |
| COOP infrastructure lifecycle scripts | Not specified | **Good addition** — cost management |
| Admin user detail with tickets section | Not specified in this detail | **Good addition** — operational visibility |

> **NOTE (2026-03-01):** These are "implicit requirements" — functionality that emerged from product discovery during development. They represent good engineering judgment and should be tracked as completed work. GitHub issues created retroactively (marked as done) to maintain a complete record: #21 through #30.

---

## 7. The Strategic Questions

These are decisions that need to be made before further development. They're not bugs — they're product direction choices.

### Q1: Is the app invite-only or open? — **DECIDED: Open**
> Open registration adopted. Events list is a marketing funnel. Verification ladder is the real gate. See §1.1.

### Q2: Should the Posh webhook create users? — **DECIDED: No**
> Posh stores orders; users create own accounts. Auto-link by phone on registration. See §1.3, tracked in #12, #13.

### Q3: Is verification-based feature gating worth implementing? — **DECIDED: Yes**
> Backend `requireVerified` middleware required. Tracked in #14. See §1.2.

### Q4: Are "Who's Going" / "Who's Here" core or nice-to-have? — **DECIDED: Build behind feature flag**
> Product owner may not want this visible (selective non-attendance concern). Build it, hide it behind a toggle. Tracked in #17.

### Q5: Is server-side connection validation needed? — **DECIDED: Defer**
> Low risk at current scale. Client-side gate is sufficient. Revisit when user base grows. See §5 security assessment.

---

## 8. Prioritized Corrections

> **NOTE (2026-03-01):** This section has been updated to reflect all decisions made during the adversarial review session. Items that were "Should Decide" have been resolved — see §7 for decision records.

### Must Fix (active bugs / compliance)

| # | Item | Status | Tracking |
|---|------|--------|----------|
| 1 | Correct `implementation_plan.md` phases 1E, 1F, 2C, 2D status | **Done** | Fixed during this review |
| 2 | ~~Decide on invite-only vs. open registration~~ | **Decided** | Open registration. See §1.1. |
| 3 | Add Delete Account button (social app) | **Open** | App Store compliance. Required before app store submission. |
| 4 | Fix token refresh 500 → 401 | **Open** | Active user-facing bug. Users get logged out after 15 min. |

### Should Fix (requirements fidelity — pre-MVP)

| # | Item | Status | Tracking |
|---|------|--------|----------|
| 5 | Wire community feed to API | **Open** | #18. Detailed plan in §2.3. |
| 6 | Wire creative search to API | **Open** | Backend endpoint exists, UI is stub. |
| 7 | Wire perks/sponsors to API | **Deferred** | Awaiting product owner requirements. Current CRUD adequate for MVP. |
| 8 | Fix Post author data shape mismatch | **Open** | Prerequisite for #18. See §2.3 data shape fix. |
| 9 | Fix SQL injection in posts.ts | **Open** | B1 in §2.3. Security prerequisite. |
| 10 | Implement `requireVerified` middleware | **Open** | #14. Backend verification gating. |
| 11 | Posh phone normalization + auto-linking | **Open** | #12, #13. Prerequisite for walk-in scenario. |
| 12 | Pre-MVP security review | **Open** | #20. Attack surface, SQL injection audit, bot resilience. |

### Resolved (decided during this review)

| # | Item | Decision | Reference |
|---|------|----------|-----------|
| R1 | Invite-only vs. open registration | Open registration | §1.1 |
| R2 | Posh webhook creating users | No — auto-link by phone instead | §1.3, #12, #13 |
| R3 | Verification feature gating | Yes — backend required | §1.2, #14 |
| R4 | Who's Going / Who's Here | Build behind feature flag | #17 |
| R5 | Same-event connection enforcement | Defer — low risk at scale | §5 |
| R6 | Activation code time window | OBE — event lifecycle is the gate | §4.2 |
| R7 | Market area filtering | Add to events + users | §4.1, #19 |
| R8 | Sponsor/vendor/perks/discounts | Deferred to product owner | §2.1 note |

### Removed (no longer applicable)

| # | Original Item | Why Removed |
|---|---------------|-------------|
| ~~7~~ | Add activation code time window validation | OBE. Decided in §4.2. Event lifecycle serves as the time gate. |

---

## Appendix: Evidence Index

All claims verified against source code on `integration` branch.

| Finding | File | Lines | Verified |
|---------|------|-------|----------|
| Open registration | `packages/api/src/routes/auth.ts` | 85-99 | Yes |
| No time window validation | `packages/api/src/routes/events.ts` | 158-213 | Yes |
| eventId optional on connections | `packages/api/src/routes/connections.ts` | 52-103 | Yes |
| No verification gating middleware | `packages/api/src/middleware/auth.ts` | 1-49 | Yes |
| No post reporting endpoint | `packages/api/src/routes/posts.ts` | 1-247 | Yes |
| No bypass_ticket_check column | `packages/database/migrations/` | All files | Yes |
| No code_valid_start/end columns | `packages/database/migrations/001_initial_schema.sql` | 83-98 | Yes |
| No S3 cleanup on event delete | `packages/api/src/routes/admin.ts` | 386-398 | Yes |
| Community feed is stub | `packages/social-app/lib/features/community/screens/community_feed_screen.dart` | 6-49 | Yes |
| Search screen is stub | `packages/social-app/lib/features/search/screens/search_screen.dart` | 91-104 | Yes |
| Token refresh throws 500 | `packages/api/src/routes/auth.ts` | ~134 | Yes |
| SQL injection in posts | `packages/api/src/routes/posts.ts` | userId interpolation | Yes |
