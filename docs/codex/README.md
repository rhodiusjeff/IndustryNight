# Industry Night — CODEX Prompt Library

**Purpose:** Each file in this directory is a self-contained execution prompt for a code-generating AI agent. A CODEX prompt gives the agent everything it needs to produce working, tested code without additional context: a precise goal, acceptance criteria, user stories, and a test specification.

**Platform Reference:** Master plan and architecture decisions live in `docs/product/master_plan_v2.md`. Schema reference is in `CLAUDE.md`. Before executing any prompt, the agent should read both.

---

## How to Execute a Prompt

1. Open the prompt file and read it fully before writing a line of code.
2. Read the referenced context documents listed in the prompt's **Context** section — this includes `docs/codex/EXECUTION_CONTEXT.md` (always first) and the relevant section of `docs/product/user-stories.md` (identified in your prompt's Context entry).
3. Implement the feature described in **Goal**.
4. Verify all **Acceptance Criteria** are satisfied.
5. Write the tests specified in the **Test Suite** section and confirm they pass.
6. Commit with the message format: `feat(track-X): <short description>`
7. In your completion log, include a **User Story Deviations** subsection — list each story from your relevant section and note whether implemented as written or deviated. See `EXECUTION_CONTEXT.md §8` for the format.

Important:
- Prompt execution output is provisional until control gates pass.
- Review and closeout governance is control-owned (local review gate + GitHub review gate + validation evidence gate).
- **Local-first execution is mandatory.** Verify with Jest testcontainers and local Flutter/widget tests before touching shared dev or AWS.
- **Interrogative session is optional.** If skipped, capture any product-owner guidance in the carry-forward report instead.
- **User stories are a strong reference, not a hard spec.** Deviations are allowed with rationale — silence is not. See `EXECUTION_CONTEXT.md §8`.

Control operator guide:
- `docs/codex/guides/control_plane_user_manual.md`

---

## Post-Run Carry-Forward (Control Context)

Use this process to apply lessons forward without rewriting historical prompts.

Principles:
- Freeze executed prompts as historical artifacts.
- Apply lessons only to downstream prompts and shared protocol/templates.
- For A/B prompts, adjudicate first, then carry-forward.
- **User story amendments:** For every deviated story, TC decides Update / Accept / Flag and updates `docs/product/user-stories.md` accordingly. Amended stories are recorded in the Amendment Log at the bottom of that file, preserving the original text for lessons-learned tracing. See `EXECUTION_CONTEXT.md §8` for the full protocol.

Artifacts:
- Reports (instance outputs): `docs/codex/log/track-{X}/{ID}/post-run-carry-forward.md` — co-located with TC control decision and agent completion report(s)
- Template: `docs/codex/carry-forward/_TEMPLATE.md`
- Prompt-level control run: `docs/codex/carry-forward/CONTROL_POST_RUN_PROMPT.md`
- Track-level synthesis: `docs/codex/carry-forward/TRACK_SYNTHESIS_PROMPT.md`
- Phase consolidation/replay prep: `docs/codex/carry-forward/PHASE_CONSOLIDATION_PROMPT.md`

Recommended sequence:
1. Prompt completes and tests are verified.
2. Control context runs the post-run carry-forward prompt and writes a carry-forward report.
3. Only forward targets are patched (unexecuted prompts and shared templates/protocol docs).
4. **All governance artifacts (control-decision.md, tracks.md, carry-forward, downstream patches)
   are committed to the feature branch before PR merge.** Stakeholder is notified when ready.
5. Stakeholder merges the PR.
6. After full track completion, control context runs track synthesis.
7. At phase end, control context runs phase consolidation for replay readiness planning.

---

## Parallel Execution Map

Tracks can execute in parallel where dependency arrows allow. Within a track, prompts are strictly sequential.

```
         C0-schema-migrations          ← START HERE (blocks A1+, B1+, C1+)
        /          |           \
       A0          |            B0
  (critical      (C1           (react-admin
   fixes)      missing         scaffold)
       |         endpoints)      |
       A1            |           B1
  (community       C2            (auth + rbac)
    board)      (push notif)      |
       |            |             B2
       A2           C3           (event ops)
  (search +     (image assets)    |
   profile)         |             B3
       |             \           (parity)
       A3              \
   (perks)              D0
                   (moderation
                    pipeline)
                        |
                    D1, D2, E0...
```

**Can start in parallel today (no dependencies):**
- C0 — schema migrations
- A0 — critical bug fixes
- B0 — React admin scaffold

**C0 must complete before:** A1, B1, C1, C2, C3, B2

**A0 must complete before:** A1 (A0 fixes posts.ts SQL that A1 relies on)

---

## Shared Dev DB Safety (Parallel Runs)

When prompts are executed in parallel, treat the AWS dev database as a shared environment.

- Prefer local-only verification first: Jest testcontainers, local Flutter/widget tests, and static checks.
- Use shared dev DB only for final smoke/manual verification that requires integrated services.
- Use unique test identities per lane/session (for example lane-specific phone/email) to avoid cross-lane collisions.
- Do not run destructive global operations during prompt execution (for example full resets).
- If any prompt creates shared test data, include explicit cleanup commands in the prompt completion notes.

