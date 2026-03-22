# Trajectory Review: Requirements Audit → Maturity Assessment
## Industry Night Platform — Adversarial Review Comparison

**Original review:** March 1, 2026 — *"Adversarial Review: Requirements vs. Reality"*
**Subsequent review:** March 2026 — *"AI-Assisted Development Maturity Review"*
**Interval:** ~2–3 weeks of active development

---

## What Each Review Was Actually Asking

This is the most important thing to understand before comparing findings: **these two reviews are not measuring the same thing.**

| | Review 1 (March 1) | Review 2 (March 2026) |
|---|---|---|
| **Question** | Are you building the right thing? | Are you building it right? |
| **Lens** | Requirements fidelity | SDLC maturity |
| **Evidence** | Code vs. spec, line-by-line | Architecture, patterns, team-readiness |
| **Audience** | Product owner / requirements authors | CTO / technical advisor |
| **Tone** | Investigative | Advisory |

The shift in question between reviews is itself a signal of progress. You can only ask "is this production-hardened?" after you've established "is this the right product?" Review 1 was doing the former. Review 2 could do the latter. **That transition is meaningful.**

---

## What Changed Between Reviews (Evidence of Progress)

### 1. The Biggest Structural Decision: Unified Customer Model

**Review 1** found sponsors and vendors as separate, half-implemented entities. Items 30–33 in the MVP scorecard were all "Partial — deferred pending product owner requirements." Edit/delete for sponsors and vendors were missing. The discount system was entirely absent.

**Review 2** treats the unified customer model as a *strength* — a conscious architecture decision showing product thinking ahead of engineering. The `customers` + `products` + `customer_products` + `discounts` tables are described as fully built, with 74 of 118 API tests covering customer/product/discount flows.

**Trajectory:** A half-built, ambiguous sponsor/vendor model became a coherent commercial CRM in the interval. This is a major structural evolution — not an incremental fix, but an architectural consolidation that resolved multiple open questions from Review 1 simultaneously.

---

### 2. Open Registration + Verification Ladder: Decided and Implemented

**Review 1** identified open registration as "Gap 1.1 — Critical." The entire invite-only model from the requirements was unimplemented. The review session itself produced the decision: open registration adopted, verification ladder becomes the feature gate.

**Review 2** doesn't mention this at all — because it's no longer a gap. Open registration is the documented, accepted model. The `verification_status` field exists, first connection auto-verifies, and the only remaining gap is server-side verification *gating* (which Review 1 tracked as #14 and Review 2 confirms is still pending).

**Trajectory:** A P0 requirement conflict was identified, decided, and implemented. One of the three "Big Three" structural gaps from Review 1 is closed.

---

### 3. Posh Webhook + User Reconciliation: Decided, Partially Implemented

**Review 1** found Posh webhook data and user data in separate silos with no reconciliation. A 3-trigger reconciliation strategy was decided: on registration, on check-in attempt, and at webhook time (tracked as #12 and #13).

**Review 2** still calls the Posh webhook the "#1 production risk" — but the risk has shifted. It's no longer about user/order reconciliation (that appears resolved); it's about **the webhook handler being completely untested**. The silent failure mode (HTTP 200 on compat errors) is the concern now.

**Trajectory:** The data model problem was solved. The testing problem was not. The risk is still real but has matured from "architectural gap" to "test coverage gap." Progress, but not resolved.

---

### 4. SQL Injection in posts.ts: Probably Fixed

**Review 1** called out SQL injection in `posts.ts` (lines 40, 63 — `userId` interpolated into SQL) as bug B1 and a security prerequisite.

**Review 2** explicitly states: "Parameterized SQL everywhere — zero string concatenation in queries (verified)." This is a deliberate verification, not an assumption.

**Trajectory:** Active security vulnerability confirmed fixed.

---

### 5. Token Refresh 500 → 401: Probably Fixed

**Review 1** called out "Fix token refresh 500 → 401" as an active user-facing bug causing users to be logged out after 15 minutes.

**Review 2** doesn't mention this bug at all. Its JWT concern is different — *no token revocation* (logout doesn't invalidate tokens). These are different problems, and the absence of the old one suggests it was fixed.

**Trajectory:** Active auth bug resolved. A more sophisticated auth concern (token revocation) has taken its place — which is the normal maturation arc for auth systems.

---

### 6. Image Management: Fully Matured

**Review 1** mentions multi-image upload with hero system as a "good addition beyond requirements" — already built.

**Review 2** discusses image management as a completed, working system with admin UI, S3 integration, hero selection, sort-order management, and a global image catalog. The `EventDetailScreen` concern in Review 2 is not about whether it works — it's about the 1,254-line file size being a maintenance burden.

**Trajectory:** Image management went from "built" to "production-capable but structurally unwieldy."

---

## What Didn't Change (Persistent Gaps)

### 1. CI/CD: Still Theater

Both reviews call this out. Review 1 didn't highlight it explicitly (it wasn't the frame of that review), but the absence of automated validation was always there. Review 2 names it clearly: "branch protection is theater without validation behind it."

