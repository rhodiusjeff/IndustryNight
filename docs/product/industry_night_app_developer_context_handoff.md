# Industry Night App – Developer Context Handoff

## 1) Product Overview
**What it is:** A mobile app focused on discovering, promoting, and managing *Industry Night* events (e.g., hospitality, service, entertainment workers).

**Primary value:**
- For users: easily find verified industry nights, perks, and discounts.
- For venues: promote events, manage listings, and drive off‑peak traffic.

**Target users:**
- End users: industry workers (bartenders, servers, DJs, promoters, etc.).
- Admins/Venues: bars, clubs, restaurants, event hosts.

---

## 2) Core Use Cases (MVP)
**User flows:**
1. Browse/search industry nights by city, day, venue, or perk.
2. View event details (who qualifies, proof required, perks).
3. Save/bookmark events.
4. Optional: check‑in or show proof of industry status.

**Venue/Admin flows:**
1. Create/edit event listings.
2. Set rules (days, perks, eligibility).
3. Publish/unpublish events.

---

## 3) Key Features & Requirements

### 3.1 User-Facing Functional Requirements
- Account creation/login (email; social optional)
- Select primary city on first launch (auto-detect optional)
- Browse industry nights via list and map views
- Filter by:
  - Day (Tonight / This Week / Specific Day)
  - Venue type
  - Perks (drinks, food, cover-free, etc.)
- View detailed event pages including:
  - Venue info
  - Eligibility requirements
  - Proof required (if any)
  - Recurrence (weekly, monthly, one-off)
- Save/bookmark events
- Optional check-in flow to redeem perks
- Receive basic notifications (saved event reminders, updates)

### 3.2 Verification & Eligibility
- Verification is optional at MVP but supported
- Accepted proof types (configurable):
  - Paystub screenshot
  - POS system screenshot
  - Employer email
  - Manual admin approval
- Verification states:
  - Unverified
  - Pending review
  - Verified
  - Rejected
- Verification can be:
  - Global (applies to all venues)
  - Event-specific (venue-defined)

### 3.3 Check-In / Redemption Logic
- Events may require check-in to redeem perks
- Check-in methods:
  - In-app button
  - Venue-provided code
- Rules:
  - One check-in per user per event per day
  - Venues can choose honor-system vs enforced
- Check-in data visible to venue admins

### 3.4 Venue & Admin Functional Requirements
- Venue onboarding & profile creation
- Create, edit, duplicate, and delete events
- Event configuration options:
  - Days & times
  - Recurrence
  - Perks
  - Eligibility rules
  - Proof required
- Publish / unpublish events
- Pause events seasonally
- View basic analytics:
  - Views
  - Saves
  - Check-ins

### 3.5 Roles & Permissions
- **User:** browse, save, check-in, submit verification
- **Venue Staff:** check in attendees, view event check-ins
- **Platform Admin:** manage all venues/events, manage users, moderate content, view analytics

### 3.6 Audit Logging
- All significant actions logged for accountability and debugging
- Tracked actions include:
  - User actions: login, logout, profile updates
  - Content: create/update/delete for events, posts, connections
  - Moderation: verify, reject, ban, unban
  - Check-ins at events
- Audit log stores: action type, entity affected, actor, before/after values, timestamp, metadata (IP, user agent)
- Admin console provides:
  - Basic audit log search (by user, action type, date range)
  - Future: advanced analytics via AWS (Athena/QuickSight) - separate deep dive planned

### 3.7 Privacy & Consent
- Users control their data sharing preferences:
  - `analytics_consent`: Opt-in to anonymized network analytics
  - `marketing_consent`: Opt-in to sponsor/partner communications
  - `profile_visibility`: 'public', 'connections', or 'private'
- Data export/deletion requests tracked for compliance (GDPR/CCPA ready)
- Analytics tables store only aggregated, anonymized data
- Individual user data never shared without explicit consent

### 3.8 Network Analytics (Future Revenue Stream)
- Aggregated, anonymized network data valuable for:
  - Sponsors: Identify influential professionals by specialty/market
  - Brands: Understand cross-specialty networking patterns
  - Venues: Measure event effectiveness at driving connections
  - Industry research: Market size, growth, density by region
- Privacy-safe aggregations computed daily:
  - Connection patterns by specialty pairing
  - User activity by city/specialty
  - Event performance metrics
  - Network influence scores (opt-in users only)
- **Deep dive planned:** AWS analytics stack (Athena, QuickSight, data pipeline)

---

## 4) Platforms & Tech Preferences
- **Platform:** iOS first (Android/web later)
- **Frontend:** TBD (React Native / Swift / Flutter)
- **Backend:** TBD (Node/Firebase/etc.)
- **Database:** TBD
- **Auth:** Email + social (optional)

> *Open to developer recommendations here.*

---

## 5) Data Models (Initial)
**User**
- id, name, email, role (user/admin), city

**Venue**
- id, name, location, contact info

**Event**
- id, venueId, title, description
- day(s), time, perks
- eligibility rules
- status (draft/approved/live)

---

## 6) Design & UX Notes
- Dark-mode-first, nightlife-forward aesthetic
- Fast access to "Tonight" events
- Clear eligibility + proof messaging (no surprises at venue)
- Minimal steps from open → event found → details
- Emphasis on trust & legitimacy (verified badges, moderation)

---

## 7) Constraints & Assumptions
- Lean MVP prioritized over edge-case perfection
- Manual admin moderation acceptable initially
- iOS-first build with scalable backend
- Expect iteration after first city launch

---

## 8) Open Questions for Developer
- Recommended stack for fast MVP + future scale?
- Best low-friction verification flow?
- Build custom admin dashboard vs off-the-shelf?
- Suggested approach for recurring events?

---

## 9) Success Metrics (Early)
- # of active events per city
- Weekly active users
- Venue retention

---

## 10) Timeline (Rough)
- Discovery & architecture: 1–2 weeks
- MVP build: 6–8 weeks
- Beta launch: City #1

---

**Primary contact:** [Your name]
**Decision maker:** [Your name]

