# Industry Night — User Stories

**Version:** 2.0 — All Actors (Admin, Social App, System)
**Status:** Draft — Jeff review pending
**Last Updated:** 2026-03-30
**Scope:** All tracks — Admin (B track, US-B prefix), Social App (A track, US-A prefix), System (C/D/E tracks, US-SYS prefix)
**Supersedes:** v1.0 (B-track only, 2026-03-26)

---

## How To Use This Document

This document is **fuel for Track Execution (TE) agents.** It defines explicit functional requirements as user stories — what users need to accomplish and what the system must do to support it. It does NOT specify HOW to implement (that's in the prompt specs and CLAUDE.md).

**Hierarchy:**
- This doc + the mockup (`docs/design/admin-mockup-v2.html`) define **what** to build
- CODEX prompt specs define **scope, phasing, and acceptance criteria** for each TE session
- CLAUDE.md defines **data models, API routes, and infrastructure ground truth**
- TEs exercise judgment on implicit behavior (micro-interactions, error copy, loading states) — this doc covers explicit requirements only

**Format:** Table per actor group. Columns: Workflow | Story | Acceptance Signal | Track/Prompt

**User story ID prefixes:**
- `US-B` — Admin (React admin app, B track)
- `US-A` — Social App (Flutter social app, A/E track)
- `US-SYS` — System actors (automated pipelines, backend services, C/D/E track)

IDs are assigned as each story is formally referenced in a prompt spec or amendment. Tables without IDs are pending assignment.

---

## Section A — Admin App (React) — Actor: B Track

**Actors for this section:**

| Actor | Description | Role Value |
|-------|-------------|------------|
| **Platform Admin** | Full-access operator — manages users, events, customers, products, moderation | `platformAdmin` |
| **Moderator** | Reviews and acts on community content (posts, flags) | `moderator` |
| **Event Ops — Door Staff** | Tablet at the venue entrance on event night; manages check-in stream | `eventOps` |
| **Event Ops — Wristband Staff** | Tablet at the wristband table on event night; issues wristbands from a queue | `eventOps` |
| **Developer** | Engineers building or validating the platform | — |

---

## B0 — Scaffold + Design System

| Workflow | Story | Acceptance Signal | Prompt |
|----------|-------|-------------------|--------|
| App startup | As a developer, I can run `./scripts/run-react-admin.sh` and have the admin app start on port 3630 without manual setup | App starts, login page renders at `localhost:3630/login` | B0 |
| Design system | As a Platform Admin, the app uses a consistent dark theme (deep background, purple primary, clear contrast) that's readable at a venue or office | All core screens render with the design token palette from the mockup | B0 |
| Empty shell navigation | As a Platform Admin, after logging in I see the full sidebar with all section headers and nav items, even if most screens are placeholders | Sidebar renders all nav items; clicking each navigates to a route (no 404) | B0 |
| Dev component reference | As a developer, I can navigate to `/dev/components` to see all shared UI components rendered in isolation | Component dev page renders DataTable, StatusBadge, Button variants, Modal skeleton | B0 |

---

## B1 — Auth + RBAC + Permissions

| Workflow | Story | Acceptance Signal | Prompt |
|----------|-------|-------------------|--------|
| Login | As any admin, I enter my email and password, click Sign In, and arrive at my permitted home screen | Valid credentials → authenticated and redirected to `/`; invalid credentials → inline error message, form not cleared | B1 |
| Wrong credentials | As any admin, if I type the wrong password I see a clear inline error and can retry without re-entering my email | Error message visible below form; email field still populated | B1 |
| Session persistence | As any admin, if I close and reopen the browser tab, I am still logged in without re-entering my credentials (as long as my refresh token has not expired) | Page reload while refresh token valid → user lands on last page, no login redirect | B1 |
| Session expiry | As any admin, if my session has fully expired and I navigate to any protected page, I am redirected to login with no confusing error state | Expired session → redirect to `/login`; no JSON error displayed | B1 |
| Logout | As any admin, after I click Logout I cannot navigate back using the browser back button and see the authenticated app | After logout + back → stays on login page; no cached state visible | B1 |
| Platform Admin nav | As a Platform Admin, I see all nav sections: Dashboard, Users, Events, Customers, Products, Moderation, Markets, Image Catalog, Audit Log, Settings | All sections visible in sidebar | B1 |
| Moderator nav | As a Moderator, I only see Dashboard and Moderation in the sidebar — no Users, Events, or Customers | Sidebar shows only those two sections | B1 |
| Event Ops nav | As an Event Ops staff member, I only see Dashboard and Event Ops in the sidebar | Sidebar shows only those two sections | B1 |
| Unauthorized route access | As a Moderator or Event Ops user, navigating directly to a URL I'm not permitted to access (e.g., `/users`) redirects me silently to my permitted home screen | No 403 error page shown; silent redirect | B1 |
| Role-gated actions | As a Moderator viewing a moderation screen, action buttons that require platformAdmin appear disabled with a tooltip explaining the restriction | Disabled state + tooltip visible; no action fires on click | B1 |

---

## B2 — Event Ops Screen (Real-Time Check-In + Wristband)

### Event Selection

| Workflow | Story | Acceptance Signal | Prompt |
|----------|-------|-------------------|--------|
| Event selector | As Event Ops staff, when I navigate to Event Ops I see a list of active and upcoming events to choose from | Event selector screen renders; only published/upcoming events shown | B2 |
| Auto-select | As Event Ops staff, if there is only one active event tonight, the system takes me directly to it without me having to select | Single active event → auto-navigates to `/events/ops/[eventId]` | B2 |

### Door Device — Check-In Stream

| Workflow | Story | Acceptance Signal | Prompt |
|----------|-------|-------------------|--------|
| Live check-in feed | As door staff, when someone checks in on the social app I see their name, avatar, and specialty appear at the top of my screen within 5 seconds | New entry appears in feed within 5s of app check-in; no manual refresh needed | B2 |
| Check-in snapshot | As door staff, when I first open the Event Ops screen I immediately see the last 50 check-ins that already happened | Feed is pre-populated on connect; not empty until first new event | B2 |
| Posh vs walk-in badge | As door staff, I can see at a glance whether someone checked in via Posh or as a walk-in | "Posh" or "Walk-in" badge visible on every check-in row | B2 |
| Wristband status in feed | As door staff, I can see which check-ins have already had a wristband issued vs. which are still pending | ⬜ (pending) and ✅ (issued) icons visible on every row in the live feed | B2 |
| Confirm wristband from door | As door staff, if I issue a wristband directly at the door I can tap the wristband icon on that person's row to mark it issued | Tap icon → immediate ✅ update in feed; `PATCH` fires; FCM push sent to attendee | B2 |
| Posh exception queue | As door staff, when a Posh buyer shows up without an app account I can find them in the exception queue and manually link them to an existing user | Exception list visible; Resolve button opens user search modal; on resolve, exception disappears | B2 |
| Activation code display | As a venue manager at the door, I can read the event activation code prominently on the screen and tell walk-in guests what to enter in the app | Activation code displayed in large monospace text with a Copy button | B2 |
| Connection recovery | As door staff, if the connection to the server drops I see a clear banner and the feed automatically reconnects without me doing anything | "Disconnected" banner appears; reconnect attempt shows; feed resumes on reconnect | B2 |

### Wristband Device — Queue

| Workflow | Story | Acceptance Signal | Prompt |
|----------|-------|-------------------|--------|
| Wristband queue auto-populated | As wristband table staff, when I open the Wristband Queue view I immediately see everyone who has checked in and is still waiting for a wristband | Queue pre-populated via SSE snapshot on connect; `wristbandIssuedAt == null` entries shown | B2 |
| Oldest-first ordering | As wristband table staff, the person who has waited the longest is always at the top of my queue so I can serve them first | Queue sorted ascending by `checkedInAt`; oldest entry at top | B2 |
| New arrivals appear automatically | As wristband table staff, when someone checks in at the door their name appears at the bottom of my queue without me refreshing the page | `checkin` SSE event → new row appended to bottom of pending list in real time | B2 |
| Backlog stats always visible | As wristband table staff, I can see at a glance how many people are waiting and how many have already been issued, without scrolling | ⏳ Pending and ✓ Issued counts visible in the header of the queue card at all times | B2 |
| Backlog warning | As wristband table staff, if the pending count climbs too high the number turns amber so I know I need to move faster | Pending count renders in amber/warning color when threshold is exceeded | B2 |
| Wait time warning | As wristband table staff, if someone has been waiting more than 20 minutes their wait duration shows in amber so I can prioritize them | Wait duration label turns amber for entries > 20 min old | B2 |
| Issue wristband | As wristband table staff, I tap "Issue Wristband →" next to a person's name, hand them the band, and their row immediately dims — I don't have to wait for a server response to see the update | Optimistic update on tap: row dims, button hides, "Wristband issued" label appears; pending count decrements | B2 |
| Issued rows stay visible | As wristband table staff, recently issued rows remain visible (dimmed) below the pending queue so I can verify I didn't miss someone | Issued rows visible below pending rows in dimmed/greyed state | B2 |
| Cross-device sync — door sees wristband update | As door staff at the entrance, when the wristband person issues a wristband I see the ⬜ → ✅ update on that person's entry in my live feed without refreshing | `wristband` SSE broadcast → door feed updates simultaneously | B2 |
| Error recovery on issue | As wristband table staff, if the wristband issue fails (network error) the row reverts to its previous state and I see a toast telling me to try again | Optimistic update reverts on error; toast shown | B2 |
| Mobile-friendly | As wristband table staff using a tablet in portrait mode, I can tap every button comfortably without mis-taps | All touch targets ≥ 44px; no horizontal scroll; dark theme readable in dim venue lighting | B2 |

---

## B3 — Admin Parity (All Remaining Screens)

### Dashboard

| Workflow | Story | Acceptance Signal | Prompt |
|----------|-------|-------------------|--------|
| Key metrics at a glance | As a Platform Admin, the dashboard shows me total users, events this month, total connections, and active customers without navigating anywhere | 4 stat cards render with live data from `GET /admin/dashboard` | B3 |
| Recent activity | As a Platform Admin, I can see recent platform activity (last 10 audit events) on the dashboard so I have situational awareness | Recent activity list renders below stats; timestamps, entity, and action visible | B3 |
| Quick navigation | As a Platform Admin, I can create a new event, add a user, or add a customer directly from the dashboard with one click | Quick action buttons present; navigate to correct create screens | B3 |

### Users

| Workflow | Story | Acceptance Signal | Prompt |
|----------|-------|-------------------|--------|
| Browse users | As a Platform Admin, I can view all users in a paginated table showing name, phone, role, and verification status | Users list loads; 25 per page; all listed columns visible | B3 |
| Search users | As a Platform Admin, I can search for a user by name or phone number and see matching results immediately | Search input calls `GET /admin/users?q=...`; results update | B3 |
| Filter users | As a Platform Admin, I can filter users by role (user / venueStaff / platformAdmin) and by verification status | Role and verificationStatus filter dropdowns functional; filters stack with search | B3 |
| View user detail | As a Platform Admin, I can click a user and see their full profile: avatar, specialties, posts, connections, and audit trail | User detail page loads all sections; collapsible sections work | B3 |
| Ban / unban user | As a Platform Admin, I can ban or unban a user from their detail page with a confirmation step | Ban/Unban toggle fires `PATCH /admin/users/:id`; badge updates; confirmation modal shown | B3 |
| Verify / reject user | As a Platform Admin, I can change a user's verification status from their detail page | Verify/Reject fires `PATCH /admin/users/:id`; badge updates | B3 |
| Add user | As a Platform Admin, I can create a new user by entering their phone number, name, email, and role | Create user form submits `POST /admin/users`; on success navigates to new user's detail page | B3 |
| Delete user | As a Platform Admin, I can delete a user with a hard confirmation step (type their name) to prevent accidents | Delete fires `DELETE /admin/users/:id` after name-typed confirmation; navigates back to list | B3 |

### Events

| Workflow | Story | Acceptance Signal | Prompt |
|----------|-------|-------------------|--------|
| Browse events | As a Platform Admin, I can see all events in a table with status, image count, and partner count at a glance | Events list loads; all columns visible; status badges color-coded | B3 |
| Filter events by status | As a Platform Admin, I can filter the events list to show only drafts, published events, or cancelled events | Status filter dropdown functional; list updates | B3 |
| Create event | As a Platform Admin, I can create a new event by entering the name, dates, venue, and optional details | Create form submits `POST /admin/events`; on success navigates to new event detail | B3 |
| Publish gate | As a Platform Admin, when I try to publish a draft event without a Posh Event ID, venue name, at least one image, or market assigned, I see a clear explanation of what's missing — not a generic error | Publish button shows a modal or inline error listing each unmet gate condition | B3 |
| Manage event images | As a Platform Admin, I can upload up to 5 images for an event, set one as the hero, and delete images I no longer want | Image gallery renders; drag-and-drop upload works; star sets hero; delete with confirm; API calls fire correctly | B3 |
| Set hero image | As a Platform Admin, I can designate any uploaded image as the hero (the first image shown in the social app) by clicking the star icon | Star click calls `PATCH /admin/events/:id/images/:imageId/hero`; only one star active at a time | B3 |
| Add event partners | As a Platform Admin, I can link a customer and product to an event to designate them as a sponsor or vendor for that event | Add partner flow opens popup; select customer + product; fires `POST /admin/events/:id/partners`; partner chip appears | B3 |
| Remove event partners | As a Platform Admin, I can remove a partner from an event | Remove fires `DELETE /admin/events/:id/partners/:cpId`; chip disappears | B3 |
| Edit event | As a Platform Admin, I can edit an event's name, dates, venue, and other details while it is in draft status | Edit form pre-populated; submits `PATCH /admin/events/:id`; read-only if status is published/cancelled/completed | B3 |
| Delete draft event | As a Platform Admin, I can delete an event that is in draft status | Delete fires `DELETE /admin/events/:id` with confirmation; only available on draft events | B3 |
| Event Ops can view events | As Event Ops staff, I can view the events list and event detail but cannot edit, publish, or delete | Edit/delete/publish controls disabled for eventOps role; view access granted | B3 |

### Image Catalog

| Workflow | Story | Acceptance Signal | Prompt |
|----------|-------|-------------------|--------|
| Browse all images | As a Platform Admin, I can see all uploaded images across all events in a grid, with event name and upload date visible on each tile | Image catalog loads; all events' images in responsive grid | B3 |
| Filter images by event | As a Platform Admin, I can filter the image catalog to show only images for a specific event | Event dropdown filter functional; grid updates | B3 |
| Multi-select and bulk delete | As a Platform Admin, I can select multiple images and delete them all at once | Checkbox multi-select works; bulk delete fires `DELETE /admin/images/:imageId` for each; images removed from grid | B3 |
| Preview image | As a Platform Admin, I can click any image to see a full-size preview with metadata (event, upload date, URL) | Preview modal opens; metadata shown; close works | B3 |

### Markets

| Workflow | Story | Acceptance Signal | Prompt |
|----------|-------|-------------------|--------|
| Browse markets | As a Platform Admin, I can see all markets (geographic/categorical regions) in a list | Markets screen loads; calls `GET /admin/markets`; all markets listed | B3 |
| Create market | As a Platform Admin, I can create a new market by entering a name | Create market form submits `POST /admin/markets`; market appears in list | B3 |
| Assign market to event | As a Platform Admin, when creating or editing an event I can assign it to a market | Market selector present in event create/edit form; required before publishing | B3 |
| Assign markets to customer | As a Platform Admin, when creating or editing a customer I can assign them to one or more markets | Market multi-select present in customer create/edit form | B3 |

### Customers

| Workflow | Story | Acceptance Signal | Prompt |
|----------|-------|-------------------|--------|
| Browse customers | As a Platform Admin, I can see all customers in a table showing logo, name, product types, and active product count | Customers list loads; all columns visible | B3 |
| Search customers | As a Platform Admin, I can search by customer name or filter by product type | Search + product type filter functional | B3 |
| View customer detail | As a Platform Admin, I can view a customer's full profile in a tabbed layout: Overview, Products, Discounts, Redemptions | Customer detail loads; all tabs functional | B3 |
| Add customer | As a Platform Admin, I can create a new customer with logo, contact info, and description | Create customer form submits `POST /admin/customers`; navigates to new customer detail | B3 |
| Edit customer | As a Platform Admin, I can update a customer's info at any time | Edit form pre-populated; submits `PATCH /admin/customers/:id` | B3 |
| Delete customer | As a Platform Admin, I can delete a customer with confirmation | Delete fires `DELETE /admin/customers/:id`; navigates back to list | B3 |
| Add product purchase | As a Platform Admin, I can record that a customer purchased a product (e.g., a sponsorship tier) with quantity and date range | Add product modal fires `POST /admin/customers/:id/products`; row appears in Products tab | B3 |
| Edit product purchase | As a Platform Admin, I can update the quantity, dates, or status of an existing purchase | Edit modal fires `PATCH /admin/customers/:id/products/:cpId`; row updates | B3 |
| Remove product purchase | As a Platform Admin, I can remove a product purchase from a customer | Delete fires `DELETE /admin/customers/:id/products/:cpId` with confirmation | B3 |
| Create discount | As a Platform Admin, I can create a discount/perk for a customer (e.g., "Free haircut on first visit") so it appears in the social app for attendees | Discount form fires `POST /admin/customers/:id/discounts`; discount appears in Discounts tab | B3 |
| Edit discount | As a Platform Admin, I can update a discount's details or toggle it active/inactive | Edit fires `PATCH /admin/customers/:id/discounts/:did`; row updates | B3 |
| Delete discount | As a Platform Admin, I can delete a discount with confirmation | Delete fires `DELETE /admin/customers/:id/discounts/:did`; row removed | B3 |
| View redemption analytics | As a Platform Admin, I can see how many users have redeemed each customer's discounts, with a breakdown by discount and a list of recent redemptions | Redemptions tab renders summary cards + breakdown table + recent redemptions list | B3 |
| View customer contacts | As a Platform Admin, I can see and manage the contact persons associated with a customer | Contacts panel renders; call `GET /admin/customers/:id/contacts`; add/edit/delete contact functional | B3 |
| Upload customer media | As a Platform Admin, I can upload brand assets (logos, photos) for a customer and see them in a gallery | Media upload panel renders; upload fires `POST /admin/customers/:id/media`; gallery updates | B3 |

### Products

| Workflow | Story | Acceptance Signal | Prompt |
|----------|-------|-------------------|--------|
| Browse product catalog | As a Platform Admin, I can see all products Industry Night sells (sponsorships, vendor space, data products) in a list | Products list loads; `GET /admin/products` called; type and price visible | B3 |
| Create product | As a Platform Admin, I can add a new product to the catalog | Product form fires `POST /admin/products`; product appears in list | B3 |
| Edit product | As a Platform Admin, I can update an existing product's name, type, or price | Edit form fires `PATCH /admin/products/:id`; list updates | B3 |
| Delete product | As a Platform Admin, I can delete a product that has no purchases attached | Delete fires `DELETE /admin/products/:id`; if product is in use, system blocks with an explanatory message | B3 |

### Moderation

| Workflow | Story | Acceptance Signal | Prompt |
|----------|-------|-------------------|--------|
| Browse community posts | As a Moderator or Platform Admin, I can see all community feed posts in a list with content preview, post type, author, and date | Posts list loads; all columns visible | B3 |
| View post detail | As a Moderator, I can click into a post and see the full content, comments, and like count | Post detail view loads | B3 |
| Delete post | As a Moderator or Platform Admin, I can delete a community post that violates guidelines | Delete fires correct API call; post removed from list | B3 |

### Settings

| Workflow | Story | Acceptance Signal | Prompt |
|----------|-------|-------------------|--------|
| View platform config | As a Platform Admin, I can view configuration settings such as AI moderation thresholds and SIEM forwarding status | Settings screen loads; config values displayed | B3 |
| View API key status | As a Platform Admin, I can see which external API integrations (Twilio, AWS SES, S3, FCM) are configured and operational | API key status panel renders with green/red status indicators | B3 |
| View audit log | As a Platform Admin, I can browse the full platform audit log with filters by action type, actor, and date range | Audit log screen loads; filter controls work; entries display with old/new values, IP, and route | B3 |

---

## Cross-Cutting Stories (All B Prompts)

| Workflow | Story | Acceptance Signal | Prompt |
|----------|-------|-------------------|--------|
| Loading states | As any admin, when a screen is fetching data I see skeleton placeholders — not a blank page or spinner over invisible content | Skeleton loaders visible during all `isLoading` states | All |
| Error states | As any admin, when a data fetch fails I see a clear error message with a retry button — not a blank screen | Error message + retry button rendered on fetch failure | All |
| Toast notifications | As any admin, when I perform an action (save, delete, copy) I see a brief confirmation toast at the bottom of the screen | Success/error toasts appear and auto-dismiss | All |
| Responsive layout | As an admin using a laptop or tablet, the app is usable without horizontal scrolling and without buttons or text being clipped | No horizontal overflow; responsive grid adapts at ≤1023px breakpoint | All |
| Dark theme | As any admin using the app in a dim venue or late at night, the dark theme is consistent across all screens | No screens break into light theme; all tokens applied | All |

---

## Out of Scope for B Track

The following are intentionally deferred to later tracks. TEs should not implement these speculatively:

- Social app screens (Track A — see Section B of this document)
- SSE backend endpoint (Track C1)
- FCM push notifications (Track C2)
- Image storage backend changes (Track C3)
- LLM-based content moderation (Track D0)
- Jobs board screens (Track E)
- Full-text search UI (Track F)
- In-app help system (Track G)
- Job Poster account portal / billing (Track E3)

---

*[Section A — Admin App ends here]*

---

## Section B — Social App (Flutter) — Actor: Social User

**Actors for this section:**

| Actor | Description | App Context |
|-------|-------------|-------------|
| **Social User** | Creative professional (hair stylist, MUA, photographer, etc.) using the app to discover events and network | Flutter social app (iOS, Android) |
| **New User** | First-time user going through onboarding before attending their first event | Flutter social app |
| **Job Seeker** | Verified creative professional browsing and applying to jobs | Flutter social app (Phase 4+) |
| **Job Poster** (employer) | Business or agent posting job listings via the social app or job poster portal | Flutter social app + job poster portal (Phase 4+) |

---

### Auth + Onboarding

| Workflow | Story | Acceptance Signal | Track |
|----------|-------|-------------------|-------|
| Phone login | As a new user, I enter my phone number and receive an SMS code, then enter the code to log in — I do not need to create a password | SMS code received within 30s; 6-digit entry auto-submits on last digit; correct code → authenticated | A0 |
| Dev code auto-fill | As a developer using a +1555555xxxx test number, the code returned by the API is auto-filled into the verify screen | devCode visible in API response; code pre-filled; one tap to confirm | A0 |
| Account auto-creation | As a first-time user, I am automatically registered when I verify my phone — I do not click "create account" separately | No separate registration step; verify success → account exists → profile setup | A0 |
| Profile setup (name) | As a new user, I set my display name and optionally add my specialties and bio during onboarding | Name required; specialties and bio optional; "Save & Continue" proceeds to main app | A0 |
| Specialty selection | As a user, I select one or more specialties (e.g., Hair Stylist, MUA, Photographer) from a platform-managed list | Specialty chips selectable; multi-select; primary specialty designation | A2 |
| Profile photo — onboarding | As a new user, I can add a profile photo during onboarding | Photo picker opens; image uploaded and shown in profile; fallback initials if skipped | A0 |
| Profile photo — edit | As an existing user, I can update my profile photo from the Edit Profile screen | Photo picker opens; image uploaded; profile updates after save | A0 |
| Delete account | As a user, I can permanently delete my account and all associated data from the app | Delete option in Settings; confirmation step; account deleted; auth tokens invalidated; logout triggered | A0 |
| Session persistence | As a returning user, I open the app and am already logged in — I do not re-enter my phone number | Access token / refresh token restored from secure storage; auto-refresh on startup | A0 |
| Token auto-refresh | As a user, my session continues seamlessly after 15 minutes without me having to log in again | `ApiClient.onTokenExpired` triggers refresh; new access token stored; in-flight request retried | A0 |

---

### Events

| Workflow | Story | Acceptance Signal | Track |
|----------|-------|-------------------|-------|
| Browse events | As a user, I see a list of upcoming events with name, date, venue, and hero image | Events list screen loads from `GET /events`; published events shown; hero image displayed | Pre-A0 |
| Event detail | As a user, I tap an event to see full details: name, dates, venue, description, and all images | Event detail screen loads from `GET /events/:id`; all available images shown | Pre-A0 |
| Check in — activation code | As a user at an event, I enter the activation code (given at the door) to check in | Activation code screen; code submission calls `POST /events/:id/checkin`; success confirmation | Pre-A0 |
| Check in — QR scan | As a user at an event, I can scan the venue's QR code instead of entering the code manually | QR scanner opens; decodes code; auto-submits; same success flow | Pre-A0 |
| Already checked in | As a user who has already checked in, tapping the check-in button shows me I'm already in rather than failing silently | 409 response from API → friendly "You're already checked in" message; no duplicate ticket | Pre-A0 |

---

### Networking — QR Connections

| Workflow | Story | Acceptance Signal | Track |
|----------|-------|-------------------|-------|
| Show my QR code | As a user, I open the Connect tab and see my personal QR code, ready to be scanned | QR code renders from `GET /users/me/qr`; displayed in Connect tab center | Pre-A0 |
| Scan someone's QR code | As a user, I tap the scan button, point my camera at another user's QR code, and the app creates a mutual connection instantly | QR scanner opens; scans code; `POST /connections` called; connection confirmed | Pre-A0 |
| Celebration overlay | As a user who just scanned someone, I see a celebration animation with the other person's name and photo | Celebration overlay renders 1–2 seconds after connection success | Pre-A0 |
| Connection notification — scanned user | As a user whose QR was just scanned, I see a notification or update in the app (without scanning anything) that someone connected with me | Polling `GET /connections` every 4 seconds; new connection → banner or Connect tab badge update | Pre-A0 |
| Already connected | As a user who tries to scan someone I'm already connected with, I see a friendly "Already connected" message rather than an error | 409 response → friendly message; no duplicate connection created | Pre-A0 |
| Auto-verification | As a user who has never connected before, my first QR connection automatically updates my verification status | After first connection, `verified` status reflected on profile | Pre-A0 |
| Connections list | As a user, I can see a list of everyone I've connected with (name, specialty, avatar) | Connections list screen loads from `GET /connections`; all connections shown | A2 |

---

### Community Board

| Workflow | Story | Acceptance Signal | Track |
|----------|-------|-------------------|-------|
| Browse feed | As a user, I open the Community tab and see the latest posts from the platform community with photos, text, and like counts | Feed loads from `GET /posts`; real posts displayed; infinite scroll works | A1 |
| Retention — quick load | As a hair stylist who checks the board daily, the feed loads in under 3 seconds on LTE and I can scroll without interruption | Feed latency <3s; no blocking spinner while scrolling; skeleton placeholders | A1 |
| Create post | As a verified user, I tap the compose button, write my post (with optional type tag), and see it appear in the feed after submitting | Create post screen; `POST /posts` called; new post appears optimistically in feed | A1 |
| Like a post | As a user, I double-tap or tap the heart icon on any post to like it; the count increases immediately | Like registered via `POST /posts/:id/like`; optimistic update; count increments | A1 |
| Unlike a post | As a user who liked a post, tapping the heart again unlikes it and the count decrements | Unlike via `DELETE /posts/:id/like`; optimistic update; count decrements | A1 |
| Comment on a post | As a user, I tap the comment icon, type a comment, and see it appear immediately in the thread | Comment submitted via `POST /posts/:id/comments`; optimistic append | A1 |
| Delete own comment | As a user who wrote a comment, I can delete my own comment by long-pressing or via a "Delete" option | Delete via `DELETE /posts/:id/comments/:commentId`; comment removed from thread | A1 |
| Report a post | As a user who sees spam or inappropriate content, I can report the post with one tap | Report action available on any post; report submitted; user sees "Thanks for reporting" confirmation | A1 |
| Post detail | As a user, tapping a post expands it to show the full content and all comments | Post detail screen loads `GET /posts/:id`; all comments visible | A1 |
| Infinite scroll | As a casual browser, I scroll down and more posts load automatically — I don't need to tap "load more" | Next page fetched when user scrolls within ~200px of bottom; no gap | A1 |
| Post author tap | As a user reading the feed, tapping a post author's name or avatar takes me to their profile | Author tap → navigate to `/users/:authorId`; UserProfileScreen loads | A2 |

---

### User Search + Profiles

| Workflow | Story | Acceptance Signal | Track |
|----------|-------|-------------------|-------|
| Search users | As a user, I type a name or specialty in the Search tab and see matching profiles appear | Search calls `GET /users?q=` with debounce; results list renders within 300ms of stopping typing | A2 |
| Recent searches | As a returning user, the search screen shows my recent searches before I type | Recent search pills shown on screen focus; tapping a pill pre-fills and runs search | A2 |
| Empty search state | As a user who searches and finds nothing, I see a clear "No results" message — not a blank screen | EmptyState widget shown with search term and suggestion | A2 |
| View another user's profile | As a user who found someone interesting, I tap their name and see their full profile: photo, name, specialties, bio, post count, connection count, and their recent posts | UserProfileScreen loads; all sections populated; connection status visible | A2 |
| Connect from profile | As a user viewing someone's profile, I can initiate a connection (if QR codes aren't available) | Connect button visible on other user's profile if not yet connected | A2 |
| View my own profile | As a user tapping my own name, I see "my profile" view with an Edit button instead of a Connect button | Own profile: Edit button visible; Connect button hidden | A2 |
| Edit profile | As a user, I navigate to Edit Profile and update my bio, specialties, or social links | Edit profile screen pre-populated; `PATCH /users/me` submitted on save; profile updates | A2 |
| Social links | As a user, I add my Instagram, TikTok, or website link to my profile | Social links fields in edit profile; displayed on user profile screen for others to tap | A2 |

