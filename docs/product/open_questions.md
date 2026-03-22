# Industry Night - Open Questions & Decisions Pending

**Purpose:** Track unresolved product decisions that need further discussion before implementation.

**Last Updated:** March 22, 2026

---

## High Priority (Blocks Implementation)

*No blocking questions at this time.*

---

## Medium Priority (Design Decisions)

### Q1. React Admin Migration Strategy
**Question:** What migration strategy to use for Flutter Web → React admin?

**Options:**
- A) Big-bang: Build React to parity, then cut over in one release
- B) Route-by-route: Move one domain at a time (events, customers, users, etc.)
- C) Dual-run: Both apps live temporarily; operators choose

**Considerations:** Option A is simpler conceptually but higher release risk. Option B lowers risk and enables continuous validation with operators. Option C adds operational complexity.

**Recommendation:** Option B (route-by-route).

**Status:** TBD (product owner preference for speed vs. safety)

---

### Q2. Influence Score Visibility
**Question:** Should the influence metric (PageRank-variant) be visible to social app users?

**Options:**
- A) Hidden — used only internally for search ranking and data products
- B) Partial — badge threshold ("Top 10% Influencer") without raw score
- C) Full — numeric score on profile

**Considerations:** C risks gamification/status anxiety dynamics. A is safe to start; can relax later.

**Recommendation:** Option A to start; revisit at Phase 7.

**Status:** TBD

---

### Q3. Professional Ratings Visibility
**Question:** Who can see professional ratings on user profiles?

**Options:**
- A) Public (visible to all, searchable)
- B) Verified-to-verified only
- C) Hidden (owner + employer only; used for data products only)

**Considerations:** A drives trust but may deter low-rated users. B/C preserve privacy.

**Status:** TBD

---

### Q5. Community Board Post Types & Jobs Separation
**Question:** Should jobs stay in the community feed, or have their own dedicated tab?

**Working assumption:** Separate Jobs tab. Community feed = `general`, `collaboration`, `announcement` post types only. Jobs tab is its own feature surface.

**Status:** Near-resolved — confirm before Phase 5 implementation

---

### Q6. Verified-to-Verified Connections Outside Events
**Question:** Can two verified IN users connect via the app when they meet outside an event (coffee shop, photoshoot)?

**Current Rule:** Connections require event code scan.

**Options:**
- A) Strict: No connections outside events (preserves premium on attendance)
- B) Verified exception: Two verified users can connect anytime (they've proven attendance)
- C) "Open networking" events: Periodic windows where verified users can connect freely

**Considerations:** A is purist but may frustrate organic meetings. B rewards verified status. C adds complexity.

**Status:** TBD

---

### Q7. Admin-Added User Testing Workflow
**Question:** How do admin-added testers get verified without attending a real event?

**Options:**
- A) Create "test events" with codes that work anytime
- B) Admin can directly set user status to `verified`
- C) `bypass_ticket_check` flag also bypasses verification entirely

**Status:** TBD — Option B is acceptable as a temporary dev workaround

---

### Q8. Phone Number Changes
**Question:** How does a user update their phone number (the login identifier)?

**Options:**
- A) Self-service in profile settings (verify new number via SMS)
- B) Admin-only change (user contacts support)
- C) Not supported in MVP

**Status:** TBD — Option C (not in MVP) is acceptable

---

## Low Priority (Future Considerations)

### Q-L1. Verification Expiration
**Question:** Does verified status ever expire? What if someone was verified 2 years ago but hasn't attended since?

**Options:**
- A) Verified is permanent (simplest)
- B) Requires re-verification after X months of inactivity
- C) Tiered badges (Verified, Regular, VIP based on attendance)

**Status:** TBD — likely Phase 2+

---

### Q-L2. Multiple Tickets to Same Event
**Question:** What happens if a user buys multiple tickets to the same event?

**Options:**
- A) Allow it (buying for friends; only their record matters)
- B) Warn but allow
- C) Prevent duplicate purchases for same phone

**Status:** TBD

---

### Q-L3. Banned User Reinstatement
**Question:** Can banned users ever be unbanned? What's the process?

