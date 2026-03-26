# Track X2 — Admin Spec Rebase

**Type:** Operational / Governance  
**Owner:** Track Control Agent  
**Created:** 2026-03-26  
**Status:** In Planning — X2-A1 not yet started

---

## Why This Track Exists

B0 execution exposed a structural gap: the B-track CODEX prompts were derived from `master_plan_v2.md` (a vision document), not from a reconciled ground-truth spec that accounts for what the Flutter admin app already ships. The result was a React scaffold missing Tickets, Markets, sidebar section headers, and several admin workflows, with no prompts to cover Phase 8 hardening, ToS acceptance, or Admin User CRUD.

X2 does not write product code. It produces first-class guidance documents and a corrected set of CODEX prompts, then feeds those back into the execution tracks before B1 executes. Every sub-prompt has an explicit human review gate (Jeff go/no-go). No-go means iterate until satisfied.

**General rule established for this track and all future carry-forwards:**  
Completed tracks (C0, A0, X1, B0) are read-only. If X2 finds a gap in a completed track, it surfaces a new downstream prompt — it does not reopen or annotate the closed prompt spec.

---

## Governance Decisions (Locked 2026-03-26)

| # | Decision |
|---|----------|
| 1 | Explicit Jeff review gate at each sub-prompt. Go/no-go call. No-go = iterate. |
| 2 | Output is `docs/product/master_plan_v3.md` (new file, v2 archived). Stale docs across all of `docs/` also archived during X2-C. |
| 3 | Research scope: all `docs/` directories + live code (`packages/admin-app/`, `packages/api/routes/`, `packages/react-admin/`, all CODEX prompts). No code changes under any circumstances. |
| 4 | Design reference: `docs/design/admin-mockup.html` included in reconciliation. B0 Claude winner working app treated as the new visual ground truth alongside the mockup. |
| 5 | User story granularity: one story per workflow, not per screen interaction. |
| 6 | Completed tracks are frozen. Gaps surface as new downstream prompts only. |
| 7 | B0 re-run decision deferred to X2-B. Not decided in advance. |
| 8 | Spec sync check added to carry-forward template in X2-C — every future closeout includes a check for spec drift. |

---

## Sub-Prompt Sequence

```
X2-A1 → [Jeff review] → X2-A2 → [Jeff review] → X2-B → [Jeff review] → X2-C → [Jeff review]
```

B1 is blocked until X2-C is complete and patches are applied.  
C1, C2, A1 are unaffected — they can run in parallel with X2.

---

## X2-A1: Ground-Truth Research

**Owner:** Track Control Agent  
**Effort:** Small (1 session)  
**Depends on:** Nothing — start immediately when authorized  
**Gate:** Jeff review of raw inventory before X2-A2 begins

### What Track Control Does

Systematic code and document archaeology across all four source layers simultaneously. Output is a raw inventory — no prose, no storytelling, just facts organized into tables.

**Layer 1 — Docs**
- `docs/product/` — master_plan_v2.md (all sections), requirements.md, implementation_plan.md
- `docs/analysis/` — implementation_audit.md, adversarial_review.md, social_network_analysis.md
- `docs/architecture/` — aws_architecture.md, aws_architecture_rationale.md
- `docs/design/` — admin-mockup.html, ux_design_direction.md, design_deep_dive_handoff.md

**Layer 2 — Flutter Admin (ground truth for what is shipped)**
- Every screen under `packages/admin-app/lib/features/`
- `packages/admin-app/lib/shared/widgets/sidebar.dart` — nav items + section headers
- `packages/admin-app/lib/config/routes.dart` — all routes
- Every API call made by each screen (what endpoints are actually consumed)

**Layer 3 — Backend API (ground truth for what exists)**
- `packages/api/routes/admin.ts` — all admin endpoints
- `packages/api/routes/auth.ts`, `users.ts`, `events.ts`, `markets.ts`, `sponsors.ts`, `discounts.ts`, `webhooks.ts`
- Note which endpoints exist but are not consumed by any current admin UI

**Layer 4 — CODEX Prompts (ground truth for what is planned)**
- All B-track prompts (B0–B3)
- All C-track, D-track, E-track, A-track prompts
- Completed tracks (X1, C0, A0, B0) — read only; gaps noted for new downstream prompts, not reopened

### Deliverable

`docs/codex/track-X/X2-A1-inventory.md` — structured as:

**Section 1: Admin Nav Inventory**  
Table: every nav item across Flutter sidebar, master_plan §5.3, B0 spec NAV_PERMISSIONS, B0 Claude winner, with gap column.

**Section 2: Screen Inventory**  
Table: every admin screen across Flutter (shipped), master plan (planned), B-track prompts (specced), with coverage gaps.

**Section 3: API Coverage Map**  
Table: every admin API endpoint — which Flutter screens call it, which React screens will call it, which prompts spec it, which are orphaned (exist in API but uncovered by any current plan).

**Section 4: Workflow Inventory**  
Table: every end-to-end admin workflow identified across the docs layer — with current coverage status (Flutter ✅ / React specced / React unspecced / Neither).

**Section 5: Intentional Divergence Candidates**  
List of places where the React admin spec diverges from Flutter, noting whether each divergence is documented as intentional or appears to be an accidental omission.

**Section 6: Doc Staleness Flags**  
List of docs in `docs/` that appear outdated relative to current implementation — candidates for archiving in X2-C.

**What Track Control does NOT do in X2-A1:**  
- No product decisions (e.g., whether Tickets is top-level nav in React)
- No writing of user stories
- No modifications to any file outside `docs/codex/track-X/`
- No code changes

---

## X2-A2: Master Plan v3 + User Story Spec