---

### Perks + Sponsors

| Workflow | Story | Acceptance Signal | Track |
|----------|-------|-------------------|-------|
| Browse perks | As a creative professional, I open the Perks tab and see available discounts and offers from event sponsors | Perks screen loads from `GET /discounts`; all active discounts visible with logo and description | A3 |
| Perk — view details | As a user interested in a perk, I tap it and see full details: sponsor name, logo, offer description, and "I Used This" button | Perk detail / sponsor detail screen loads; all fields populated | A3 |
| Redeem a perk | As a user who used a perk (e.g., free haircut), I tap "I Used This" to self-report the redemption | `POST /discounts/:id/redeem` called; button changes to "✓ Used" state; idempotent | A3 |
| Already-redeemed state | As a returning user who already redeemed a perk, I see the "✓ Used" state immediately on load | Redemption status loaded on screen init; correct state shown without repeat API call | A3 |
| Offline graceful degradation | As a user with no internet connection opening the Perks tab, I see cached content with a subtle "offline" indicator | Cached perks shown if available; offline indicator rendered; no crash | A3 |
| Sponsor discovery | As a user browsing perks, I can see which sponsor is offering each perk and navigate to their profile | Sponsor name + logo tap → sponsor detail screen | A3 |

---

### Settings + Account

| Workflow | Story | Acceptance Signal | Track |
|----------|-------|-------------------|-------|
| Access settings | As a user, I tap the gear icon or "Settings" option on my profile to access account settings | Settings screen accessible from profile; renders correctly | A0 |
| Log out | As a user, I can log out of the app from Settings | Logout calls `POST /auth/logout`; tokens cleared; navigated back to phone entry screen | A0 |
| Delete account — confirm | As a user who decides to leave, I can initiate account deletion from Settings with a clear warning about what will be lost | Delete flow shows a confirmation step; cannot be accidentally triggered | A0 |

