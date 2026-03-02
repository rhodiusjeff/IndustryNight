# Social Network Expert Analysis — Industry Night

**Date:** 2026-03-02
**Scope:** Missing social features, data value proposition, sponsor/vendor monetization, engagement gaps, and prioritized recommendations.
**Audience:** Product owner, development team, future chat sessions needing social-layer context.

---

## Table of Contents

1. [What IN Actually Is](#1-what-in-actually-is)
2. [Current Social Feature Inventory](#2-current-social-feature-inventory)
3. [The Data Asset](#3-the-data-asset)
4. [Missing Social Features](#4-missing-social-features)
5. [The Engagement Gap](#5-the-engagement-gap)
6. [Sponsor/Vendor Value Proposition](#6-sponsorvendor-value-proposition)
7. [Gotchas and Risks](#7-gotchas-and-risks)
8. [Prioritized Recommendations](#8-prioritized-recommendations)
9. [Glossary of Marketing/Monetization Concepts](#9-glossary-of-marketingmonetization-concepts)

---

## 1. What IN Actually Is

### Network Taxonomy

Industry Night is an **event-first, proximity-verified social network** for creative professionals (hair stylists, makeup artists, photographers, videographers, producers, directors). It occupies a specific niche in social networking:

| Dimension | IN's Model | Contrast |
|-----------|-----------|----------|
| Graph creation | Physical QR scan at events | LinkedIn: digital requests. Instagram: follow from anywhere |
| Trust signal | "I physically met this person" | Most platforms: no trust signal on connection |
| Verification | Behavioral (attend + connect) | LinkedIn: self-reported. Twitter/X: pay-to-verify |
| Content focus | Community board (not yet live) | Instagram: content-first. LinkedIn: content + jobs |
| Monetization path | Sponsor/vendor partnerships | Most: ads. Some: subscriptions |

### The Verification Ladder

IN uses a behavioral verification model where trust is earned through real-world actions:

```
registered  -->  checked_in  -->  verified
     |                |               |
     |                |               +-- Made first QR connection at an event
     |                +-- Entered activation code at event door (has ticket)
     +-- Downloaded app, registered via SMS OTP
```

Each tier unlocks features (enforcement tracked in GitHub #14):
- **registered** --> browse events, set up profile, search creatives
- **checked_in** --> QR networking at events
- **verified** --> community board, sponsor discounts, persistent QR networking

### What Makes This Model Defensible

Every connection in the IN graph carries implicit proof of physical co-presence. A photographer connected with a makeup artist at "Industry Night NYC Feb 2026" is a *verified professional relationship*, not a random follow. This is qualitatively different from any digital-only social network and is IN's single most defensible differentiator.

> **MARKETING NUANCE:** When pitching sponsors, the message is NOT "we have X users" — it's "every connection in our network represents two professionals who physically met at one of your events." That's qualitatively different from impression counts, follower numbers, or click-through rates. It represents a real-world professional relationship.

---

## 2. Current Social Feature Inventory

### What's Real (wired to API, working end-to-end)

| Feature | Description | Key Files |
|---------|-------------|-----------|
| **QR-based instant connections** | Scan someone's QR code --> instant mutual connection, celebration overlay, auto-verify on first connection | `connect_tab_screen.dart`, `qr_scanner_screen.dart`, `connections.ts` |
| **Connections list** | View all connections with name, photo, specialties. Pull-to-refresh, swipe-to-delete | `connections_list_screen.dart`, `NetworkingState` |
| **Polling-based notifications** | When QR displayed, polls every 4s for incoming connections. Shows celebration overlay | `NetworkingState` in `networking_state.dart` |
| **Profile editing** | Name, email, bio, specialties. Validates, saves to API | `edit_profile_screen.dart`, `AppState.updateProfile()` |
| **Event browsing** | Upcoming events list, sorted by ticket status. Hero images, venue, date/time | `events_list_screen.dart`, `EventsApi` |
| **Event check-in** | QR scan or manual 4-digit activation code. Validates ticket + code server-side | `activation_code_screen.dart`, `events.ts` |
| **Ticket display** | Shows ticket status on events (purchased, checked in). Links to Posh for purchase | `event_detail_screen.dart` |
| **User search (backend only)** | `GET /users?q=&specialties=` — text + specialty filtering | `users.ts` route |

### What's Stub (UI exists, zero API integration)

| Feature | Current State | Key Files |
|---------|---------------|-----------|
| **Community feed** | 10 hardcoded fake PostCards | `community_feed_screen.dart` |
| **Create post** | `Future.delayed` fake submission | `create_post_screen.dart` |
| **Post detail** | All static: hardcoded author, content, counts, comments | `post_detail_screen.dart` |
| **User search (UI)** | Hardcoded 10 dummy results | `search_screen.dart` |
| **Other user profiles** | Hardcoded stats, specialties, social links | `user_profile_screen.dart` |
| **Perks/sponsors** | Hardcoded sponsor list + discount codes | `perks_screen.dart`, `sponsor_detail_screen.dart` |
| **Saved posts** | Menu item exists, no functionality | `my_profile_screen.dart` |

### What Doesn't Exist At All

| Feature | Status |
|---------|--------|
| Direct messaging | No tables, no endpoints, no UI |
| Push notifications | No FCM/APNs integration |
| In-app notifications | No notification system |
| Portfolio / work showcase | No schema, no UI |
| Endorsements / recommendations | No concept |
| Mutual connections display | Not computed or displayed |
| Activity feed ("X liked Y's post") | Not a feature |
| Event-specific chat | Not a feature |
| Share externally (profiles, events, posts) | Not implemented |
| Hashtags / topics | Not a feature |

### Backend Layer (API + Database) — Posts System

The posts backend is **complete with bugs** — it exists and is functional but has known issues that must be fixed before wiring the Flutter UI:

| Layer | Status | Details |
|-------|--------|---------|
| **DB tables** | Complete | `posts` (with type, is_pinned, is_hidden, like_count, comment_count), `post_comments`, `post_likes` |
| **API routes** | Complete (with bugs) | Full CRUD, like/unlike, comments |
| **Shared Dart model** | Complete (with shape mismatch) | `Post`, `PostComment` models |
| **Shared API client** | Complete (with bug) | `PostsApi` with all methods |

**Known bugs (prerequisites before wiring — from adversarial review §2.3):**
- B1: SQL injection — `userId` interpolated directly in `posts.ts` lines 40, 63
- B2: `PostsApi.unlikePost()` casts void to Map --> TypeError at runtime
- B3: `GET /posts/:id/comments` lacks `authenticate` middleware
- B4: `DELETE /posts/:id/comments/:commentId` endpoint doesn't exist

**Data shape mismatch:** API returns flat `author_name`/`author_photo` fields, but Dart `Post` model expects nested `User` object (always null). Fix: add `authorName`/`authorPhoto` fields to Post model.

---

## 3. The Data Asset

IN captures data that most social platforms don't, because of the event-first model. This section inventories what data exists, what's derivable, and what it's worth.

### Tier 1 — Exists and Works Today

| Data | Source | Current Use | Latent Value |
|------|--------|-------------|--------------|
| **Specialty distribution** | `users.specialties` (TEXT array, GIN-indexed) | Profile display, search filter | "62% of attendees were hair stylists" — tells sponsors who shows up |
| **Cross-specialty pairings** | `connections` table (user_a + user_b, each with specialties) | None | "Photographers connect with MUAs 3x more than with videographers" — affinity intelligence |
| **Event attendance** | `tickets.status = 'checkedIn'` + `posh_orders.checked_in_at` | Attendee count on event detail | Per-event demographic breakdown by specialty |
| **Connection graph** | `connections` table (user_a_id, user_b_id, event_id, created_at) | Connections list | Network analysis: clusters, bridges, influence |
| **Temporal patterns** | `connections.created_at` | None | "Most connections happen in first 90 minutes" — event design insight |
| **Consent flags** | `users.analytics_consent`, `users.marketing_consent` | Stored but not enforced | Ethical basis for audience data sharing with sponsors |
| **Profile visibility** | `users.profile_visibility` (public/connections/private) | Stored but not enforced | Privacy controls for user trust |

### Tier 2 — Schema Exists, Not Populated/Computed

| Data | Table | What It Would Contain | Why It Matters |
|------|-------|-----------------------|---------------|
| **Influence scores** | `analytics_influence` | connection_count, events_attended, network_reach (2nd-degree), specialty_rank, city_rank, influence_score | Identifies top networkers per specialty per market. "Here are the 10 most connected photographers in NYC." |
| **Cross-specialty rates** | `analytics_events.cross_specialty_rate` | Percentage of connections at an event that cross specialty lines | Measures whether events achieve their stated goal of cross-disciplinary networking |
| **Daily user/connection stats** | `analytics_users_daily`, `analytics_connections_daily` | new_users, active_users, verified_users, checkins by city + specialty + date | Trend lines for growth reporting to sponsors |
| **Event performance** | `analytics_events` | total_checkins, unique_attendees, connections_made, top_specialties, avg_connections_per_user | The "event scorecard" that sponsors would pay to see |

> **MARKETING NUANCE:** These analytics tables were designed with privacy in mind from the start — they store *aggregated* data, not individual records. `analytics_connections_daily` tracks specialty pairings by city and date, never individual connection records. `analytics_influence` requires `analytics_consent = true`. This is the right architecture for compliant audience intelligence.

### Tier 3 — Doesn't Exist But Is Derivable

| Insight | How to Derive It | Value |
|---------|-----------------|-------|
| **Repeat attendance rate** | Query `tickets` grouped by `user_id` across events | "35% of attendees are repeat visitors" — retention metric sponsors care about |
| **Connection activation rate** | `COUNT(connections WHERE event_id = X) / COUNT(tickets WHERE event_id = X AND status = 'checkedIn')` | "Average attendee makes 4.2 connections per event" — engagement proof |
| **Specialty growth trends** | `analytics_users_daily` over time (requires population job) | "MUA registrations up 40% month-over-month" — market signal |
| **Geographic density** | Future `market_area` on users (#19) | "180 verified creatives in NYC metro" — local sponsor targeting |
| **Network clusters** | Graph analysis on connections (BFS/DFS from seed users) | Identifies tightly-connected groups — useful for targeted perks |
| **Event ROI per sponsor** | `event_sponsors` + attendance data + discount redemptions | "Your sponsorship of Event X reached 150 hair professionals; 42 redeemed your code" |

> **MARKETING NUANCE — "Audience Intelligence":** There's a concept in B2B sales called **audience intelligence**. It's the difference between telling a sponsor "we had 200 people at the event" vs. "we had 200 people: 45% hair stylists, 25% MUAs, 15% photographers, 15% other. Hair stylists connected with MUAs at 3x the rate of any other pairing. Your brand was seen by 120 hair professionals who are actively networking." The second version commands 5-10x the sponsorship price. IN has the raw data for version two — it just needs the computation and reporting layer.

---

## 4. Missing Social Features

Assessed in three tiers based on impact to user retention and platform value.

### Critical for Retention

Without these, users download the app, attend one event, and never open it again.

#### A. Working Community Feed (tracked in #18)

The community feed is what turns IN from a "QR scanner you use once a month" into a daily-open app. It's the single most important stub to wire.

Detailed implementation plan exists in `adversarial_review.md` §2.3 — 6 chunks covering backend fixes, CommunityState provider, feed wiring, create post wiring, detail screen wiring, and moderation.

The feed supports 4 post types: `general`, `collaboration`, `job`, `announcement`. The `collaboration` and `job` types are particularly valuable — they give creatives a reason to post between events ("Looking for a photographer for a shoot on March 15th").

#### B. Messaging (NOT yet tracked)

This is the biggest functional gap. Users create instant connections at events — then what? They exchange Instagram handles or phone numbers because IN has no way to continue the conversation. **Every connection that moves to Instagram/iMessage is a user who doesn't need to open IN again.**

Recommended approach (in order of complexity):

| Option | Description | Effort | Retention Impact |
|--------|-------------|--------|-----------------|
| **Connection-only DMs** | Simple 1:1 messaging between connected users only | Medium-Large | Very High |
| **Event group chat** | Auto-group for everyone checked into an event | Medium | High |
| **Collaboration threads** | Structured "I'm looking for X" with responses (extends `collaboration` post type) | Medium | Medium-High |

The QR-based connection gate is a natural spam filter — you can only message people you physically met. This is a significant advantage over platforms where anyone can DM anyone.

> **MARKETING NUANCE — Messaging as a Double-Edged Sword:** Messaging keeps users in-app (good), but it's also where abuse happens (bad). For a creative professionals network, connection-only DMs with a report button is the sweet spot. You don't need to build WhatsApp — you need just enough to say "great meeting you, want to shoot together next week?" The connection gate (must physically QR-scan to connect) is a natural anti-spam mechanism that most platforms would kill for.

#### C. Push Notifications (NOT yet tracked)

Without push notifications, the app has no way to pull users back between events. There is currently zero notification infrastructure — no FCM/APNs integration, no notification service.

Critical notification triggers:
- "You have a new connection!" (currently only detected via polling while QR screen is open)
- "New event in [your market area]" (when event published)
- "[Connection name] posted in the community" (feed engagement)
- "[Sponsor] has a new perk for verified members" (perk discovery)
- "Reminder: Industry Night NYC is tomorrow" (event attendance)

### Important for Value

These features make the platform meaningfully stickier and richer.

#### D. Profile Portfolio / Work Showcase

Creative professionals' primary currency is their work. The profile currently captures name, bio, and specialties — but no portfolio. A photographer's profile should show their best shots. A MUA's profile should show their looks.

This could be as simple as a "featured work" image grid on the profile (3-6 images). It makes profiles worth visiting, which makes connections worth tapping, which increases engagement.

Schema consideration: either a `portfolio_images` table (similar to `event_images`) or a JSONB array on the `users` table. The former is more flexible (captions, ordering, upload management).

#### E. Mutual Connections ("People You Both Know")

When viewing another user's profile, showing "12 mutual connections" provides social proof and context. It's a 2nd-degree graph query that's computationally straightforward:

```sql
SELECT c2.user_b_id FROM connections c1
JOIN connections c2 ON c2.user_a_id = c1.user_b_id OR c2.user_b_id = c1.user_a_id
WHERE c1.user_a_id = :currentUser OR c1.user_b_id = :currentUser
  AND (c2.user_a_id = :otherUser OR c2.user_b_id = :otherUser)
```

The canonical LEAST/GREATEST ordering makes this query slightly more complex but the connections table is already indexed.

#### F. Connection Context

Currently a connection record is: `userA ↔ userB, eventId, createdAt`. Adding context makes the connections list more meaningful:

| Enhancement | Description | Effort |
|-------------|-------------|--------|
| Event name display | "Met at Industry Night NYC, Feb 2026" (derivable from existing `event_id --> events.name`) | Small |
| Personal notes | "Great photographer, wants to collab on editorial" (new `notes` TEXT field on connections) | Small |
| Last interaction | When you last messaged / liked their post (requires messaging or feed) | Deferred |

#### G. "People at This Event" Discovery

For users checked into an event: show a grid of other checked-in users (name, photo, specialty). This is the digital equivalent of looking around the room.

Pre-event variant: "Who's Going" — connections who have tickets (deferred behind feature flag, tracked in #17).

### Nice-to-Have (Future Differentiators)

| Feature | Description | Value | Effort |
|---------|-------------|-------|--------|
| **Endorsements** | "Great to work with" badges on profiles | Social proof; trusted recommendations within verified network | Medium |
| **Structured collaboration board** | "Looking for MUA for shoot on 3/15" with structured fields (date, location, pay, specialties needed) | Extends `collaboration` post type into a marketplace | Medium |
| **Availability status** | "Open to bookings this month" toggle on profile | Facilitates professional connections | Small |
| **External share** | Share profile/event/post via native share sheet | Viral growth mechanism: "Check out my IN profile" | Small |
| **Hashtag/topic system** | Tag posts with topics for discovery | Content organization and trending topics | Medium |
| **Saved/bookmarked posts** | Bookmark posts for later reference | Content curation (menu item already exists as stub) | Small |
| **Recurring events** | "Duplicate event" admin feature | Operational efficiency; events often recur monthly | Small |
| **Event save/bookmark** | "Interested" button on events for non-ticket-holders | Intent signal; marketing funnel data | Small |

---

## 5. The Engagement Gap

### The Problem

Here's the current user lifecycle:

```
Download --> Register --> Browse Events --> Buy Ticket --> Attend --> Check In --> QR Connect
                                                                                     |
                                                                                     v
                                                                              ...silence...
                                                                         App sits unused until
                                                                        next event (weeks/months)
```

The gap between "QR Connect" and "next event" is where users are lost. There is currently **nothing** in the app that gives a user a reason to open it between events. The community feed is stub. There's no messaging. There are no notifications to pull users back.

### The Solution

Three pillars fill this gap: **Feed + Messaging + Notifications**.

```
Download --> Register --> Browse Events --> Buy Ticket --> Attend --> Check In --> QR Connect
                              ^                                                      |
                        Event reminder                                     DM new connection
                       (push notification)                                Browse feed daily
                              ^                                          Get perk notification
                       New event published                                       |
                              ^                                          Return for next event
                              +------------------------------------------------------+
```

### The Metric That Matters

> **MARKETING NUANCE — DAU/MAU Ratio:** Sponsors and partners care about one number above all others: **DAU/MAU ratio** (daily active users divided by monthly active users). An event-only app might have a DAU/MAU of ~0.03 (users open it once a month on event night). A working community feed + messaging could push that to 0.15-0.25. The difference between those two numbers is the difference between "we sponsor events" (one-time transactional) and "we have an ongoing relationship with your audience" (recurring partnership). The latter is worth dramatically more in sponsorship revenue.

### Feed Cold Start Strategy

Empty communities die. When the feed goes live, it needs seeding:

1. **Admin announcements** — The `announcement` post type exists. Use it for event recaps, upcoming event teasers, community milestones.
2. **Post-event prompts** — After check-in, push notification: "How was Industry Night? Share your experience."
3. **Collaboration seeding** — Admin posts sample collaboration requests to model the behavior ("Looking for a photographer for upcoming brand shoot — DM if interested").
4. **Connection prompt** — After making a connection, prompt: "Say hi to [Name] in the community feed" or "Post about tonight's event."

---

## 6. Sponsor/Vendor Value Proposition

### Current Sponsor Model

Sponsors are linked to events via `event_sponsors` junction table. Each sponsor has a tier (bronze/silver/gold/platinum) and can have discount codes. Vendors are a separate catalog linked to events via `event_vendors`.

The current monetization capability:
- Sponsor logos appear on event detail screens
- Discount codes are viewable by authenticated users (no verification gate yet)
- Admin can create/manage sponsors and link them to events

### Three Tiers of Sponsor Revenue

> **MARKETING NUANCE — Revenue Tiers:** There are roughly three tiers of sponsor revenue, and IN has the data model for all three. The jump from Tier 1 to Tier 2 is the highest-ROI investment.

#### Tier 1: Logo Placement (~$500-2K/event)
"Your logo on the event page and visible to all attendees."

**Status:** Works today. `event_sponsors` junction + sponsor display on event detail.

**Limitations:** Low value, transactional, no proof of impact. This is where most event sponsorships live and it's a commodity market.

#### Tier 2: Audience Access (~$2-5K/event)
"Your discount codes pushed to 200 verified hair professionals who attended your sponsored event."

**Requires:**
- Verification gating (#14) — so "verified professionals" means something
- Working perks screen — wired to real sponsor/discount data
- **Redemption tracking** — know whether discount codes were actually used

**This is the highest-leverage investment** because it moves sponsors from "we put our logo somewhere" to "we reached verified professionals in our target demographic."

#### Tier 3: Data Partnership (~$5-20K/quarter)
"Monthly audience intelligence report: growth trends, specialty demographics, engagement patterns, top influencers in your target market."

**Requires:**
- Analytics computation jobs — populate `analytics_influence`, `analytics_events`, `analytics_*_daily`
- Reporting layer — admin screens or generated reports showing aggregated data
- Sufficient user base for statistical significance

**This is recurring revenue** — sponsors pay quarterly for ongoing audience insights, not per-event.

### What You Can Offer Today (with reporting)

| Offering | Data Source | What Sponsor Gets | Missing Piece |
|----------|-----------|-------------------|---------------|
| Event sponsorship | `event_sponsors` | Logo on event, brand visibility | **Reporting:** "Your brand was seen by X attendees with Y specialty mix" |
| Discount distribution | `discounts` table | Codes visible to users | **Redemption tracking:** Did anyone actually use the code? |
| Audience demographics | `users.specialties` + `tickets` | "Here's who attended your sponsored event" | **Report builder:** aggregate + present this data |
| Post-event summary | `analytics_events` (not populated) | Attendance, connections, top specialties | **Computation job** to populate analytics tables |

### What You Could Offer (with build-out)

| Offering | Requires | Value to Sponsor |
|----------|----------|-----------------|
| **Targeted perks** | Verification gating (#14) + specialty filter | "Show this discount to verified hair stylists only" |
| **Sponsored posts** | Working community feed (#18) | Native content in the community feed |
| **Influencer identification** | `analytics_influence` computation job | "Here are the 10 most connected photographers in your market" |
| **Conversion tracking** | Discount redemption + event attribution | "42 of your 100 codes were redeemed by users from Event X" |
| **Market intelligence** | `analytics_*_daily` populated | "MUA registrations up 40% in NYC this quarter" |
| **Sponsor self-serve dashboard** | Admin reporting screens | Self-serve access to their sponsorship ROI data |

### Redemption Tracking — The Most Important Missing Piece

> **MARKETING NUANCE — Proving ROI:** Redemption tracking is the single most important missing piece for sponsor monetization. Today: sponsor gives discount codes --> IN shows them to users --> **nobody knows if anyone used them**. Even self-reported tracking ("Tap 'Redeemed' when you use this code") would let you tell sponsors: "42 users redeemed your 20% off code." That's **conversion data**. That's what turns a $500 logo placement into a $5,000 quarterly partnership. Sponsors don't pay for impressions — they pay for conversions.

Implementation options:
1. **Self-reported** (simplest): "Redeemed" button on discount card. User taps when they use the code. Tracks `user_id`, `discount_id`, `redeemed_at`.
2. **Code-based tracking**: Generate unique codes per user (instead of shared codes). Track which user-specific codes were used by the sponsor's POS system. Requires sponsor integration.
3. **QR-based redemption**: User shows QR code at sponsor's business. Sponsor scans it to confirm redemption. Most reliable, most complex.

Recommendation: Start with #1 (self-reported). It's imperfect but infinitely better than no data.

### The Marketing Consent Channel

> **MARKETING NUANCE — Managed Channel:** The `marketing_consent` flag on users is strategically important. Sponsors will ask "can we email your attendees?" The answer should always be: **"No, but we can surface your discounts to users who opted in to marketing."** This is a **managed channel** — IN controls the relationship between sponsor and user, which:
> - Protects user trust (sponsor doesn't get PII)
> - Lets IN charge for access (IN is the gatekeeper)
> - Prevents sponsor fatigue (IN controls frequency)
> - Maintains data sovereignty (sponsor never gets the list)
>
> Giving sponsors direct access to user contact info would be a mistake — it undermines the platform's role as intermediary and eliminates the recurring revenue opportunity.

---

## 7. Gotchas and Risks

### Product Risks

| Risk | Severity | Description | Mitigation |
|------|----------|-------------|------------|
| **Connection decay** | High | Users connect at events but never interact again. Connections go stale, app becomes irrelevant. | Messaging + post-event engagement prompts + "remember this person" notifications |
| **Feed cold start** | High | Empty community = no reason to post. No posts = empty community. Chicken-and-egg problem. | Seed with admin announcements. Post-event prompts. Collaboration request templates. |
| **Event dependency** | High | If events happen monthly, the app is only relevant ~2 days/month (anticipation + event day). | Feed + messaging create between-event value. Collaboration posts create ongoing professional utility. |
| **Platform substitution** | Medium | Users connect on IN, then move to Instagram DMs for ongoing communication. IN becomes a stepping stone, not a destination. | Messaging feature (connection-only DMs) keeps conversations in-app. Portfolio feature removes need to visit Instagram for work samples. |
| **Over-promising to sponsors** | Medium | "We have 500 users" but only 50 are active. Inflated metrics erode trust. | Focus on verified users and event attendance as honest metrics. DAU/MAU is the north star. |

### Technical Risks

| Risk | Severity | Description | Mitigation |
|------|----------|-------------|------------|
| **Polling scalability** | Low (now), Medium (later) | 4-second polling for connection detection. Works at 50 concurrent users; won't work at 5,000. | Acceptable for MVP. Plan WebSocket upgrade or server-sent events when user base grows. |
| **Analytics computation** | Medium | Analytics tables exist but no computation jobs. If populated lazily (on-demand), first sponsor report request will be slow. | Build scheduled jobs (daily cron) to populate analytics tables. Even if sponsor reports aren't built yet, start populating data now for historical trends. |
| **Posh dependency** | Low-Medium | Ticketing routes through Posh. If Posh changes their webhook format or goes down, ticket flow breaks. | Webhook payload is stored as `raw_payload` JSONB — always have the original data. Reconciliation by phone (#12, #13) adds resilience. |

### Legal/Privacy Risks

| Risk | Severity | Description | Mitigation |
|------|----------|-------------|------------|
| **"Selling user data" perception** | Medium | Aggregated audience insights are legally fine (GDPR/CCPA) but perceptually blurry. Users may feel uncomfortable. | Public messaging: "We share anonymized audience insights with sponsors to bring you better perks." Never: "We share your data." The `analytics_consent` flag + aggregated-only tables are the right technical foundation. |
| **Analytics consent opt-in rate** | Medium | If too few users opt in, aggregate data is statistically insignificant. | Default opt-in with clear explanation during onboarding (not dark pattern — genuine value exchange). Research local consent requirements per market. |
| **PII in API responses** | Low (tracked in #20) | Some endpoints may return more user data than necessary. Pre-MVP security review will audit. | Endpoint-level field filtering. Never return phone/email to non-admin callers unless user explicitly shares. |

---

## 8. Prioritized Recommendations

### Priority Matrix

Assessed on two axes: **user retention impact** (keeps users opening the app) and **sponsor revenue impact** (makes the platform monetizable).

| Priority | Item | Retention Impact | Sponsor Impact | Effort | Tracking |
|----------|------|-----------------|----------------|--------|----------|
| **P0** | Wire community feed | Very High | Medium | 3-4 sessions | #18 |
| **P0** | Push notifications | Very High | Medium | Medium | New issue needed |
| **P1** | Connection-only DMs | Very High | Low | Medium-Large | New issue needed |
| **P1** | Verification gating (backend) | Medium | High | Small | #14 |
| **P1** | Discount redemption tracking | Low | Very High | Small | New issue needed |
| **P2** | Analytics computation jobs | None | Very High | Medium | New issue needed |
| **P2** | Sponsor post-event report | None | Very High | Medium | New issue needed |
| **P2** | Profile portfolio images | High | Low | Medium | New issue needed |
| **P2** | Wire creative search UI | Medium | Low | Small | Adversarial review §8.6 |
| **P2** | Wire perks/sponsors UI | Low | High | Small | Deferred — needs product owner input |
| **P3** | People at This Event | Medium | Low | Small | New issue needed |
| **P3** | Mutual connections display | Medium | Low | Small | New issue needed |
| **P3** | Connection notes | Medium | Low | Small | New issue needed |
| **P3** | External sharing (profiles/events) | Medium (growth) | Low | Small | New issue needed |

### Recommended Sequencing

**Phase A: Make the app worth opening between events**
1. Wire community feed (#18) — the adversarial review has a detailed 6-chunk plan
2. Push notifications — FCM/APNs integration + key triggers
3. Verification gating (#14) — gates feed access, creates behavioral incentive

**Phase B: Build the professional utility layer**
4. Connection-only DMs — continue conversations after events
5. Profile portfolio — showcase work without leaving the app
6. Creative search UI — find collaborators by specialty

**Phase C: Build the sponsor revenue engine**
7. Discount redemption tracking — prove ROI to sponsors
8. Analytics computation jobs — populate influence scores, event stats, daily aggregates
9. Sponsor post-event reports — package the data for sponsor consumption
10. Wire perks/sponsors UI — real discount codes, real sponsor profiles

**Phase D: Network effects and growth**
11. Mutual connections display
12. People at This Event / Who's Going (#17)
13. External sharing
14. Structured collaboration board

### Dependencies

```
#14 (verification gating) ---> Community feed access gate
                           ---> Sponsor perks access gate

#18 (community feed)      ---> Sponsored posts
                           ---> Feed cold start seeding

Push notifications        ---> Event reminders
                           ---> Connection notifications
                           ---> Feed engagement triggers

Analytics computation     ---> Influence scores
                           ---> Event reports
                           ---> Market intelligence

Redemption tracking       ---> Sponsor ROI reports
                           ---> Tier 2 revenue unlock
```

---

## 9. Glossary of Marketing/Monetization Concepts

These concepts are referenced throughout the analysis. This glossary is for team members who may not have marketing/monetization experience.

| Term | Definition | How It Applies to IN |
|------|-----------|---------------------|
| **Audience Intelligence** | Detailed, structured knowledge about who your users are — demographics, behaviors, preferences, professional attributes. More valuable than raw user counts. | IN knows each user's creative specialty, which events they attend, who they connect with, and (with analytics jobs) their influence score. This is rich audience intelligence for beauty/creative industry sponsors. |
| **DAU/MAU Ratio** | Daily Active Users divided by Monthly Active Users. Measures how "sticky" an app is. A ratio of 0.5 means half your monthly users open the app daily. Facebook: ~0.65. Average social app: ~0.25. Event-only app: ~0.03. | IN's current DAU/MAU is probably near zero between events. The feed, messaging, and notifications are specifically designed to improve this metric, which directly correlates with sponsor willingness to pay for ongoing partnerships. |
| **Managed Channel** | A communication channel where the platform acts as intermediary between brands and users. The brand doesn't get direct access to user contact info — the platform controls the message delivery. | IN's `marketing_consent` flag + in-app perks display = managed channel. Sponsors can reach users through IN, but never get user emails/phones. This protects users AND creates recurring revenue (sponsors pay IN for access, not for a list). |
| **Conversion Data** | Evidence that a marketing action led to a desired outcome (purchase, redemption, signup). The holy grail of advertising — proving that the ad actually worked. | If IN tracks discount code redemptions, it can tell sponsors "42 people used your 20% off code." That's conversion data. Without tracking, IN can only say "we showed your code to 200 people" — which is an impression, not a conversion. |
| **Affinity Data** | Knowledge about which groups are naturally connected or interested in each other. "People who like X also like Y." | IN's cross-specialty connection data IS affinity data. "Photographers connect with MUAs at 3x the rate of other pairings" tells a MUA product brand exactly where to focus. |
| **Network Effects** | The phenomenon where a product becomes more valuable as more people use it. Each new user makes the platform more valuable for existing users. | Every new creative who joins IN makes the network more valuable for connection discovery, collaboration opportunities, and sponsor targeting. This is IN's moat — the connections and community data cannot be replicated by a new entrant. |
| **Cold Start Problem** | The challenge of launching a platform that requires content/users to be valuable, but can't attract content/users without being valuable first. | The community feed will have this problem on day one. Mitigation: seed with admin announcements, prompt post-event sharing, model collaboration post behavior. |
| **Two-Sided Marketplace** | A platform that serves two distinct user groups (e.g., riders and drivers for Uber). Value flows between both sides through the platform. | IN is a two-sided marketplace: creatives (who attend events, make connections, consume perks) and sponsors/vendors (who pay for access to creatives). The platform must deliver value to both sides. |
| **Verified Co-Presence** | IN-specific term: the implicit proof that two users were physically in the same place at the same time, evidenced by a QR-code connection at an event. | This is IN's unique data asset. No other social platform can prove that two professionals met in person. LinkedIn connections could be strangers. Instagram follows are one-directional. IN connections are mutual AND proximity-verified. |
| **Sponsor ROI** | Return on Investment for a sponsor — did their sponsorship dollars produce measurable value? The #1 question every sponsor asks. | Currently unanswerable because IN has no redemption tracking. With tracking: "Your $2,000 sponsorship of Event X resulted in 42 discount redemptions, reaching 150 verified professionals in hair/makeup specialties." |
| **Influence Score** | A computed metric indicating how connected/active a user is within the network. Used to identify key networkers, potential brand ambassadors, and community leaders. | The `analytics_influence` table already has schema for this: `connection_count`, `events_attended`, `network_reach`, `specialty_rank`, `city_rank`, `influence_score`. Just needs the computation job. |
| **Feature Gating** | Restricting access to certain features based on user status/tier. Creates behavioral incentives ("do X to unlock Y"). | IN's verification ladder gates community board and perks behind "attend an event + make a connection." This drives event attendance and QR usage, which generates the data that makes the platform valuable to sponsors. Circular reinforcement. |

---

## Appendix: Key Files Reference

For developers picking up social feature work, these are the critical files:

### Social App — Feature Screens
| File | Status | Purpose |
|------|--------|---------|
| `packages/social-app/lib/features/community/screens/community_feed_screen.dart` | Stub | Community feed (10 hardcoded posts) |
| `packages/social-app/lib/features/community/screens/create_post_screen.dart` | Stub | Post creation (Future.delayed fake) |
| `packages/social-app/lib/features/community/screens/post_detail_screen.dart` | Stub | Post detail (all static) |
| `packages/social-app/lib/features/community/widgets/post_card.dart` | Real | Post card widget (ready for real data) |
| `packages/social-app/lib/features/search/screens/search_screen.dart` | Stub | User search (hardcoded results) |
| `packages/social-app/lib/features/search/screens/user_profile_screen.dart` | Stub | Other user profile (hardcoded) |
| `packages/social-app/lib/features/perks/screens/perks_screen.dart` | Stub | Sponsor list (hardcoded) |
| `packages/social-app/lib/features/perks/screens/sponsor_detail_screen.dart` | Stub | Sponsor detail (hardcoded) |
| `packages/social-app/lib/features/networking/screens/connect_tab_screen.dart` | Real | QR display + connection detection |
| `packages/social-app/lib/features/networking/screens/qr_scanner_screen.dart` | Real | QR scanner + instant connection |
| `packages/social-app/lib/features/networking/screens/connections_list_screen.dart` | Real | Connections list |

### State Management
| File | Purpose |
|------|---------|
| `packages/social-app/lib/providers/app_state.dart` | Global state (auth, profile, active event) |
| `packages/social-app/lib/features/networking/providers/networking_state.dart` | Connection state (list, polling, creation) |
| (Needed) `CommunityState` | Feed state — follow `NetworkingState` pattern |

### Shared Package — Models
| File | Purpose |
|------|---------|
| `packages/shared/lib/models/post.dart` | Post + PostComment models (needs author shape fix) |
| `packages/shared/lib/models/connection.dart` | Connection model |
| `packages/shared/lib/models/user.dart` | User + SocialLinks models |
| `packages/shared/lib/models/sponsor.dart` | Sponsor model |
| `packages/shared/lib/models/discount.dart` | Discount model |

### Shared Package — API Clients
| File | Purpose |
|------|---------|
| `packages/shared/lib/api/posts_api.dart` | Posts API client (has unlikePost bug) |
| `packages/shared/lib/api/connections_api.dart` | Connections API client |
| `packages/shared/lib/api/users_api.dart` | Users API client |

### Backend — Route Handlers
| File | Purpose |
|------|---------|
| `packages/api/src/routes/posts.ts` | Posts CRUD + comments + likes (has SQL injection bug) |
| `packages/api/src/routes/connections.ts` | Connection creation + listing |
| `packages/api/src/routes/users.ts` | User search + profile |
| `packages/api/src/routes/sponsors.ts` | Sponsor listing (social-facing) |
| `packages/api/src/routes/discounts.ts` | Discount listing (social-facing) |

### Database — Analytics Tables
| Table | File | Purpose |
|-------|------|---------|
| `analytics_connections_daily` | `001_initial_schema.sql` | Daily connection aggregates by specialty pairing + city |
| `analytics_users_daily` | `001_initial_schema.sql` | Daily user aggregates by specialty + city |
| `analytics_events` | `001_initial_schema.sql` | Per-event performance metrics |
| `analytics_influence` | `001_initial_schema.sql` | User influence scores (requires computation job) |

---

## Related Documents

- `docs/analysis/adversarial_review.md` — Requirements vs. reality analysis, decisions, bug inventory, Posts implementation plan (§2.3)
- `docs/product/implementation_plan.md` — Phase-by-phase roadmap with current status
- `docs/product/requirements.md` — Original feature requirements
- `docs/product/industry_night_app_developer_context_handoff.md` — Full product requirements and MVP scope
- `docs/product/app_creative_direction.md` — UI/UX creative direction
- `CLAUDE.md` — Technical reference for all packages, APIs, and infrastructure
