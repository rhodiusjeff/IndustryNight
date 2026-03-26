# Industry Night — CODEX Execution Tracks

**Purpose:** High-level map of all implementation tracks, their sequences, dependencies, model assignments, and A/B test designations.

**Last Updated:** March 26, 2026 (B0 winner declared — Jeff signoff received; X2 track approved and scoped)

**Legend:** ⚡ = A/B test (run both Claude + OpenAI models; adversarial panel review before merge)

---

## Branch Naming Convention

```
integration
└── feature/{prompt-id}-{short-name}              ← non-A/B prompt branch
    ├── feature/{prompt-id}-{short-name}-claude    ← Claude model execution (A/B prompts)
    └── feature/{prompt-id}-{short-name}-gpt       ← OpenAI model execution (A/B prompts)

Examples:
  feature/C0-schema-foundation-claude
  feature/C0-schema-foundation-gpt

  feature/B0-react-scaffold-claude
  feature/B0-react-scaffold-gpt

  feature/A1-community-board             ← non-A/B: single branch
```

---

## Parallel Execution Overview

Three tracks can start immediately in parallel. All other tracks wait for C0 to complete.

```
TODAY — Start all three in parallel (all are ⚡ A/B):
  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
  │  ⚡ C0           │  │  ⚡ A0           │  │  ⚡ B0           │
  │ Schema          │  │ Critical Fixes  │  │ React Admin     │
  │ Migrations      │  │ (bugs + app     │  │ Scaffold        │
  │                 │  │  store fixes)   │  │                 │
  │ Sonnet / 5.3    │  │ Sonnet / 5.3    │  │ Opus / GPT-5.4  │
  │ ~3-4 hrs        │  │ ~4-5 hrs        │  │ ~1-2 days       │
  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘
           │                    │                     │
           └────────────────────┼─────────────────────┘
                                │ C0 + adversarial review complete
                                ▼ unlocks all downstream
           ┌────────────────────────────────────────────────────┐
           │  Can now run in parallel (all require C0):         │
           │  C1, C2, A1, B1                                    │
           └────────────────────────────────────────────────────┘
```

---

## Track A — Social App Completion

**Goal:** Wire the Flutter social app's stubbed screens to real API calls. Each prompt is sequential.

| Prompt | Title | Claude | OpenAI | A/B | Effort | Depends On |
|--------|-------|--------|--------|-----|--------|------------|
| A0 | Critical Bug Fixes | sonnet-4-6 | gpt-5.3-codex | ⚡ | Small | None |
| A1 | Community Board | sonnet-4-6 | gpt-5.3-codex | — | Medium | C0, A0 |
| A2 | User Search + Profile | sonnet-4-6 | gpt-5.3-codex | — | Medium | C0, A1 |
| A3 | Perks / Sponsors Display | sonnet-4-6 | gpt-5.3-codex | — | Small | A2 |

**Track A completion:** Full social app retention feature loop working.

---

## Track B — React Admin App

**Goal:** Build the React admin app from scaffold to feature parity with Flutter admin, plus new features.

| Prompt | Title | Claude | OpenAI | A/B | Effort | Depends On |
|--------|-------|--------|--------|-----|--------|------------|
| B0 | Scaffold + Design System | opus-4-6 | gpt-5.4 | ⚡ | Medium | None |
| B1 | Auth + RBAC + Permissions | sonnet-4-6 | gpt-5.4 | — | Medium | C0, B0 |
| B2 | Event Ops Screen + SSE + FCM | sonnet-4-6 | gpt-5.4 | — | Medium | C2, B1 |
| B3 | Admin Parity (all remaining screens) | sonnet-4-6 | gpt-5.3-codex | — | Large | B1, C1 |

**Track B completion:** Full React admin at feature parity with Flutter admin; eventOps role operational.

---

## Track C — Backend + Schema

**Goal:** Fill all backend gaps, add new API endpoints, and implement infrastructure services.

| Prompt | Title | Claude | OpenAI | A/B | Effort | Depends On |
|--------|-------|--------|--------|-----|--------|------------|
| C0 | Schema Migrations (Phase 0) | sonnet-4-6 | gpt-5.3-codex | ⚡ | Small | None |
| C1 | Missing API Endpoints | sonnet-4-6 | gpt-5.3-codex | — | Small | C0 |
| C2 | Push Notifications (FCM) | sonnet-4-6 | gpt-5.3-codex | — | Medium | C0 |
| C3 | Image Assets Architecture | opus-4-6 | gpt-5.4 | ⚡ | Large | C0 |
| C4 | Platform Config + API Key Status | sonnet-4-6 | gpt-5.4-mini | — | Small | C0 |

