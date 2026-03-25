# X1 — Schema Consolidation

**Track:** X (Exception / Operational)
**Model:** control-agent (single-model, no A/B)
**Effort:** Small
**Depends on:** A0 merged to `integration`
**Status:** ⬜ Not started

---

## Objective

Collapse migrations `001` through `007` into a single new `001_baseline_schema.sql` that represents the full current schema. Archive the original incremental files. This is a pure restructuring — no schema changes, no data changes, no new features.

After X1, the migrations folder will have exactly one file: `001_baseline_schema.sql`. Future migrations start at `002_*.sql`.

---

## Rationale

Seven incremental migrations have accumulated since project start. Each is correct individually but together they represent archaeological history, not a useful starting point. Before the next round of schema-changing tracks (C1, C2, C3, etc.) adds more, consolidate now while the baseline is stable.

This must happen **after A0** (which fixes audit_log cascade and adds test infrastructure) and **before** any track that adds new migrations.

---

## Execution Plan

### Phase 1 — Capture current schema

**Step 1: Port-forward to dev RDS**
```bash
./scripts/pf-db.sh --env dev start
```

**Step 2: pg_dump schema-only from dev RDS** (which has all 7 migrations applied)
```bash
pg_dump \
  --schema-only \
  --no-owner \
  --no-acl \
  --no-privileges \
  -h 127.0.0.1 \
  -p 5433 \
  -U postgres \
  -d industrynight \
  -f /tmp/schema_dump_x1.sql
```

**Step 3: Clean the dump**
Edit `/tmp/schema_dump_x1.sql` to remove:
- `pg_dump` header comment block
- `SET` statements (`SET client_encoding`, `SET standard_conforming_strings`, etc.)
- `SELECT pg_catalog.set_config(...)` lines
- Any `--` comment lines referencing specific object names (optional — keep schema-level comments)
- The `_migrations` table DDL (this table is managed by `migrate.js`, not by the migration files themselves)

The result should be clean DDL: enums → tables → indexes → triggers → functions, in dependency order.

**Step 4: Add file header**
Prepend:
```sql
-- 001_baseline_schema.sql
-- Consolidated baseline schema (replaces 001–007 incremental migrations)
-- Generated from dev RDS as of X1 execution on [DATE]
-- Do not edit incrementally — create 002_*.sql for future changes
```

---

### Phase 2 — Replace migration files

**Step 5: Archive old migrations**
```bash
cd packages/database/migrations
mkdir -p archive
mv 001_baseline_schema.sql archive/001_baseline_schema_original.sql
mv 002_event_images.sql archive/
mv 003_customers_products.sql archive/
mv 004_drop_event_image_url.sql archive/
mv 005_posh_orders.sql archive/
mv 006_discount_redemptions.sql archive/
mv 007_audit_log_cascade.sql archive/
```

*(Adjust filenames to match actual files — check `packages/database/migrations/` before running.)*

**Step 6: Place new consolidated file**
```bash
cp /tmp/schema_dump_x1.sql packages/database/migrations/001_baseline_schema.sql
```

**Step 7: Update `scripts/migrate.js` if needed**
Verify `migrate.js` reads all `.sql` files in the migrations folder sorted alphanumerically. No change needed if it already does this — the new `001_baseline_schema.sql` will be picked up automatically.

---

### Phase 3 — Validate locally

**Step 8: Teardown and rebuild local Docker postgres**
```bash
# Stop any running api containers, then:
docker rm -f pg-local 2>/dev/null || true
docker run -d \
  --name pg-local \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=industrynight \
  -p 5432:5432 \
  postgres:15
sleep 3
```

**Step 9: Apply new consolidated migration only**
```bash
DB_HOST=localhost DB_PORT=5432 DB_NAME=industrynight DB_USER=postgres \
DB_PASSWORD=postgres DB_SSL=false \
node scripts/migrate.js --skip-k8s
```

Expected output: `[migrate] Applied: 001_baseline_schema.sql` — no other files.

**Step 10: Run full local closeout suite**
```bash
./scripts/closeout-test.sh X1 --local-only
```

Expected: Phase 1 (Jest 145/145), Phase 2 (Flutter 30/30), Phase 3 (E2E 25/25).

If any test fails, the dump or cleanup step introduced a schema difference. Compare failing migration with archived files.

---

### Phase 4 — AWS validation

**Step 11: Apply to dev RDS**
Since dev RDS already has all 7 migrations applied, the `_migrations` table already tracks them. The consolidated file is a **drop-in replacement** for fresh environments only — no need to re-apply to dev RDS.

To validate end-to-end on AWS (full rebuild):
```bash
./scripts/closeout-test.sh X1 --env dev
```

This runs phases 4–7: migrate RDS → deploy EKS → E2E → smoke.

---

### Phase 5 — PR and merge

**Step 12: Commit and push**
```bash
git add packages/database/migrations/
git commit -m "feat(X1): consolidate migrations 001-007 into new 001_baseline_schema.sql"
git push -u origin feature/X1-schema-consolidation
```

**Step 13: Open PR → integration**
```bash
gh pr create \
  --base integration \
  --head feature/X1-schema-consolidation \
  --title "feat(X1): schema consolidation - collapse 001-007 into single baseline" \
  --body "Operational track X1. No schema changes — pure restructuring. Verified by 197 tests (145 Jest + 30 Flutter + 25 E2E) plus AWS smoke."
```

**Step 14: After merge — update tracker and write decision log**
Update [docs/codex/tracks.md](../tracks.md): X1 row → `✅ Merged`.

Create `docs/codex/log/X1-control-decision.md` with:
- Migration files archived and new filename
- Closeout test results summary (phases 1–7, pass counts)
- Raw log filename (`test_logs/X1_closeout_test_YYYY-MM-DD_HHMMSS.log` — git-ignored, local only)
- Merge SHA and date

The tracker "Log" column points to the decision doc; the decision doc references the raw log by name for local auditability.

---

## Validation Criteria

| Check | Pass Condition |
|-------|---------------|
| `migrate.js` on clean DB | Only `001_baseline_schema.sql` applied, no errors |
| Jest suite | 145/145 passing |
| Flutter tests | 30/30 passing |
| Local E2E | 25/25 passing |
| AWS migrate | No errors on dev RDS re-deploy |
| AWS smoke | All endpoints respond correctly |
| `_migrations` tracking | On fresh DB: exactly 1 row (`001_baseline_schema.sql`) |
| Archive intact | 002–007 all present in `migrations/archive/` |

---

## Risk Notes

- **Do not change any column names, types, or constraints.** This is a pure snapshot — if the dump differs from what the app expects, revert.
- **Check enum order.** PostgreSQL dumps enums before tables. Ensure all enum types used in table columns appear earlier in the file.
- **Triggers and functions.** `pg_dump --schema-only` includes trigger functions (`plpgsql`). Verify these appear before the `CREATE TRIGGER` statements that reference them.
- **Dev RDS is not affected** by this PR — it already has the schema. Only fresh environments (new dev spins, CI, teardown+rebuild) use the new file.

---

## Branch

```
integration
└── feature/X1-schema-consolidation
```

No `-claude` / `-gpt` suffixes. No adversarial review. Control agent owns execution start to finish.
