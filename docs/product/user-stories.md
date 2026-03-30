# Industry Night — User Stories

**Version:** 1.0 — B-Track (React Admin App)  
**Status:** Draft — Jeff review pending  
**Last Updated:** 2026-03-26  
**Scope:** Track B (B0–B3) — React Admin App: scaffold, auth, event ops, and full admin parity  
**Next scope:** A-Track (social app), C-Track (backend), D/E/F/G-Track expansions — to be added after B-track review

---

## How To Use This Document

This document is **fuel for Track Execution (TE) agents.** It defines explicit functional requirements as user stories — what users need to accomplish and what the system must do to support it. It does NOT specify HOW to implement (that's in the prompt specs and CLAUDE.md).

**Hierarchy:**
- This doc + the mockup (`docs/design/admin-mockup-v2.html`) define **what** to build
- CODEX prompt specs define **scope, phasing, and acceptance criteria** for each TE session
- CLAUDE.md defines **data models, API routes, and infrastructure ground truth**
- TEs exercise judgment on implicit behavior (micro-interactions, error copy, loading states) — this doc covers explicit requirements only

**Format:** Table per actor group. Columns: Workflow | Story | Acceptance Signal | Track/Prompt

---

## Actors — B Track

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

- Social app screens (Track A)
- SSE backend endpoint (Track C1)
- FCM push notifications (Track C2)
- Image storage backend changes (Track C3)
- LLM-based content moderation (Track D0)
- Jobs board screens (Track E)
- Full-text search UI (Track F)
- In-app help system (Track G)
- Job Poster account portal / billing (Track E3)

---

*Next section to be added: A-Track (Social App) — pending Jeff review of B-Track section.*

---

## Amendment Log

*Managed by Track Control. Each row records a user story that was amended after implementation. The original text is preserved here for lessons-learned tracing. The table rows above reflect current truth (post-amendment).*

*TC instructions: when a TE deviates from a story and TC action is "Update", amend the table row above to reflect what was actually built, then add a row here with the original text. For "Accept" decisions, the table row stays as written (it remains the intent reference); add a note here only if the deviation is worth capturing for future TEs. For "Flag" decisions, add a row here and hold for Jeff before touching the table.*

| Date | Prompt | Story (short label) | Section | Original Text | Amended Text | Reason | TC Action |
|------|--------|---------------------|---------|---------------|--------------|--------|-----------|
| — | — | — | — | (no amendments yet) | — | — | — |