---

### Jobs Board (Phase 4+)

| Workflow | Story | Acceptance Signal | Track |
|----------|-------|-------------------|-------|
| Jobs tab visibility | As a user, the Jobs tab only appears in the bottom navigation when the `feature.jobs_board` platform flag is enabled | Jobs tab hidden when flag off; 4-tab nav shown; Jobs appears as 5th tab when enabled | E1 |
| Browse jobs | As a creative professional, I open the Jobs tab and see available job listings with type, specialty requirements, and compensation | Jobs list loads from `GET /jobs`; cards show title, type badge, compensation, specialty chips, location | E1 |
| Filter jobs | As a job seeker, I filter by specialty, job type (freelance, full-time, etc.), and location type | Filter chips on jobs list; each selection refreshes list with debounce | E1 |
| Job detail | As a job seeker, I tap a job listing to see the full description, requirements, and compensation details | Job detail screen loads from `GET /jobs/:id`; all sections visible | E1 |
| Apply to a job | As a job seeker, I tap "Apply" and submit my application with an optional cover note | Apply sheet opens; `POST /jobs/:id/apply` called; button changes to "✓ Applied" | E1 |
| Track applications | As a job seeker, I can see all my pending and confirmed applications in one place | Applications list screen; filter by status (pending, accepted, rejected) | E1 |
| Post a job | As a verified job poster, I can create a job listing with title, description, specialty, and compensation | Job posting flow; `POST /jobs` called (employer-verified accounts only) | E1 |
| Hire confirmation | As a job poster, I can initiate a hire confirmation after hiring someone; both parties must confirm | Hire confirmation flow; both parties receive notification; bidirectional confirm required | E2 |
| Rate a worker | As a job poster who completed a hire confirmation, I can leave a verified rating for the worker | Rating form available only post-hire confirmation; `POST /ratings` called | E2 |