**Track C completion:** All known backend gaps filled; push notifications live; image asset system operational.

---

## Track D — LLM Pipeline + Analytics

**Goal:** Implement content moderation, analytics pipeline, and event wrap reports.

| Prompt | Title | Claude | OpenAI | A/B | Effort | Depends On |
|--------|-------|--------|--------|-----|--------|------------|
| D0 | Moderation Pipeline (Haiku → Sonnet) | opus-4-6 | gpt-5.4 | ⚡ | Large | C0, A1 |
| D1 | Analytics Pipeline (DuckDB + Influence) | sonnet-4-6 | gpt-5.3-codex | — | Medium | C0 |
| D2 | Event Wrap Reports | sonnet-4-6 | gpt-5.4 | — | Medium | D0, D1 |

**Track D completion:** All community content moderated; nightly analytics populating; event wrap reports auto-generating.

---

## Track E — Jobs Board

**Goal:** Implement the full jobs marketplace: job posters, listings, applications, hire confirmation, ratings.

| Prompt | Title | Claude | OpenAI | A/B | Effort | Depends On |
|--------|-------|--------|--------|-----|--------|------------|
| E0 | Jobs Schema + Backend API | sonnet-4-6 | gpt-5.3-codex | — | Medium | C0 |
| E1 | Jobs Board Social UI (Flutter) | sonnet-4-6 | gpt-5.3-codex | — | Large | E0, A1 |
| E2 | Hire Confirmation + Professional Ratings | sonnet-4-6 | gpt-5.4 | — | Medium | E0, D0 |
| E3 | Job Poster Account Portal | sonnet-4-6 | gpt-5.4 | — | Large | E0 |

**Track E completion:** Full jobs marketplace operational; verified hire confirmation pipeline live; professional ratings available.

---

## Recommended Execution Order

### Week 1 (parallel)
- **C0** — schema migrations (clears the path for everything)
- **A0** — critical bug fixes (unblocks App Store submission)
- **B0** — React admin scaffold (sets architectural foundation)

### Week 2 (parallel after C0 complete)
- **C1** — missing API endpoints (unblocks A1, B3)
- **C2** — push notifications (unblocks B2)
- **A1** — community board wiring (first retention feature)
- **B1** — React admin auth + RBAC

### Week 3
- **A2** — user search + profile
- **B2** — Event Ops screen (needs C2)
- **C3** — image assets backend (large, run concurrently)

### Week 4
- **A3** — perks display (Track A complete)
- **B3** — admin parity (large, may span 2 weeks)
- **C4** — platform config

### Weeks 5-6
- **D0** — moderation pipeline (Tracks A + B must be functional first)
- **D1** — analytics pipeline

### Weeks 7-8
- **E0-E3** — jobs board
- **D2** — event wrap reports

---

## Track X — Exception / Operational Tracks

**Purpose:** Infrastructure, consolidation, and operational interruptions that don't fit the product track model. Single-model (no A/B), control-agent-owned, verified by infrastructure tests rather than adversarial review.

| Prompt | Title | Model | A/B | Effort | Depends On |
|--------|-------|-------|-----|--------|------------|
| X1 | Schema Consolidation | control-agent | — | Small | A0 merged |
| X2-A1 | Admin Ground-Truth Research | control-agent | — | Small | None |
| X2-A2 | Master Plan v3 + User Story Spec | control-agent | — | Medium | X2-A1 + Jeff review |
| X2-B | CODEX Phase Rework + Track Patches | control-agent | — | Medium | X2-A2 + Jeff review |
| X2-C | Apply Patches + Archive Stale Docs | control-agent | — | Small | X2-B + Jeff review |

**Track X completion:** Ongoing — new X-tracks added as operational needs arise.

**X2 Dependency:** B1 cannot start until X2-C is complete. C1, C2, A1 can run in parallel with X2 (no B-track dependency).