This is the most persistent gap. It appears in both reviews, it appears in the technical debt roadmap, and it will appear in a third review if a third review is written. **It keeps surviving because it doesn't break anything visible — until it does.**

### 2. Community Feed / Social Screens: Still Substantially Stub

**Review 1** called community feed (Phase 1E), creative search (Phase 1F), and perks as stubs — and devoted an entire section (§2.3) to an implementation plan for wiring them up.

**Review 2** notes the social app has "~10 TODO markers for unimplemented features (community feed hardcoded to `itemCount: 10`, create post not wired to API, no photo picker)."

The section §2.3 implementation plan from Review 1 (5 detailed chunks, state management pattern, optimistic updates, pagination) appears to have gone unimplemented in the interval. The backend exists. The client-side remains stub.

**Trajectory:** No movement. This is the most surprising finding of the trajectory comparison. A detailed implementation plan was written in Review 1. It was not executed. The admin app advanced significantly in the same period; the social app did not.

**Hypothesis:** Development effort in the interval went toward the commercial model (unified customers, products, discounts) — the revenue side. The social feed — the community side — was deprioritized. This is a defensible product decision but should be made explicit, not left as an artifact of where attention went.

### 3. Flutter Test Suite: Still Zero

Both reviews note the Flutter apps have no meaningful tests. Review 1 was primarily focused on API/requirements fidelity and didn't dwell on this. Review 2 calls it out explicitly. No movement.

### 4. Verification-Based Feature Gating: Still Pending

Review 1 decided (§1.2) that backend `requireVerified` middleware is required, tracked as #14. Review 2 confirms it still hasn't been implemented: "verification_status is read and written but never gates access to anything."

**Trajectory:** Decision made in Review 1, still not implemented in Review 2. This is now 3+ weeks old as a tracked gap.

---

## The Maturity Arc: What the Trajectory Tells You

### Phase 1 → Phase 2 Transition (Review 1 to Review 2)

Review 1 found a platform **navigating product decisions under development pressure** — open registration vs. invite-only, Posh reconciliation, sponsor/vendor model, community feed wiring. Every major finding required a product decision, not just a code change. The review session itself served as a product design session, with decisions documented inline.

Review 2 found a platform **with settled product decisions and maturing architecture** — the big questions are answered, the commercial model is built, the infrastructure is solid. The new concerns are engineering hygiene: CI/CD, file size, transaction wrappers, CLAUDE.md sustainability. These are the concerns of a project that knows what it's building and is asking whether it's building it durably.

This is a healthy trajectory. The sequence is correct: decide what to build → build it → harden it. Most projects skip the middle step (deciding) or the last step (hardening). This one did both in sequence.

### The Velocity Paradox

Review 2 noted something Review 1 couldn't see: the full scope of what was built by a single developer in approximately 5 months. By Review 2, the platform had a complete backend (32+ admin endpoints, full social API, webhook handler, S3 integration, audit logging), two Flutter apps, operational infrastructure (COOP, migrations, deploy scripts, smoke tests), and comprehensive documentation. The COOP system alone — 2,350 lines of bash — represents weeks of traditional DevOps work.

This velocity is the AI-assisted development story. But Review 2 also identified the failure mode: **velocity without a test harness compounds risk faster than it creates value**. At 25K lines with minimal test coverage, the next architectural change carries more risk than the first one did.

### What Review 3 Would Find (Prediction)

If a third review were conducted after the technical debt roadmap is executed:

- **Closed:** CI/CD (the roadmap addresses this explicitly)
- **Closed:** admin.ts monolith (tracked, straightforward)
- **Closed:** Missing transactions (tracked, well-understood)
- **Still open, elevated risk:** Community feed stubs (if social development doesn't accelerate)
- **Still open:** Flutter test suite (requires explicit discipline, not just a task)
- **New concern:** React admin migration complexity (new parallel codebase = new context maintenance burden)
- **New concern:** OpenAI API costs at scale (marketing insights without cost controls)
- **New positive:** Shareable type definitions across API + React admin (Zod → TypeScript inference)

---

## The Single Most Important Finding of the Trajectory

Between the two reviews, **the commercial side of the platform advanced significantly while the social side stalled.** The customers, products, discounts, and revenue infrastructure grew from "deferred pending product owner input" to "74 tests, complete CRUD, unified model." The community feed, creative search, and perks/discounts UI on the social side remained stubs.

This is not a criticism — it may be the right prioritization for a pre-launch platform (get the revenue infrastructure right before opening the doors). But it means the social app, as it stands today, is not yet a social app. It's an event check-in app with a profile screen. The community, the discovery, the perks — the things that keep people coming back between events — are not yet real.

**The platform is ready to transact. It is not yet ready to retain.**

---

*Trajectory analysis based on: `docs/analysis/adversarial_review.md` (March 1, 2026) and `docs/analysis/ai_assisted_maturity_review.md` (March 2026).*