---

*[Section B — Social App ends here]*

---

## Section C — System Actors (Automated Pipelines + Backend Services)

**About system stories:** These define what the system (not a human) must do in response to triggers. Each story follows the format:

> **When** [trigger] → **the system must** [action] **within** [SLA] → **on failure** [fallback behavior] → **observable via** [signal]

These stories drive Track C (backend services), Track D (moderation + analytics), and Track E (jobs) backend specs. They are testable as integration or unit tests.

---

### US-SYS-001 — Posh Webhook: New Order

| Field | Value |
|-------|-------|
| **Trigger** | `POST /webhooks/posh` with `new_order` event and valid `X-Posh-Signature` header |
| **Action** | Validate HMAC signature; upsert `posh_orders` row (idempotent on `posh_order_id`); if buyer phone matches existing user, link `user_id`; send invite SMS (if no user) or welcome SMS (if user exists); send welcome email |
| **SLA** | Webhook returns `200` within 500ms; SMS delivery via Twilio is async |
| **Failure: invalid signature** | Return `401`; no record created; log attempt |
| **Failure: SMS unavailable** | Write `posh_orders` row; skip SMS; log warning; return `200` (webhook must acknowledge) |
| **Observable via** | `posh_orders` row in DB; `audit_log` entry; Twilio send log |
| **Track** | Pre-existing (webhooks.ts) + C1 missing endpoint additions |

