# Industry Night - Product Requirements Document

**Version:** 1.8
**Date:** February 4, 2026
**Status:** Draft

---

## 1. Product Overview

**Industry Night** is a mobile app + web platform for **creative professionals** in NYC (hair stylists, makeup artists, photographers, videographers) to discover networking events and build community.

### Core Value Proposition
- **For Creatives:** Discover industry networking events, connect with peers, build professional relationships, find job opportunities
- **For Event Hosts:** Reach the right audience, manage recurring events, track attendance

### Target Users
- Hair stylists & barbers
- Makeup artists
- Photographers
- Videographers
- Stylists
- Models
- Nail technicians
- Lash technicians
- Other creative professionals

### Existing Brand Presence
- **Instagram:** [@industrynight__](https://www.instagram.com/industrynight__)
- Events already running in NYC with established audience
- **Ticketing:** Posh.vip (current platform for ticket sales)

---

## 2. Competitive Landscape

| Category | Examples | Gap |
|----------|----------|-----|
| Portfolio sites | Behance, NOVA, PurplePort | Showcase-focused, not event/community-focused |
| Booking platforms | StyleSeat, Glamsquad, Model Mayhem | Transactional, client-to-creative |
| Event platforms | Meetup, Eventbrite, Fever | Generic UX, no verification, one-off events |
| Local groups | IdleProjects (NYC) | Manual, not scalable, no app experience |

### Industry Night Differentiators
1. **Creative-focused community** - Built specifically for creative professionals
2. **Verification through attendance** - Badge earned by showing up (trust signal)
3. **Recurring event focus** - Built for weekly/monthly Industry Nights
4. **QR networking** - Easy in-person connections at events
5. **NYC-first depth** - Understanding of local creative scenes

---

## 3. User Roles & Permissions

### 3.1 Creative (All Users)

**All Users (Unverified + Verified):**
- Browse events
- View Community Board *(TBD: may restrict to verified only)*
- Search and view other creative profiles
- Purchase tickets (Phase 2)

**Verified Users Only (must attend IN event):**
- Post on Community Board
- Personal QR code for networking
- Scan other creatives to connect (at events only)
- Access sponsor discount codes

### 3.2 Admin (Platform Admin)
**Capabilities:**
- Post announcements (highlighted on Community Board)
- Moderate content (remove posts, ban users)
- Scan tickets at events (grants verified badge)
- Manage events (Phase 2)

**Interfaces:**
- **Mobile app:** Basic admin features (post announcements, scan tickets)
- **Web dashboard:** Full admin panel (analytics, moderation, event management)

---

## 4. Core Features

### 4.1 App Access Control (IMPORTANT)

**The app is invite-only / ticket-only. No open signup.**

Users can ONLY log in if pre-registered via:
1. **They buy a Posh ticket** → webhook creates their record (normal flow), OR
2. **Admin manually adds them** in backend admin console (special cases)

**Admin-Added Users:**
- Used for testers and special-case users
- Can have `bypass_ticket_check` flag to skip ticket validation for activation codes
- Still need to attend event and enter activation code to verify (unless testing)
- Use sparingly - keeps community authentic

**Login Flow:**
```
User enters phone number
    ↓
Is phone in system?
    ├── NO → "To access Industry Night, purchase a ticket at posh.vip"
    └── YES → Send SMS code → Login success
```

**Rationale:**
- Keeps community exclusive to genuine attendees
- Creates value proposition for buying tickets
- Prevents spam/fake accounts

---

### 4.2 User Onboarding & Profiles

**Pre-Registration (before app access):**
- User buys ticket on Posh.vip
- Posh webhook → IN backend creates user record
- IN sends welcome email with app download link

**Login Flow (phone must be in system):**
1. User enters phone number
2. System checks if phone exists in database
3. If yes → User receives SMS verification code
4. User enters code to verify
5. User creates profile (name, bio, specialty, social links)
6. User has LIMITED access until verified

**Profile Fields:**
- Name
- Bio
- Specialty (multi-select from predefined list)
- Social links: Instagram, Website, LinkedIn, TikTok
- Profile photo
- Verified badge (earned, not editable)

**Creative Specialties:**
- Hair
- Makeup
- Photography
- Videography
- Styling
- Modeling
- Nails
- Lashes
- (expandable based on demand)

---

### 4.3 Verification System

**Model:** Verification **unlocks key features**, creating incentive to attend IN events AND actively network.

**Three Steps to Get Verified:**
1. **Get ticket** - Purchase ticket on Posh.vip (creates pre-registration)
2. **Show up** - Enter 4-digit activation code given at door
3. **Make first connection** - Scan another creative's QR or get scanned

**Verification Flow:**
```
Buy Ticket on Posh → Webhook creates record → User downloads app
        ↓
User logs in (limited access) → Sets up profile
        ↓
User attends event → Doorperson gives 4-digit activation code
        ↓
User enters code in app → Status = "checked_in"
        ↓
User scans first QR connection → Status = "verified"
```

**Activation Code System:**
- Each event has a unique 4-digit activation code
- Same code for all attendees at that event
- Code changes per event
- Code valid only during event time window
- **Security:** Must have ticket record + valid code to activate

**Feature Access by Status:**

| Feature | Registered | Checked-In (at event) | Verified |
|---------|------------|----------------------|----------|
| Log in to app | Yes | Yes | Yes |
| Browse events | Yes | Yes | Yes |
| View Community Board | No | No | Yes |
| Setup profile | Yes | Yes | Yes |
| Search creatives | Yes | Yes | Yes |
| View profiles | Yes | Yes | Yes |
| Post on Community Board | No | No | Yes |
| **Connect via QR scan** | **No** | **Yes** | **Yes (at event)** |
| **Sponsor discount codes** | **No** | **No** | **Yes** |
| **Who's Going (event)** | **No** | **Yes** | **Yes (at event)** |
| **Who's Here (event)** | **No** | **Yes** | **Yes (at event)** |

**Key Insight:** `checked_in` users (not yet verified) CAN use QR features. This allows two first-time attendees to scan each other and both become verified.

**Two Types of Unlocks:**
1. **Verified Status (one-time):** First event attendance + first connection → unlocks posting, discounts
2. **Event Check-In (per-event):** Enter event code → unlocks Who's Going/Here and QR networking for THAT event

**Rationale:**
- Ticket purchase required to access app (exclusive)
- Activation code proves physical attendance
- First connection proves active networking
- Builds genuine community of active participants

**Verification States:**
- `registered` - Has ticket, hasn't attended yet
- `checked_in` - Entered activation code at event
- `verified` - Made first connection, full permanent access

---

### 4.4 QR Networking

**Requires:**
- `checked_in` OR `verified` status, AND
- Currently checked in at an event (must have entered event code for THIS event)

**IMPORTANT: Connections can ONLY be made at events.** This puts a critical premium on attending Industry Night events and connecting with as many creatives as possible while there. QR networking is disabled outside of events.

**Verification Deadlock Solution:** Users who are `checked_in` (but not yet `verified`) CAN use QR features. This allows two first-time attendees to scan each other - both then become `verified` simultaneously.

**Personal QR Code:**
- Each user has a unique QR code linked to their profile
- QR code only active when user is checked in at an event
- Outside events: "Check in at an IN event to network"
- `registered` users (never attended) see: "Attend an IN event to unlock networking"

**QR Scanner:**
- Scan another creative's QR code to connect
- Connection is mutual (both users see each other in connections)
- Scanner only active when user is checked in at an event
- Both users must be checked in to the same event to connect

**My Connections:**
- List of all users you've connected with
- Shows: name, photo, specialty, verified status, event where you met
- Tap to view full profile
- Visible to all `checked_in` and `verified` users (connections list persists after event)

---

### 4.5 Event Social Features

#### Ticket Purchase = RSVP

**There is no separate RSVP feature.** Buying a ticket on Posh.vip IS the functional equivalent of RSVP. This simplifies the model:
- User buys ticket on Posh → They're "going" to the event
- Posh webhook creates their ticket record in IN system
- No additional in-app RSVP needed

#### Event Code Unlocks Per-Event Visibility

**Important:** Even verified users must enter the **event code at each event** to unlock social features for that specific event.

**Event Check-In (Requires Event Code):**
- User arrives at event, receives 4-digit event code at door
- User enters code in app → unlocks event-specific features
- **This is required at EVERY event, not just the first one**

**Visibility Rules:**
| Feature | Requires | What You See |
|---------|----------|--------------|
| **Who's Going** | Event code for THIS event | Connections with tickets for this event |
| **Who's Here** | Event code for THIS event | Connections checked in to this event |
| **QR Networking** | Event code for THIS event | Can scan/be scanned at this event |

**Flow for Verified User at Each Event:**
```
Verified User → Arrives at Event → Doorperson gives event code
    → User enters code in app
    → Unlocks "Who's Going" for THIS event
    → Unlocks "Who's Here" for THIS event
    → Unlocks QR networking for THIS event
```

**Rationale:**
- Prevents lurking (seeing who's at events without attending)
- Each event is a fresh social experience
- Encourages physical attendance to unlock social features
- Connections can ONLY be made at events (premium on showing up)

---

### 4.6 Creative Search

**Search & Filter:**
- Search by name
- Filter by specialty
- Filter by verified status (optional)

**Search Results:**
- Show: name, photo, specialty, verified badge
- Tap to view full profile

**Profile View:**
- Full profile information
- Social links (tap to open in external app)
- Option to scan their QR / add to connections

---

### 4.7 Community Board

**Access:** Verified users only (both viewing and posting)

**Post Types:**
- General posts
- Event feedback
- Job postings
- Advice/support requests

**Admin Announcements:**
- Special highlighted posts
- Used for: IN event dates, community events, sponsor deals

**Post Features:**
- Text content
- Images (optional)
- Timestamp
- Author info (name, photo, specialty, verified badge)

**Moderation:**
- Admin can remove inappropriate posts
- Admin can ban users

---

### 4.8 Sponsors & Vendors

#### Sponsor Tiers

| Tier | Description | Visibility |
|------|-------------|------------|
| **Title Sponsor** | Main presenting sponsor | "IN app powered by [Name + Logo]" - persistent throughout app |
| **App Sponsor** | App-specific sponsor | Featured placement in app header/footer |
| **Event Sponsors** | Per-event sponsors | Own profile page in app, listed on event page |

#### Sponsor Pages
- Each event sponsor has a dedicated page in the app
- Page includes: name, logo, description, website link, social links
- Can include discount codes for verified users

#### Vendors (Separate from Sponsors)
- Vendors are present at events but are NOT sponsors
- Own section in the app: "Vendors" (separate heading from Sponsors)
- Vendor listing: name, logo, description, what they offer
- Can be associated with specific events

#### Sponsor Discounts (Verified Users Only)

**Requires:** Verified status

**How It Works:**
- Sponsors provide discount codes for IN community
- Only verified users can view/access codes
- Displayed in dedicated "Perks" or "Discounts" section

**Discount Display:**
- Sponsor name/logo
- Discount description (e.g., "20% off at XYZ Supply")
- Code or link to redeem
- Expiration date (if applicable)

#### Admin Sponsor Management
- Add/edit/remove sponsors (by tier)
- Upload sponsor logos and info
- Assign sponsors to events
- Manage sponsor discount codes
- Add/edit/remove vendors
- Assign vendors to events

---

### 4.9 Event Ticketing (Phase 2)

**Event Listings:**
- Browse upcoming Industry Night events
- Event details: venue, date, time, price, description

**Ticket Purchase:**
- In-app purchase via Stripe
- Platform controls all pricing centrally

**Mobile Ticket:**
- QR code ticket for venue entry
- Staff scans to admit and check-in user

---

## 5. Posh.vip Integration

### Why Posh Stays
- Posh provides **event discovery** - people find IN events there
- Staff already trained on Posh scanning at door
- No need to rebuild ticketing infrastructure

### Integration Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. DISCOVERY & PURCHASE (Posh)                                  │
├─────────────────────────────────────────────────────────────────┤
│ • User finds event on Posh.vip                                  │
│ • User buys ticket                                              │
│ • Posh webhook → IN backend notified                           │
│ • IN creates user record (phone, email from webhook)           │
│ • IN sends thank-you email + link to download app              │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 2. PRE-EVENT (Limited Access)                                   │
├─────────────────────────────────────────────────────────────────┤
│ • User downloads IN app                                         │
│ • User logs in via SMS (phone must be in system)               │
│ • LIMITED functions available:                                  │
│   ✓ View upcoming events                                        │
│   ✓ Setup profile (name, bio, specialty, socials)              │
│   ✗ QR networking (locked)                                     │
│   ✗ Sponsor discounts (locked)                                 │
│ • Message: "Get your activation code at the event"             │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 3. AT THE EVENT                                                 │
├─────────────────────────────────────────────────────────────────┤
│ • User arrives at venue                                         │
│ • Doorperson scans Posh ticket (unchanged Posh flow)           │
│ • Doorperson gives user 4-digit ACTIVATION CODE                │
│   - Same code for all attendees at that event                  │
│   - Code changes per event                                      │
│   - Code valid event night only                                │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 4. ACTIVATION (Full Access)                                     │
├─────────────────────────────────────────────────────────────────┤
│ • User enters activation code in IN app                         │
│ • App validates:                                                │
│   - User has ticket record (from webhook)                      │
│   - Code matches current event                                  │
│   - Code is within valid time window                           │
│ • User status → "checked_in"                                   │
│ • User makes first QR connection → "verified"                  │
│ • All features unlocked (QR networking, discounts)             │
└─────────────────────────────────────────────────────────────────┘
```

### Posh Webhook Data
- Triggered on: "Order Created" (ticket purchased)
- Data needed: buyer email, buyer phone, event ID, order ID
- Action: Create user record + ticket record in IN database

### Admin Event Management
- Admin creates event in IN backend (separate from Posh for now)
- Admin sets 4-digit activation code for that event
- Admin sets valid time window (event date/hours)
- Future: Explore Posh API for automatic event sync

---

## 6. Business Rules

### Access Control
- App is invite-only (no open signup)
- Must have Posh ticket or admin-added to log in

### Pricing
- Platform (admin) sets all ticket prices centrally
- Venues do not control pricing

### Messaging
- No in-app messaging/chat
- Users connect via external social platforms (Instagram DMs, etc.)

### Jobs
- Users can post jobs on Community Board
- No formal job application system
- Contact via external social links

---

## 7. Technical Architecture

### 7.1 Platforms
- **Mobile:** iOS + Android (Flutter - single codebase)
- **Web:** Admin dashboard (Flutter web or separate)

### 7.2 Backend
| Component | Technology |
|-----------|------------|
| API | Node.js (containerized) |
| Orchestration | AWS EKS (Kubernetes) |
| Database | AWS (RDS PostgreSQL, DynamoDB, or Aurora - TBD) |
| Authentication | JWT tokens |
| SMS | AWS SNS or Twilio |
| Payments | Stripe (Phase 2) |

### 7.3 Notes
- EKS chosen for scalability and learning purposes
- Immediate scaling not required but architecture supports it

---

## 8. Data Model

### User
```
- id: UUID
- phone: string (unique - used for login)
- email: string (from Posh webhook or admin entry)
- name: string
- bio: string
- role: enum (creative, admin)
- source: enum (posh_webhook, admin_added)
- bypass_ticket_check: boolean (for admin-added testers/special users)
- specialty: string[] (array of specialties)
- social_links: {
    instagram: string
    website: string
    linkedin: string
    tiktok: string
  }
- verification_status: enum (registered, checked_in, verified)
- profile_completed: boolean
- qr_code_data: string
- profile_photo_url: string (optional)
- banned: boolean
- created_at: timestamp
- updated_at: timestamp
```

**Note on `bypass_ticket_check`:** Admin-added users with this flag can enter activation codes without having a Posh ticket record. Used for testers and special-case users who need app access outside the normal ticket-first flow.

### Connection
```
- id: UUID
- user_a_id: UUID (foreign key)
- user_b_id: UUID (foreign key)
- connected_at: timestamp
- event_id: UUID (foreign key - required, connections only made at events)
```

### Post
```
- id: UUID
- author_id: UUID (foreign key)
- content: string
- image_url: string (optional)
- is_announcement: boolean
- post_type: enum (general, feedback, job, advice)
- created_at: timestamp
- updated_at: timestamp
```

### Sponsor
```
- id: UUID
- name: string
- logo_url: string
- description: string
- website_url: string (optional)
- social_links: {
    instagram: string
    website: string
    linkedin: string
  }
- tier: enum (title, app, event)
- is_active: boolean
- created_at: timestamp
```

### EventSponsor (join table)
```
- id: UUID
- event_id: UUID (foreign key)
- sponsor_id: UUID (foreign key)
```

### Vendor
```
- id: UUID
- name: string
- logo_url: string (optional)
- description: string
- website_url: string (optional)
- is_active: boolean
- created_at: timestamp
```

### EventVendor (join table)
```
- id: UUID
- event_id: UUID (foreign key)
- vendor_id: UUID (foreign key)
```

### Discount (Sponsor Perks)
```
- id: UUID
- sponsor_id: UUID (foreign key)
- description: string
- code: string (optional - if code-based)
- redemption_url: string (optional - if link-based)
- starts_at: timestamp (optional)
- expires_at: timestamp (optional)
- is_active: boolean
- created_at: timestamp
```

### Event
```
- id: UUID
- title: string
- description: string
- venue_name: string
- venue_address: string
- event_date: date
- start_time: time
- end_time: time
- activation_code: string (4-digit code for this event)
- code_valid_start: timestamp
- code_valid_end: timestamp
- posh_event_id: string (optional - for future sync)
- status: enum (draft, published, completed)
- created_at: timestamp
- updated_at: timestamp
```

### Ticket (from Posh webhook)
```
- id: UUID
- user_id: UUID (foreign key)
- event_id: UUID (foreign key)
- posh_order_id: string (from webhook)
- purchased_at: timestamp
- activated_at: timestamp (when code entered)
```

### EventCheckIn (Per-Event Check-in)
```
- id: UUID
- user_id: UUID (foreign key)
- event_id: UUID (foreign key)
- checked_in_at: timestamp (when user entered event code)
```

**Note:** RSVP is handled by Ticket record (buying a ticket = RSVP). EventCheckIn tracks who has entered the event code at each event, enabling Who's Going/Who's Here visibility and QR networking.

### Venue (Phase 2)
```
- id: UUID
- name: string
- address: string
- city: string
- created_at: timestamp
```

---

## 9. MVP Scope (Phase 1)

**Core Focus:** Posh Integration + QR Networking + Community

### Included in MVP

**Posh Integration:**
1. Webhook receiver for Posh "order created" events
2. User pre-registration from webhook data
3. Welcome email with app download link

**Access Control:**
4. Invite-only login (phone must be in system)
5. Phone-based SMS authentication (passwordless)
6. Admin can manually add users

**User Onboarding:**
7. Profile creation (name, bio, specialty, social links)
8. Limited access mode for unverified users

**Event & Activation:**
9. Event management (admin creates events with activation codes)
10. Activation code entry screen
11. Code validation (ticket + code + time window)

**Networking (Verified Users):**
12. Personal QR code for networking
13. QR scanner to connect with others
14. My Connections list
15. First connection triggers verified status

**Event Social (Verified Users + Event Code):**
16. Event code entry at each event (required for social features)
17. "Who's Going" - see connections with tickets for this event
18. "Who's Here" - see connections checked in to this event
19. QR networking enabled only while checked in at event

**Discovery & Community:**
20. Upcoming events list
21. Creative search by specialty
22. Profile viewing with social link outs
23. Community Board (verified users only - view and post)
24. Admin announcements
25. Sponsor discount codes (verified users only)

**Admin Tools:**
26. Add users manually
27. Create/manage events with activation codes
28. Post announcements
29. Moderate content
30. Manage sponsors (by tier: title, app, event)
31. Manage vendors
32. Assign sponsors/vendors to events
33. Manage sponsor discount codes

### Deferred to Phase 2
- In-app event ticketing + purchase (replace Posh)
- Push notifications
- Analytics dashboard
- Posh API sync for automatic event creation

---

## 10. Success Metrics

### Phase 1 (MVP)
- Number of registered users
- Number of connections made (QR scans)
- Community board engagement (posts, views)
- Verified users (event attendance)

### Phase 2
- Ticket sales volume
- Event attendance rate
- User retention (weekly active users)
- Revenue per event

---

## 11. Open Items & Future Considerations

**See also:** [Open Questions](open_questions.md) for unresolved product decisions requiring discussion.

### Technical Open Items
- [ ] Finalize database choice (RDS vs DynamoDB vs Aurora)
- [ ] Define app navigation structure
- [ ] Design wireframes/mockups
- [ ] Determine push notification strategy
- [ ] Define sponsor integration for verified perks

### Product Open Items (see open_questions.md)
- [ ] Verified users connecting outside events
- [ ] Admin-added user testing workflow
- [ ] Phone number change process

### Future Considerations
- [ ] Consider expansion beyond NYC
- [ ] Verification expiration / tiered badges
- [ ] Analytics dashboard

---

## Appendix A: User Flows

### A.1 Ticket Purchase (Posh)
```
User finds event on Posh.vip → Buys ticket → Posh webhook → IN creates user record
    → IN sends welcome email with app link
```

### A.2 New User Login (Invite-Only)
```
Splash → Phone Entry → Is phone in system?
    ├── NO → "Purchase ticket at posh.vip" message
    └── YES → SMS Code → Profile Setup → Home (limited access)
```

### A.3 Event Activation
```
User at event → Doorperson scans Posh ticket → Doorperson gives 4-digit code
    → User enters code in app → Status = "checked_in" → QR features unlocked
```

### A.4 First Connection (Becomes Verified)
```
Checked-in User → Scan Another Creative → First Connection Made
    → Status = "verified" → Sponsor discounts unlocked
```

### A.5 QR Networking (At Events Only)
```
User checked in at event → My QR Code → (Other checked-in user scans) → Connection Created
  OR
User checked in at event → QR Scanner → Scan Other Checked-In User → Connection Created
```
**Note:** Both `checked_in` and `verified` users can network, but only while checked in at an event.

### A.6 Registered User Tries to Connect (Not at Event)
```
Home → QR Code/Scanner → "Enter activation code at event to unlock" → View Events
```

### A.7 Finding a Creative
```
Home → Search → Filter by Specialty → View Profile → Tap Social Link
```

### A.8 Check-In at Event (Requires Event Code Each Time)
```
Verified User at Event → Receives event code at door
    → Events → Select Event → Enter Event Code
    → Unlocks "Who's Going" for THIS event (connections with tickets)
    → Unlocks "Who's Here" for THIS event (connections checked in)
    → Unlocks QR networking for THIS event
```

### A.9 Verified User Without Event Code
```
Verified User → Views Event → Sees "Enter event code to see who's attending"
    → Cannot see Who's Going or Who's Here until code entered
    → Cannot use QR networking until code entered
```

### A.10 Making a Connection (At Event Only)
```
Verified User (checked in) → My QR Code → Other user scans
    → Connection created (mutual)
    → Both users see each other in "My Connections"
    → Connection shows which event you met at
```

---

## Appendix B: Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-02-04 | - | Initial requirements document |
| 1.1 | 2026-02-04 | - | Clarified verification gates features (QR networking, sponsor discounts). Added sponsor discounts feature. |
| 1.2 | 2026-02-04 | - | Added "make first connection" as third step to verification. Added checked_in intermediate state. |
| 1.3 | 2026-02-04 | - | Major update: Added Posh.vip integration, invite-only access control, activation code system. Updated data models, user flows, and MVP scope. |
| 1.4 | 2026-02-04 | - | Added Event Social Features: RSVP, "Who's Going", simplified check-in for verified users, "Who's Here". Added EventAttendance data model. |
| 1.5 | 2026-02-04 | - | Added Sponsors & Vendors: sponsor tiers (title, app, event), sponsor pages, vendor listings, admin sponsor management. Added Sponsor, Vendor, EventSponsor, EventVendor data models. |
| 1.6 | 2026-02-04 | - | Clarified per-event check-in: event code required at EACH event to unlock "Who's Going" and "Who's Here" for that specific event. Verified status unlocks QR networking (one-time), event check-in unlocks social features (per-event). |
| 1.7 | 2026-02-04 | - | **Contradiction resolution:** (1) Community Board posting is verified-only; viewing TBD. (2) RSVP removed - ticket purchase IS RSVP. (3) QR networking only works at events with event code. (4) `checked_in` users CAN use QR features (fixes verification deadlock). (5) Added `bypass_ticket_check` flag for admin-added users. Renamed EventAttendance to EventCheckIn. |
| 1.8 | 2026-02-04 | - | Community Board visibility resolved: verified users only (both viewing and posting). |