**X2 Governance decisions (2026-03-26):**
- Review gate at each sub-prompt: Jeff go/no-go; no-go = iterate until satisfied
- Output: `docs/product/master_plan_v3.md` (new file) + `docs/codex/track-X/admin-user-stories.md`; stale docs archived across all of `docs/`
- Research scope: all docs + live code (`packages/admin-app/`, `packages/api/`, `packages/react-admin/`, all CODEX prompts); **no code changes**
- Design reference: B0 Claude winner working app treated as the new mockup; `docs/design/admin-mockup.html` included in reconciliation
- User story granularity: one story per workflow (not per screen interaction)
- Completed tracks are read-only; gaps addressed by new downstream prompts only
- B0 re-run decision deferred to X2-B
- Spec sync check added to carry-forward template in X2-C

---

## Post-Track Completion Gate (Preproduction)

When all tracks are complete (preproduction), execute this finalization sequence:

1. Collapse all accumulated migrations into a single fresh initial schema baseline.
2. Snapshot/backup database state.
3. Perform full infrastructure teardown and rebuild from scratch.
4. Apply the consolidated baseline schema in the rebuilt environment.
5. Run end-to-end completion validation as the final system integrity test.

Until that completion gate, continue using incremental migrations as normal.

---

## Status Tracker

Update this table as prompts complete.

| Prompt | A/B | Status | Winner | Log | Review | Notes |
|--------|-----|--------|--------|-----|--------|-------|
| C0 | ⚡ | ✅ Closed | Claude | docs/codex/log/track-C/C0/control-decision.md | docs/codex/reviews/C0-adversarial-review.md | Winner-only control-session apply executed on AWS dev; C0 schema gate complete |
| A0 | ⚡ | ✅ Closed | GPT | docs/codex/log/track-A/A0/control-decision.md | docs/codex/reviews/A0-adversarial-review.md | Merged to integration 2026-03-25 (PR #54, commit 2f63641); all 4 gates green |
| X1 | — | ✅ Closed | N/A | docs/codex/log/track-X/X1/control-decision.md | — | Merged 2026-03-25 (PR #58, e37e3cb); 145 Jest / 30 Flutter / 25 E2E + 7/7 AWS; fresh-schema proof complete |
| B0 | ⚡ | 🔶 Reviewing | Claude (claude-sonnet-4-6) | — | docs/codex/reviews/B0-adversarial-review.md | Winner: Claude. **Jeff signoff received 2026-03-26.** PR #63 parked pending X2-B re-run verdict. If merged as-is: 2 remaining pre-merge items (client.ts proxy fix, playwright fallback port). **B1 blocked until X2-C complete.** |
| X2-A1 | — | ⬜ Not started | — | — | — | Ground-truth research: docs + code archaeology |
| X2-A2 | — | ⬜ Not started | — | — | — | Waiting for X2-A1 + Jeff review |
| X2-B | — | ⬜ Not started | — | — | — | Waiting for X2-A2 + Jeff review |
| X2-C | — | ⬜ Not started | — | — | — | Waiting for X2-B + Jeff review |
| C1 | — | ⬜ Not started | — | — | — | Waiting for C0 |
| C2 | — | ⬜ Not started | — | — | — | Waiting for C0 |
| A1 | — | ⬜ Not started | — | — | — | Waiting for C0, A0 |
| B1 | — | ⬜ Not started | — | — | — | Waiting for C0, B0, **X2-C** |
| B2 | — | ⬜ Not started | — | — | — | Waiting for B1, C2 |
| A2 | — | ⬜ Not started | — | — | — | Waiting for A1 |
| C3 | ⚡ | ⬜ Not started | — | — | — | Waiting for C0 |
| C4 | — | ⬜ Not started | — | — | — | Waiting for C0 |
| A3 | — | ⬜ Not started | — | — | — | Waiting for A2 |
| B3 | — | ⬜ Not started | — | — | — | Waiting for B1, C1 |
| D0 | ⚡ | ⬜ Not started | — | — | — | Waiting for A1 |
| D1 | — | ⬜ Not started | — | — | — | Waiting for C0 |
| D2 | — | ⬜ Not started | — | — | — | Waiting for D0, D1 |
| E0 | — | ⬜ Not started | — | — | — | Waiting for C0 |
| E1 | — | ⬜ Not started | — | — | — | Waiting for E0, A1 |
| E2 | — | ⬜ Not started | — | — | — | Waiting for E0, D0 |
| E3 | — | ⬜ Not started | — | — | — | Waiting for E0 |

**Status values:** ⬜ Not started → 🔵 In progress → 🟡 Claude done / GPT done → 🟠 Under adversarial review → ✅ Merged
**Winner values:** Claude / GPT / Cherry-pick / N/A