---

### US-SYS-002 — QR Scan → Mutual Connection → FCM Notification

| Field | Value |
|-------|-------|
| **Trigger** | `POST /connections` with valid JWT and `targetUserId` |
| **Action** | Create mutual connection record (idempotent: 409 if already exists); set both users to `verified` if first connection; send FCM push to `targetUser.fcm_token` with title "New Connection!" and `type: 'new_connection'` data payload |
| **SLA** | Connection record created within 200ms; FCM send is fire-and-forget (non-blocking) |
| **Failure: already connected** | Return `409`; no duplicate; no FCM send |
| **Failure: FCM unavailable** | Connection still created; FCM skipped silently; log warning |
| **Failure: targetUser has no fcm_token** | FCM send skipped silently; no error |
| **Observable via** | `connections` row; `users.verification_status` updated; FCM delivery log (when available) |
| **Track** | C2 (FCM) |

---

### US-SYS-003 — Event Check-In → SSE Broadcast

| Field | Value |
|-------|-------|
| **Trigger** | Attendee submits activation code via social app (`POST /events/:id/checkin`) |
| **Action** | Create or validate ticket; broadcast `checkin` SSE event to all connected admin clients subscribed to `GET /admin/events/:id/checkins/stream` with attendee name, avatar, specialty, ticket type (Posh / walk-in), timestamp |
| **SLA** | SSE event delivered to connected admin clients within 500ms of API response |
| **Failure: no admin clients connected** | Ticket created; SSE broadcast attempted; no failure if no subscribers |
| **Failure: SSE connection dropped** | Client auto-reconnects via `EventSource`; receives snapshot of last 50 check-ins on reconnect |
| **Observable via** | `tickets` row; admin React Event Ops screen updates in real time |
| **Track** | C1 |

