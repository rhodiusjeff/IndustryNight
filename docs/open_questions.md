# Industry Night - Open Questions & Decisions Pending

**Purpose:** Track unresolved product decisions that need further discussion before implementation.

**Last Updated:** February 4, 2026

---

## High Priority (Blocks Implementation)

*No blocking questions at this time.*

---

## Medium Priority (Design Decisions)

### 2. Verified Users Connecting Outside Events
**Question:** What happens when two verified IN users meet outside an event (e.g., at a photoshoot, coffee shop)? Can they connect via the app?

**Current Rule:** Connections can ONLY be made at events (requires event code).

**Options:**
- A) Strict: No connections outside events. Period. (Preserves premium on attendance)
- B) Verified-to-verified exception: Two verified users can connect anytime (they've already proven attendance)
- C) "Open networking" events: Periodic windows where verified users can connect freely

**Considerations:**
- Option A is purist but may frustrate users who meet organically
- Option B rewards verified status with more flexibility
- Option C creates special moments but adds complexity

**Status:** TBD

---

### 3. Admin-Added User Testing Workflow
**Question:** How do admin-added testers get verified without a real event?

**Options:**
- A) Create "test events" with codes that work anytime
- B) Admin can directly set user status to `verified`
- C) `bypass_ticket_check` flag also bypasses verification entirely

**Status:** TBD

---

### 4. Phone Number Changes
**Question:** How does a user update their phone number (the login identifier)?

**Options:**
- A) Self-service in profile settings (verify new number via SMS)
- B) Admin-only change (user contacts support)
- C) Not supported in MVP

**Status:** TBD

---

### 8. A2P 10DLC Registration
**Question:** When to register for A2P 10DLC messaging compliance?

**Context:**
- Currently using Twilio Verify API for auth/OTP, which handles its own compliance — no 10DLC needed for auth flow
- A2P 10DLC is only required if we use the Messages API for non-auth SMS (event reminders, connection notifications, marketing)
- Industry Night does not currently have its own EIN, which is required for standard brand registration
- Rhodius Labs (ISV) could register as the brand using its own EIN as a stopgap
- Sole proprietor registration is also an option (lower throughput limits)

**Decision:** Defer until non-auth SMS messaging is needed or Industry Night obtains its own EIN. Twilio Verify covers the critical auth path without 10DLC.

**Status:** Deferred — revisit when adding non-auth SMS features

---

## Low Priority (Future Considerations)

### 5. Verification Expiration
**Question:** Does verified status ever expire? What if someone was verified 2 years ago but hasn't attended since?

**Options:**
- A) Verified is permanent (simplest)
- B) Requires re-verification after X months of inactivity
- C) Tiered badges (Verified, Regular, VIP based on attendance)

**Status:** TBD - likely Phase 2+

---

### 6. Multiple Tickets to Same Event
**Question:** What happens if a user buys multiple tickets to the same event?

**Options:**
- A) Allow it (they're buying for friends, only their record matters)
- B) Warn but allow
- C) Prevent duplicate purchases for same phone

**Status:** TBD

---

### 7. Banned User Reinstatement
**Question:** Can banned users ever be unbanned? What's the process?

**Status:** TBD

---

## Resolved Questions

*Move questions here once decided, with the decision noted.*

| Question | Decision | Date |
|----------|----------|------|
| Can unverified users post on Community Board? | No - verified only | 2026-02-04 |
| Can unverified users VIEW Community Board? | No - verified only (full exclusivity) | 2026-02-04 |
| Is RSVP separate from ticket purchase? | No - ticket purchase IS RSVP | 2026-02-04 |
| Can `checked_in` users use QR features? | Yes - fixes verification deadlock | 2026-02-04 |

---

## How to Use This Document

1. **Add new questions** as they arise during planning/development
2. **Discuss options** and add considerations
3. **Move to Resolved** once a decision is made
4. **Reference in requirements.md** if the decision changes the spec
