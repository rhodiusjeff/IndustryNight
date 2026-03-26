# Post-Run Carry-Forward Report

Scope: X1 — Schema Consolidation (single-model, non-A/B)
Owner: Track Control Agent
Date: 2026-03-25
Save location: `docs/codex/log/track-X/X1/post-run-carry-forward.md`

---

## Header
- Prompt ID: X1
- Prompt title: Schema Consolidation — collapse migrations 001-007 into single baseline
- Track: X (Operational)
- Date: 2026-03-25
- Control owner: Track Control Agent (claude-sonnet-4-6)
- Branches reviewed: `feature/X1-schema-consolidation`
- Winner model: N/A (single-model)
- Merge target: `integration`

---

## Evidence Reviewed
- Prompt spec path: `docs/codex/track-X/X1-schema-consolidation.md`
- Completion report path: `docs/codex/log/track-X/X1/control-decision.md`
- Review path(s): N/A (non-A/B; no adversarial review panel)
- Test output summary: 145 Jest / 30 Flutter / 25 E2E (local); 7/7 AWS (two runs)
- Deployment/smoke verification: Full 7-phase closeout passing including fresh-schema proof run
  (`test_logs/X1_closeout_test_2026-03-25_212313.log`)

---

## Decision Summary
- Final status: **Pass with deviations** (all deviations accepted)
- What is accepted:
  - `prevent_audit_log_mutation()` repositioned after tables (pg_dump 18 / PG 15 %TYPE compatibility fix)
  - `products_catalog.sql` added as new seed file (restores catalog data lost in schema-only dump)
  - `db-reset.js` updated with `DROP FUNCTION` guard + products_catalog seed load
  - AWS validation via `db-reset.js` instead of live RDS re-deploy (fresh-schema proof stronger than spec's path)
- What is rejected: Nothing
- Deviations from prompt and rationale:
  - Function ordering: pg_dump 18 emits functions before tables; PG 15 `%TYPE` resolution requires
    table to exist before reference. Repositioning is the only correct fix.
  - products_catalog.sql: pg_dump --schema-only drops INSERT statements. The old baseline had inline
    product inserts; these must live in a seed file going forward.

---

## Lessons Learned
- What worked:
  - db-reset as validation method — faster than spec's path and stronger (proves fresh-schema from zero)
  - Keeping products in a separate seed file is the correct pattern; this is better than inline INSERTs
    in migration SQL
  - Closing spec called `closeout-test.sh --local-only` first, then `--env dev` — good sequencing
- What failed or drifted:
  - pg_dump 18 function ordering is a known gotcha. The X1 spec warned about enum order but not
    function %TYPE order. Should be documented.
- Process gaps observed:
  - The spec did not include `products_catalog.sql` because the pg_dump scope wasn't fully analyzed
    before spec was written. For any future schema dump-and-replace, always verify seed data coverage
    before executing.
- Model behavior notes: N/A (single-model)

---

## Carry-Forward Actions

### Rule: pg_dump function %TYPE ordering gotcha
- **Rule added:** When using `pg_dump --schema-only`, any function that uses `%TYPE` references against
  a table column (e.g., `col users.id%TYPE`) will fail on PG 15 if the function appears before the
  table in the dump. Always move such functions to after the table DDL block.
- **Effective from prompt ID:** X1 (applies retroactively to all future schema dump work)
- **Files to update now:** `docs/codex/README.md` — add to gotchas/lessons section

### Rule: Seed data coverage check before schema dump
- **Rule added:** Before executing a schema-only dump-and-replace, enumerate all reference/seed data
  that is currently embedded in migration SQL (INSERT statements). Ensure it is either re-embedded or
  moved to a dedicated seed file. Verify seed load order in `db-reset.js`.
- **Effective from prompt ID:** X1

### Migration numbering — post-X1 state (CRITICAL for C1, C2, E0)
- **Rule:** After X1, `packages/database/migrations/` contains exactly one file: `001_baseline_schema.sql`.
  The `_migrations` table on a fresh DB will have exactly 1 row after a clean migrate run.
  The next new migration file must be numbered `002_*`, regardless of how many migrations existed
  historically.
- **C0 status:** C0 is already Closed. Its migration (`004_phase0_foundation.sql`) is archived and
  its schema changes are absorbed into the consolidated `001_baseline_schema.sql`. C0 does NOT
  create a new migration file post-X1.
- **Effective from prompt ID:** X1 (C1 is first prompt to create a new migration post-X1)

### Stale references to patch (MUST apply before C1 and C2 execute)
- **C1** (`docs/codex/track-C/C1-missing-api-endpoints.md`):
  - All body references to `005_post_reports.sql` → `002_post_reports.sql` (lines 235, 240, 242, 246, 822, 828, 870)
  - Line 22: source-of-truth migration `004_phase0_foundation.sql` → `001_baseline_schema.sql`
    (file is now in `archive/`; consolidated baseline is the new reference)
- **C2** (`docs/codex/track-C/C2-push-notifications.md`):
  - Line 22: source-of-truth migration → `001_baseline_schema.sql`
  - Line 42: context read item `004_phase0_foundation.sql` → `001_baseline_schema.sql`
- **Files explicitly frozen (no backward edits):**
  - `docs/codex/track-X/X1-schema-consolidation.md` — frozen (executed)
  - `docs/codex/track-C/C0-schema-migrations.md` — frozen (executed, Closed)

### products_catalog.sql — downstream awareness
- `packages/database/seeds/products_catalog.sql` is now part of the `db-reset.js` seed chain.
  Any prompt that modifies products or tests product-dependent data must be aware this file exists.
  Seed load order: `specialties.sql` → `products_catalog.sql` → `dev_seed.sql`
- No prompt spec changes needed — EXECUTION_CONTEXT.md should note this.

---

## Downstream Impact

| Prompt | Impact | Action required |
|--------|--------|-----------------|
| C1 | Migration must now be `002_post_reports.sql`; source-of-truth file reference stale | Patch spec (done in this carry-forward) |
| C2 | Source-of-truth file reference stale | Patch spec (done in this carry-forward) |
| E0 | Already uses `001_baseline_schema.sql` as reference context — correct | No patch needed |
| All other prompts with migration steps | Must number from `002_*` onward | EXECUTION_CONTEXT.md note |

---

## Validation Gates for Next Prompts

- **C1 required evidence gate:** `002_post_reports.sql` applies cleanly on top of `001_baseline_schema.sql` on a fresh DB. Verify with `db-reset.js` + `migrate.js --dry-run`.
- **C2 required evidence gate:** Any new migration C2 creates must be numbered `003_*` or higher (after C1 merges). Coordinate with C1 merge sequence.
- **E0 required evidence gate:** Same — migration numbering must be coordinated with C1 and C2 merge order before E0 executes.