Recommended cleanup scripts (targeted):

- `node scripts/db-uncheckin.js [--skip-k8s] [--yes] <phone>`
- `node scripts/db-unconnect.js [--skip-k8s] [--yes] <phone>`
- `node scripts/db-scrub-user.js [--skip-k8s] [--yes] <phone>`

For A/B prompts touching schema or shared infrastructure, continue using winner-only control-session apply after review.

---

## Model Recommendations

Two families are recommended: Anthropic (Claude) and OpenAI (GPT-5.x-Codex / GPT-5.4). The prompts are model-agnostic — pick the family you're running in. Within each family, apply the same tier logic: use the stronger/more capable model for architectural prompts that set precedent; use the balanced model for implementation prompts that follow a clear spec.

**March 2026 benchmark context:**
- GPT-5.3-Codex leads on Terminal-Bench 2.0 (77.3% vs 75.1%) — advantage for terminal-heavy workflows (SQL, CLI, running test suites)
- GPT-5.4 leads on SWE-Bench Pro (57.7% vs 56.8%) and tool orchestration (54.6% vs 51.9%) — advantage for multi-tool chaining and architectural scaffolding
- GPT-5.4 mini: 30% of GPT-5.4 usage cost, 2x faster — appropriate for well-scoped, low-ambiguity prompts only

| Prompt | Claude Model | OpenAI Model | Why |
|--------|-------------|--------------|-----|
| C0 - schema migrations | claude-sonnet-4-6 | gpt-5.3-codex | Terminal-first: psql verification, node scripts, grep checks — GPT-5.3-Codex's Terminal-Bench edge is tangible here |
| A0 - critical fixes | claude-sonnet-4-6 | gpt-5.3-codex | Mixed Dart/TypeScript surgical fixes with flutter build + jest verification loops |
| B0 - React admin scaffold | claude-opus-4-6 | gpt-5.4 | Architectural foundation with multi-tool chaining; GPT-5.4's tool orchestration score matters; do NOT use mini |
| A1 - community board | claude-sonnet-4-6 | gpt-5.3-codex | API wiring in Dart; terminal test runs; well-defined spec |
| B1 - auth + RBAC | claude-sonnet-4-6 | gpt-5.4 | Security-critical TypeScript; tool orchestration for running auth tests |
| B2 - event ops screen | claude-sonnet-4-6 | gpt-5.4 | SSE + React + FCM trigger; multi-tool verification |
| C1 - missing endpoints | claude-sonnet-4-6 | gpt-5.3-codex | Fill existing route patterns; terminal verification |
| C2 - push notifications | claude-sonnet-4-6 | gpt-5.3-codex | Well-specified FCM integration with terminal test validation |
| C3 - image assets | claude-opus-4-6 | gpt-5.4 | Architectural refactor across schema + S3 + upload flows + LLM job; high complexity |
| D0 - moderation pipeline | claude-opus-4-6 | gpt-5.4 | Multi-stage LLM orchestration design; queue architecture; high precedent-setting |
| D1 - analytics/DuckDB | claude-sonnet-4-6 | gpt-5.3-codex | Batch compute cron; terminal-heavy validation |
| E0 - jobs schema + API | claude-sonnet-4-6 | gpt-5.3-codex | New table + CRUD following established patterns; terminal test runs |

**Fast-path option:** GPT-5.4 mini is appropriate for C1, C4, and E0 where the spec is extremely tight and the work is pattern-matching against existing code. Not recommended for anything with architectural decisions or cross-cutting concerns.

**General principle:** Use the stronger model (Opus / GPT-5.4) when the prompt involves architectural decisions that set precedent for everything built on top. Use the balanced model (Sonnet / GPT-5.3-Codex) for implementation that follows a clear spec. Never use Haiku or GPT-5.4 mini for prompts spanning more than 3 files or requiring architectural judgment.

---

## Prompt Template