---

### US-SYS-004 — Wristband Issued → FCM to Attendee

| Field | Value |
|-------|-------|
| **Trigger** | Event Ops staff taps "Issue Wristband" in React admin → `PATCH /admin/events/:eventId/attendees/:ticketId/wristband` |
| **Action** | Set `tickets.wristband_issued_at = NOW()`; look up attendee's `fcm_token`; send FCM push with title "🎉 You're in!" and `type: 'wristband_confirmed'`, `eventId` data; broadcast `wristband` SSE event to all admin clients on the event's stream |
| **SLA** | DB write within 100ms; FCM fire-and-forget; SSE broadcast within 500ms |
| **Failure: FCM** | Wristband still marked issued; FCM skipped silently |
| **Failure: attendee has no fcm_token** | Wristband still marked; FCM skipped |
| **Observable via** | `tickets.wristband_issued_at`; admin feed shows ✅ update; attendee phone receives push |
| **Track** | C1 (endpoint), C2 (FCM integration) |

---

### US-SYS-005 — Post Created → Moderation Queue

| Field | Value |
|-------|-------|
| **Trigger** | `POST /posts` succeeds → post record created with `moderation_status = 'pending'` |
| **Action** | Enqueue moderation job (Bull queue or SQS) with `{postId, content, authorId, timestamp}`; Stage 1: invoke Haiku classifier; if confidence > 0.7 → auto-approve or auto-reject; if 0.3 ≤ confidence ≤ 0.7 → Stage 2: invoke Sonnet classifier; if still ambiguous → flag for human review; write result to `moderation_results`; update `posts.moderation_status` and `posts.is_hidden` |
| **SLA** | Stage 1 (Haiku) completes within 2s; Stage 2 (Sonnet) within 10s; human-flagged posts visible in admin queue within 30s |
| **Failure: LLM unavailable** | Post remains `moderation_status = 'pending'`; `is_hidden = false` (fail-open, posts visible); admin notified via queue backlog alert |
| **Failure: queue full** | Post remains pending; admin alert fired; SLA degraded gracefully |
| **Observable via** | `posts.moderation_status`; `moderation_results` row; admin React Moderation queue shows flagged posts |
| **Track** | D0 |