**Status:** TBD

---

## Resolved Questions

*Decisions made, moved here for reference.*

| Question | Decision | Date |
|----------|----------|------|
| Can unverified users post on Community Board? | No — verified only | 2026-02-04 |
| Can unverified users VIEW Community Board? | No — verified only (full exclusivity) | 2026-02-04 |
| Is RSVP separate from ticket purchase? | No — ticket purchase IS RSVP | 2026-02-04 |
| Can `checked_in` users use QR features? | Yes — fixes verification deadlock | 2026-02-04 |
| Open registration vs. invite-only? | Open registration. Verification ladder is the feature gate | 2026-03-22 |
| Does Posh webhook auto-create users? | No. Orders stored; users register separately. Auto-link by phone | 2026-03-22 |
| Verification-based feature gating required? | Yes — backend `requireVerified` middleware | 2026-03-22 |
| What happens to venueStaff user role? | Removed from `user_role` enum. Venue check-in staff are `eventOps` admin users | 2026-03-22 |
| RBAC approach — ACL system or simpler? | Three separate account tables (users, admin_users, job_poster_accounts). Permissions in code (permissions.ts). No ACL system needed at current scale | 2026-03-22 |
| Job poster account type (flag vs. separate table)? | Separate `job_poster_accounts` table. Probationary lifecycle: pending → probationary → active → suspended | 2026-03-22 |
| Job poster ↔ Customer relationship? | Job poster optionally linked to customer via customer_id FK. Auto-provisioned when admin assigns job posting subscription product | 2026-03-22 |
| Image storage architecture? | First-class `image_assets` table. LLM-driven cleanup job. Archive vs. delete distinction. Community photos reusable per ToS | 2026-03-22 |
| Community post media — photos and/or video? | Photos yes (max 4 per post, S3 + sharp resize). Videos DEFERRED post-launch. Instagram is social backup for video | 2026-03-22 |
| Push notification mechanism? | FCM (Firebase Cloud Messaging) for iOS + Android. Flutter `firebase_messaging` package | 2026-03-22 |
| Wristband confirmation — need a push notification? | Yes. FCM push: "🎉 You're in. Welcome to Industry Night." Deep-links to Who's Here. Additive (non-blocking) | 2026-03-22 |
| Analytics compute engine — DuckDB vs. Spark? | DuckDB. Runs embedded in Node.js/Python cron. Reads from PostgreSQL, computes analytics, writes back. Spark is overkill | 2026-03-22 |
| Influence score — show on profiles? | No. Used in data products and search ranking only. Not displayed on user profiles | 2026-03-22 |
| Job post location — market area or real city? | Real city. Fields: location_display TEXT, location_city TEXT, location_state TEXT, location_country TEXT DEFAULT 'US', remote_ok BOOLEAN | 2026-03-22 |
| Video uploads — ship in MVP? | No. Deferred post-launch. Instagram is backup | 2026-03-22 |
| React admin local dev port? | Port 3630 | 2026-03-22 |
| ToS/Privacy — when to implement? | Phase 2, before App Store submission. Legal review required before go-live. Covers UGC image reuse, ratings standards, LLM data processing, data products | 2026-03-22 |
| Export My Data — prerequisite for Delete Account? | No. Delete Account ships Phase 0 (App Store compliance). Export My Data is Phase 9 (very late phase, post-MVP) | 2026-03-22 |
| Event check-in comparables comparison — when? | Post-MVP (early May 2026). Evaluate vs. Zkipster, Splash, Boomset, Eventbrite Organizer, DICE.fm, Posh | 2026-03-22 |
| A2P 10DLC SMS registration — when to register? | Deferred. Twilio Verify covers auth path. Revisit when non-auth SMS messaging is needed or IN obtains own EIN | 2026-03-22 |
| IN Chatbot — build now? | Parked. No clear use case yet. Revisit when real user need emerges | 2026-03-22 |

---

## How to Use This Document

1. **Add new questions** as they arise during planning/development
2. **Discuss options** and add considerations
3. **Move to Resolved** once a decision is made
4. **Reference in master_plan_v2.md** if the decision changes the architecture or plan