```markdown
# [Track-##] Title

**Track:** [A/B/C/D/E]
**Sequence:** [# of # in track]
**Model:** claude-[model]
**Alternate Model:** [openai model] ← [one-line rationale]
**A/B Test:** Yes | No  ← if Yes, run both models on separate branches before merging
**Estimated Effort:** [Small / Medium / Large]
**Dependencies:** [List prompt IDs that must complete first, or "None"]

---

## Context

> Files and documents to read before writing any code.

- `CLAUDE.md` — full project reference
- `docs/product/master_plan_v2.md` — architecture decisions
- [specific files relevant to this prompt]

---

## Goal

[1-3 sentence precise description of what must be built]

---

## Acceptance Criteria

- [ ] Criterion 1
- [ ] Criterion 2
- [ ] ...

---

## User Stories

| Actor | Story | Notes |
|-------|-------|-------|
| Social user | ... | |
| Admin | ... | |
| System | ... | |

---

## Technical Spec

[Precise implementation notes: file paths, function signatures, data shapes, error handling requirements]

---

## Test Suite

### Unit Tests
[Specific test cases with inputs and expected outputs]

### Integration Tests
[End-to-end scenarios]

### Smoke Tests
[Minimal "is it working" checks for post-deploy verification]

---

> **Completion Report:** The executing agent writes a separate `{lane}-completion.md` file to `docs/codex/log/track-{X}/{ID}/` using `docs/codex/log/_TEMPLATE.md`. For non-A/B prompts the file is named `completion.md`. This file does NOT go in the prompt spec. See **Log Directory Convention** below.

---

## Acceptance Criteria Checklist Format

Every CODEX prompt's acceptance criteria must be verifiable — not aspirational. Good examples:

✅ `GET /posts returns 200 with paginated results for a verified user`
✅ `Unauthenticated request to GET /posts returns 401`
✅ `unlikePost() completes without throwing a type error`
✅ `Sidebar renders only Event Ops section for eventOps role users`

Bad examples (not verifiable by a test):
❌ `The UI feels smooth`
❌ `Code is well-organized`
❌ `Error handling is robust`

---

## A/B Testing Protocol

**Selected prompts** (see CODEX_TRACKER.xlsx for live status): C0, A0, B0, C3, D0

**Branch naming convention:**
```
integration
└── feature/{prompt-id}-{short-name}          ← non-A/B prompt branch
    ├── feature/{prompt-id}-{short-name}-claude   ← Claude model execution (A/B prompts)
    └── feature/{prompt-id}-{short-name}-gpt      ← OpenAI model execution (A/B prompts)
```

Example for C0:
```
feature/C0-schema-foundation-claude
feature/C0-schema-foundation-gpt
```

**Execution sequence for A/B prompts:**
1. Create `feature/{prompt-id}-{short-name}-claude` and `feature/{prompt-id}-{short-name}-gpt` off `integration`
2. Run the prompt on each model branch independently (same prompt, same context, different model)
3. Each model writes `{lane}-completion.md` to `docs/codex/log/track-{X}/{ID}/` using `docs/codex/log/_TEMPLATE.md` (e.g. `claude-completion.md`, `gpt-completion.md`)
4. Adversarial panel (Option B — four role evaluators) runs against both; writes `docs/codex/reviews/{prompt-id}-adversarial-review.md`
5. Product owner picks winner (or cherry-picks specific parts)
6. Winning branch squash-merges to `integration`; other branch archived
7. Update CODEX_TRACKER.xlsx with outcome + rationale

**For non-A/B prompts:**
1. Create `feature/{prompt-id}-{short-name}` off `integration`
2. Run with the model designated in the prompt header by default
3. Product owner may override to the `Alternate Model` at execution time based on latest A/B evidence and operational context
4. Agent writes `completion.md` to `docs/codex/log/track-{X}/{ID}/` using `docs/codex/log/_TEMPLATE.md`
5. Merge review (single reviewer, not full adversarial panel)
6. Squash-merge to `integration`

---

## Log Directory Convention

Every executed prompt produces two co-located files in `docs/codex/log/track-{X}/{ID}/`:

| File | Written by | Purpose |
|------|-----------|---------|
| `{lane}-completion.md` (A/B) or `completion.md` (non-A/B) | **Execution agent** | Self-report: deviations, decisions, technical debt, carry-forward notes for next prompt |
| `control-decision.md` | **Track Control Agent** | Gate verdicts, finding dispositions, tracker updates, stakeholder signoff |

**Rules:**
- Execution agents write ONLY their `{lane}-completion.md`. They do NOT touch `control-decision.md` or any other TC-owned artifact.
- Track Control writes ONLY `control-decision.md`. TC may read agent completion reports but does not edit them.
- Both files are required before a prompt can be marked Closed.
- Prompt spec files do NOT contain completion reports. The spec is a reusable template; the log directory captures run-specific outputs.
- Existing prompt specs that contain a `## Completion Report` section are considered stale. That section is ignored at runtime; agents write to the log directory instead. Stale sections will be removed during X2-C spec cleanup.

---

## Adversarial Panel — Option B

Four role-specialized evaluators. Each receives: the prompt spec + the model's output. See `ADVERSARIAL_PANEL_TEMPLATE.md` for the full evaluator prompts.

| Evaluator | Focus | Key Questions |
|-----------|-------|---------------|
| **Correctness** | Does the code do what the spec says? | All acceptance criteria met? Edge cases handled? |
| **Security** | Are there vulnerabilities? | Input validation? Auth checks? SQL injection? Token handling? |
| **Test Coverage** | Are the tests meaningful? | Tests actually verify behavior? Edge cases covered? Easy to game? |
| **Patterns** | Does it fit the codebase? | Follows CLAUDE.md gotchas? Consistent with existing style? No unnecessary abstractions? |

Each evaluator scores on a 1-5 scale per criterion and writes a free-text finding. The panel summary recommends: **Claude wins** / **GPT wins** / **Cherry-pick** (with specific callouts) / **Re-run** (if both have critical failures).