---

### US-SYS-006 — Image Upload → CSAM Scan + S3 Write

| Field | Value |
|-------|-------|
| **Trigger** | `POST /admin/events/:id/images` or `POST /users/me/photo` receives multipart image file |
| **Action** | Run CSAM scan (AWS Rekognition ModerationLabels + NCMEC hash check) synchronously before any S3 write; if scan flags explicit content → return `422 Unprocessable Content`, write scan decision to audit log (NOT flagged content metadata), stop; if clean → resize/compress via sharp, upload to S3, create `image_assets` record, compute pHash, check near-duplicates, return asset |
| **SLA** | Scan + upload completes within 3s for images ≤ 5MB |
| **Failure: scan service unavailable** | Return `503 Service Unavailable`; no S3 write; no partial asset record; admin sees error |
| **Failure: S3 unavailable** | Return `503`; no asset record; scan result discarded |
| **Observable via** | `image_assets` row on success; `audit_log` entry for rejected uploads; no S3 object written on rejection |
| **Architecture flag** | **UNRESOLVED — requires Jeff decision before C3 executes.** See `docs/product/master_plan_v3.md` §7 for options analysis. |
| **Track** | C3 (image assets + CSAM gate) |

---

### US-SYS-007 — Nightly Analytics Aggregation

| Field | Value |
|-------|-------|
| **Trigger** | Nightly cron job at 02:00 UTC (configurable via `platform_config`) |
| **Action** | Aggregate daily stats into `analytics_connections_daily`, `analytics_users_daily`, `analytics_events`; recompute `analytics_influence` scores (PageRank variant weighted by attendance, connections, post engagement). All writes are idempotent (upsert on date key). |
| **SLA** | Job completes within 60 minutes; if > 60 min, send alert |
| **Failure: DB unavailable** | Retry 3× with exponential backoff; log failure; skip day (next night's run will compute cumulative) |
| **Failure: influence computation error** | Log error per user; skip that user; continue batch |
| **Observable via** | `analytics_*` table row counts; `llm_usage_log` entries for LLM calls (if any); alert if job fails |
| **Track** | D1 |

---

### US-SYS-008 — Event Wrap Report Generation

| Field | Value |
|-------|-------|
| **Trigger** | 24 hours after `events.end_time` for any event with `status = 'completed'` |
| **Action** | Collect event data (attendance, connections made, posts created, top influencers, Posh order count, walk-in count, check-in duration histogram); draft report using Sonnet LLM; store draft in `event_wrap_reports`; create admin notification for review; wait for admin approval before distribution |
| **SLA** | Draft generated within 5 minutes of trigger; admin notification within 1 minute of draft |
| **Failure: LLM unavailable** | Log failure; retry in 1 hour; alert admin after 3 failures |
| **Failure: event has no data** | Generate minimal report ("No attendance data available"); still create record |
| **Observable via** | `event_wrap_reports` row; admin React Analytics → Event Reports screen shows pending review; `llm_usage_log` entry |
| **Track** | D1 |

---

### US-SYS-009 — FCM Token Refresh + Stale Token Cleanup

| Field | Value |
|-------|-------|
| **Trigger** | Flutter app `onTokenRefresh` callback fires; OR FCM API returns `messaging/registration-token-not-registered` on any send attempt |
| **Action (refresh)** | `PATCH /users/me/device-token` with new token → update `users.fcm_token` |
| **Action (stale on send)** | Set `users.fcm_token = NULL` for the affected user; log stale token event |
| **SLA** | Token update lands in DB within 200ms of API call |
| **Failure: API unavailable on refresh** | SDK retries next app launch; no data loss |
| **Observable via** | `users.fcm_token` column; FCM send log (delivery rate recovers after cleanup) |
| **Track** | C2 |

---

### US-SYS-010 — Platform Config Hot Reload

| Field | Value |
|-------|-------|
| **Trigger** | `PATCH /admin/platform-config/:key` succeeds |
| **Action** | Update `platform_config` row; create `audit_log` entry (action: `update`, entity: `platform_config`, entity_id: key, old_val, new_val); broadcast config change to any subscribed services (if polling interval applies); feature flags take effect on next config read by API services |
| **SLA** | DB write within 100ms; audit log within 100ms; feature flag effective within the API service's config poll interval (default: next request) |
| **Failure: invalid value for key** | Return `400` with validation error; no write; no audit entry |
| **Observable via** | `platform_config` row; `audit_log` entry; feature behavior changes on next relevant API call |
| **Track** | C4 |

---

### US-SYS-011 — GDPR Data Export Request

| Field | Value |
|-------|-------|
| **Trigger** | `POST /users/me/export` called by authenticated social user |
| **Action** | Create `data_export_requests` row with `status = 'pending'`; enqueue async export job; job collects: profile, connections, posts, comments, tickets, ratings, redemptions; package as JSON archive; upload to private S3 URL (signed, 48h expiry); send download link via SES email; update row to `status = 'complete'` |
| **SLA** | Email delivered within 60 minutes of request |
| **Failure: S3 unavailable** | Retry; alert admin after 3 failures; user receives "export delayed" email |
| **Failure: SES unavailable** | Store S3 URL in DB; retry email; user sees pending status in app |
| **Observable via** | `data_export_requests` status; S3 object; SES send log |
| **Track** | C1 (endpoint) |

---

### US-SYS-012 — Job Application Status Change → FCM

| Field | Value |
|-------|-------|
| **Trigger** | Job poster changes application status (`PATCH /jobs/:id/applications/:appId`) to `accepted` or `rejected` (Phase 4+) |
| **Action** | Update `job_applications.status`; send FCM push to applicant with title "Application Update" and `type: 'job_application_status'`, `status`, `jobTitle` data |
| **SLA** | FCM fire-and-forget; non-blocking |
| **Failure: FCM unavailable** | Status update still persists; FCM skipped silently |
| **Observable via** | `job_applications.status`; applicant notification received |
| **Track** | E1 (job board), C2 (FCM integration) |

---

### US-SYS-013 — Hire Confirmation: Bidirectional Confirm → Rating Unlock

| Field | Value |
|-------|-------|
| **Trigger** | Second party confirms hire via `PATCH /hire-confirmations/:id` with `confirmed = true` |
| **Action** | Set `hire_confirmations.status = 'confirmed'`; set both-party `confirmed_at` timestamps; unlock rating capability (job poster can now call `POST /ratings` for this hire); send FCM to both parties confirming the hire |
| **SLA** | DB write + FCM within 300ms |
| **Failure: FCM** | Hire still confirmed; FCM skipped silently |
| **Observable via** | `hire_confirmations.status = 'confirmed'`; rating endpoint no longer returns 403 for this hire; FCM delivery |
| **Track** | E2 |

---

### US-SYS-014 — Admin Login Audit Logging

| Field | Value |
|-------|-------|
| **Trigger** | `POST /admin/auth/login` completes (success or failure) |
| **Action** | On success: write `audit_log` entry (action: `login`, actor: adminUserId, ip_address, user_agent); set `admin_users.last_login_at = NOW()`. On failure (wrong password): write `audit_log` entry (actor: null, email attempted, ip_address, failure_reason) |
| **SLA** | Audit log written within 100ms of response |
| **Failure: audit log DB write fails** | Login still succeeds (auth flow is not blocked by audit); log the audit failure to stderr |
| **Observable via** | `audit_log` rows with action `login`; admin React Platform → Audit Log screen |
| **Track** | B1 (auth) |

---

### US-SYS-015 — Influence Score: Daily Recomputation

| Field | Value |
|-------|-------|
| **Trigger** | Nightly cron job (same batch as US-SYS-007, or separate job at 03:00 UTC) |
| **Action** | For each active user: compute influence score as weighted PageRank variant — inputs: event attendance count (weight 1×), QR connection count (weight 2×), post like count (weight 0.5×), verified status bonus (1.5× multiplier); upsert `analytics_influence` row; update `users.influence_score` (denormalized for fast sorting) |
| **SLA** | Full recomputation completes within 30 minutes for ≤ 50,000 users |
| **Failure: computation error for a user** | Skip that user; log error; continue batch; previous score retained |
| **Observable via** | `analytics_influence` rows; `users.influence_score` field; admin Analytics → Influence Scores leaderboard |
| **Track** | D2 |

---

*[Section C — System Actors ends here]*

---

## Amendment Log

*Managed by Track Control. Each row records a user story that was amended after implementation. The original text is preserved here for lessons-learned tracing. The table rows above reflect current truth (post-amendment).*

*TC instructions: when a TE deviates from a story and TC action is "Update", amend the table row above to reflect what was actually built, then add a row here with the original text. For "Accept" decisions, the table row stays as written (it remains the intent reference); add a note here only if the deviation is worth capturing for future TEs. For "Flag" decisions, add a row here and hold for Jeff before touching the table.*

| Date | Prompt | Story (short label) | Section | Original Text | Amended Text | Reason | TC Action |
|------|--------|---------------------|---------|---------------|--------------|--------|-----------|
| — | — | — | — | (no amendments yet) | — | — | — |
