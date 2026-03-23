# Industry Night — CODEX Execution Tracks

**Purpose:** High-level map of all implementation tracks, their sequences, dependencies, model assignments, and A/B test designations.

**Last Updated:** March 22, 2026

**Legend:** ⚡ = A/B test (run both Claude + OpenAI models; adversarial panel review before merge)

---

## Branch Naming Convention

```
integration
└── feature/{prompt-id}-{short-name}              ← base branch (never committed to directly)
    ├── feature/{prompt-id}-{short-name}/claude    ← Claude model execution
    └── feature/{prompt-id}-{short-name}/gpt       ← OpenAI model execution (A/B prompts only)

Examples:
  feature/C0-schema-foundation
  feature/C0-schema-foundation/claude
  feature/C0-schema-foundation/gpt

  feature/B0-react-scaffold
  feature/B0-react-scaffold/claude
  feature/B0-react-scaffold/gpt

  feature/A1-community-board             ← non-A/B: single branch, no /claude suffix needed
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

## Status Tracker

Update this table as prompts complete.

| Prompt | A/B | Status | Winner | Log | Review | Notes |
|--------|-----|--------|--------|-----|--------|-------|
| C0 | ⚡ | ✅ Merged | Claude | docs/codex/log/C0-control-decision.md | docs/codex/reviews/C0-adversarial-review.md | Winner-only control-session apply executed on AWS dev; C0 schema gate complete |
| A0 | ⚡ | ⬜ Not started | — | — | — | |
| B0 | ⚡ | ⬜ Not started | — | — | — | |
| C1 | — | ⬜ Not started | — | — | — | Waiting for C0 |
| C2 | — | ⬜ Not started | — | — | — | Waiting for C0 |
| A1 | — | ⬜ Not started | — | — | — | Waiting for C0, A0 |
| B1 | — | ⬜ Not started | — | — | — | Waiting for C0, B0 |
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