**Owner:** Track Control Agent  
**Effort:** Medium (1–2 sessions)  
**Depends on:** X2-A1 complete + Jeff review and approval  
**Gate:** Jeff review of both output documents before X2-B begins

### What Track Control Does

Using the approved X2-A1 inventory and Jeff's product decisions from the review, write two first-class guidance documents.

**Output 1: `docs/product/master_plan_v3.md`**

Structured as:
- Executive summary of what changed from v2 and why
- Current state assessment (updated — reflects C0, A0, X1, B0 completion)
- New/revised requirements (incorporating lessons from B0 parity review)
- Intentional divergences from Flutter explicitly documented with rationale
- Revised implementation phases — corrected against track coverage gaps
- React admin architecture spec (§5) — updated nav structure, corrected NAV_PERMISSIONS map, sidebar grouping pattern, corrected screen inventory
- Schema migration plan (updated to reflect C0/X1 what was actually applied)

v2 archived to `docs/archive/master_plan_v2.md` (or existing archive folder if present).

**Output 2: `docs/codex/track-X/admin-user-stories.md`**

Actor profiles:
- `platformAdmin` — full access; manages the platform
- `moderator` — content safety; scoped to users + moderation
- `eventOps` — venue-night operations; mobile-optimized; check-in focused
- `system` — automated actors (nightly jobs, SSE, webhooks, FCM)

Story format:
```
US-[ID]: [Short title]
Actor: [role]
Workflow: As a [role], I need to [action] so that [outcome].
Current state: ✅ Flutter / ⚠️ Stubbed / ❌ Not built
React coverage: [B-prompt ID] / ❌ Not specced
API dependency: [endpoint] / ❌ Missing
Priority: P0 / P1 / P2
```

Granularity: one story per workflow. "Manage event images" is one story. The hero-image swap interaction within that workflow is not a separate story — it's a detail in the B3 screen spec.

**What Track Control does NOT do in X2-A2:**  
- No product priority decisions without explicit Jeff input from the X2-A1 review
- No modifications to existing prompt specs
- No code changes

---

## X2-B: CODEX Phase Rework + Track Patch Plan

**Owner:** Track Control Agent  
**Effort:** Medium (1 session)  
**Depends on:** X2-A2 complete + Jeff review and approval  
**Gate:** Jeff review of patch plan and B0 re-run verdict before X2-C begins

### What Track Control Does

Using the approved master_plan_v3 and user story catalogue, produce:

**Output: `docs/codex/track-X/X2-B-track-patch-plan.md`**

For every unexecuted prompt (B1–B3, C1–C4, D0–D2, E0–E3, A1–A3):
- Which user stories does this prompt satisfy?
- Which user stories it was supposed to satisfy but doesn't (gaps)?
- Verdict: **OK** / **Needs Patch** (list specific additions) / **Needs New Prompt**

Then:
- **B0 re-run verdict** with rationale — based on X2-A2 findings, is the scaffold gap large enough to warrant re-running, or are patches to B1 sufficient?
- **New prompts needed** — full list with proposed IDs, titles, track placement, dependencies
- **Execution order update** — revised week-by-week plan incorporating new prompts
- **tracks.md diff** — explicit table of every row/column change needed in tracks.md

**What Track Control does NOT do in X2-B:**  
- No actual edits to any prompt spec yet — the patch plan is approved first
- No code changes

---

## X2-C: Apply Patches + Archive + Template Update

**Owner:** Track Control Agent  
**Effort:** Small (1 session)  
**Depends on:** X2-B complete + Jeff review and approval  
**Gate:** Jeff final review before B1 is unblocked

### What Track Control Does

Execute the approved X2-B patch plan:

1. **Patch unexecuted prompt specs** — surgical additions only; no rewrites. Each patched file gets a header note: `> **Patched by X2-C (2026-MM-DD):** [list of additions]`

2. **Create new prompt files** — for any prompts the patch plan identified as needing to be created from scratch.

3. **Archive stale docs** — move X2-A1 flagged stale documents from `docs/` subdirectories to `docs/archive/`. Update any cross-references.

4. **Update carry-forward template** — add "Spec Sync Check" section to `docs/codex/carry-forward/_TEMPLATE.md`. Template addition:
   ```
   ## Spec Sync Check
   Does the implemented output drift from master_plan_v3 or admin-user-stories.md in ways
   not already captured in the prompt spec? If yes, list each divergence and whether it
   requires a carry-forward patch to a downstream prompt or a new prompt.
   ```

5. **Update tracks.md** — apply all row/column changes from the X2-B patch plan table. Mark X2-C as closed.

6. **Commit** — single commit: `chore(codex): X2-C apply track patches, archive stale docs, update templates`

7. **Unblock B1** — confirm B1 dependency satisfied in tracks.md.

---

## Definition of Done for X2

- [ ] X2-A1 inventory complete and Jeff-approved
- [ ] X2-A2 master_plan_v3.md and admin-user-stories.md complete and Jeff-approved
- [ ] X2-B patch plan complete and Jeff-approved; B0 re-run verdict issued
- [ ] X2-C patches applied; stale docs archived; carry-forward template updated; tracks.md updated
- [ ] B1 unblocked (dependency satisfied)
- [ ] All X2 artifacts committed to `chore/X2-spec-rebase` branch → PR → merged to integration

---

## What X2 Does Not Do

- Modifies no source code in `packages/`
- Does not reopen completed tracks (C0, A0, X1, B0)
- Does not make product prioritization decisions unilaterally — Jeff owns those
- Does not run any execution agents (no Claude/GPT model calls for code generation)
- Does not block C1, C2, or A1 — those tracks can execute in parallel
