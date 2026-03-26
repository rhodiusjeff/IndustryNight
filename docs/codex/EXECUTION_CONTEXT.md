# Execution Context — Industry Night CODEX

**This is a living document.** Read it before touching any code on any CODEX prompt. It captures operational knowledge that is not in CLAUDE.md: test infrastructure conventions, migration system mechanics, post-A0 API ground truth, deployment patterns, and gotchas learned through execution. The Track Control agent owns this document and updates it after each completed track.

**Last updated:** Track A0 carry-forward (March 2026). Control session: `feature/A0-carry-forward`.

---

## 1. Test Infrastructure

### API Tests (Jest + testcontainers)

- Tests run against a **real PostgreSQL container** (Docker), not mocks. Testcontainers starts and tears down the container per test suite.
- `jest.config.ts` **excludes** `tests/e2e/`. E2E tests use a separate config: `jest.e2e.config.ts --runInBand`.
- Run API unit tests: `cd packages/api && npx jest --config jest.config.ts`
- Run E2E tests: `cd packages/api && npx jest --config jest.e2e.config.ts --runInBand`
- **Target test counts** (as of A0 closeout): 142 Jest unit / 30 Flutter widget / 25 E2E
- Test pattern reference: `packages/api/src/__tests__/customers.test.ts` — established testcontainers + supertest structure

### Flutter Widget Tests

- **CRITICAL: `FakeAppState.initialize()` must be a no-op override.** Without this, every widget test that creates/uses `AppState` will crash with `MissingPluginException` from `flutter_secure_storage`. The real `initialize()` calls `SecureStorage.getTokens()`, which requires a platform channel unavailable in test context.
  ```dart
  class FakeAppState extends AppState {
    @override
    Future<void> initialize() async {
      // intentional no-op: SecureStorage has no platform channel in widget tests
    }
  }
  ```
- Test pattern reference: `packages/social-app/test/features/settings/settings_screen_test.dart` (established in A0, GPT lane)
- Run Flutter tests: `cd packages/social-app && flutter test test/`
- After changing any model in `packages/shared/lib/models/`, run: `cd packages/shared && dart run build_runner build --delete-conflicting-outputs`

### Magic Test Prefix

- Pattern: `+1555555xxxx` phones bypass Twilio entirely and use local devCode verification.
- **Active when**: `ENABLE_MAGIC_TEST_PREFIX=true` (dev k8s) OR `NODE_ENV=test` (local Jest) regardless of env var.
- **Hard-disabled when**: `ENABLE_MAGIC_TEST_PREFIX=false` (prod k8s). Returns 400 even if code matches.
- Do not assume this is active just because you're running locally — `NODE_ENV` must be `test`.
- Response from `POST /auth/request-code` with magic prefix: includes `{ devCode: "123456" }` field in addition to normal `{ message: "..." }`.

### closeout-test.sh

Located at `scripts/closeout-test.sh`. Phases:
- **Phase 1A**: Jest unit tests (API)
- **Phase 1B**: Flutter widget tests (social-app)
- **Phase 2**: E2E tests (jest.e2e.config.ts, runs against local API + local DB)
- **`--local-only` flag**: runs phases 1A + 1B + 2 only; no AWS required
- **Phases 3–7**: AWS dev deploy + integration smoke (requires AWS profile `industrynight-admin` and active EKS cluster)
- Use `--env dev` to run the full pipeline including AWS phases.

---

## 2. Migration System

### Post-X1 Conventions (APPLIES ONCE X1 MERGES)

> **Do not apply these conventions until X1 is merged to `integration`.** Until then, 7 separate files exist (001–007).

After X1 merges:
- Single consolidated file: `packages/database/migrations/001_baseline_schema.sql`
- All new migrations: `002_*.sql`, `003_*.sql`, etc. (strictly sequential)
- Naming: `NNN_description_snake_case.sql` where `NNN` is zero-padded to 3 digits
- To find the next migration number: `ls packages/database/migrations/*.sql | tail -1`

### `_migrations` Table

- Managed by `scripts/migrate.js` — the script inserts rows into `_migrations` when a file is successfully applied.
- Migration files themselves do NOT manage `_migrations` (no `INSERT INTO _migrations` in SQL files).
- `migrate.js` is idempotent: already-applied files are skipped by checking `_migrations.filename`.
- Run safely multiple times: `DB_PASSWORD=xxx node scripts/migrate.js --skip-k8s`

### Local Docker DB

```bash
DB_HOST=localhost DB_PORT=5432 DB_SSL=false DB_NAME=industrynight DB_USER=postgres DB_PASSWORD=xxx \
  node scripts/migrate.js --skip-k8s
```

### RDS via Port-Forward

```bash
./scripts/pf-db.sh --env dev start   # tunnels dev RDS to localhost:5433
DB_PORT=5433 DB_SSL=true DB_PASSWORD=xxx node scripts/migrate.js --skip-k8s
```

### Migration Pre-Deploy Rule

**Always run `migrate.js` BEFORE deploying API code that depends on new schema.** The CI/CD pipeline does not auto-run migrations (known gap). Manual order: migrate first, then deploy.

---

## 3. API Ground Truth (Post-A0 Mopup)

These endpoints exist in the codebase **right now**. Do NOT re-implement them. Check `packages/api/src/routes/` before writing any new endpoint.

### Markets (fully implemented)

| Method | Route | Notes |
|--------|-------|-------|
| `GET` | `/markets` | Public list (no auth) |
| `GET` | `/admin/markets` | Admin list with full details |
| `POST` | `/admin/markets` | Create market |
| `PATCH` | `/admin/markets/:id` | Update market |

Customer create/update accepts `marketIds: string[]` for market associations.

### Customer Contacts (fully implemented)

| Method | Route |
|--------|-------|
| `GET` | `/admin/customers/:id/contacts` |
| `POST` | `/admin/customers/:id/contacts` |
| `PATCH` | `/admin/customers/:id/contacts/:contactId` |
| `DELETE` | `/admin/customers/:id/contacts/:contactId` |

### Customer Media (fully implemented)

| Method | Route | Notes |
|--------|-------|-------|
| `GET` | `/admin/customers/:id/media` | List media |
| `POST` | `/admin/customers/:id/media` | Multipart upload; sharp validates image |
| `DELETE` | `/admin/customers/:id/media/:mediaId` | Removes from S3 + DB |

### Event Publish Gate (updated post-A0)

An event cannot be published unless ALL of these are met:
1. `posh_event_id` is set
2. `venue_name` is set
3. At least 1 image exists in `event_images`
4. **`market_id` is set** ← NEW (added in A0 mopup)

Error when market_id is missing: `"Cannot publish: Market must be assigned"`

### Response Contract Notes

- **Post unlike**: returns `{ success: true }` — NOT the full post object
- **Comment delete**: recalculates `comment_count` from `COUNT(*)` query — not a decrement

---

## 4. Deployment & Validation Patterns

### Deploying the API

```bash
# Build, push to ECR, and roll out to EKS
./scripts/deploy-api.sh              # dev (default)
./scripts/deploy-api.sh --env prod   # prod (requires extra confirmation)
```

Always run migrations first if schema changed.

### Deploying React Admin

```bash
./scripts/deploy-admin.sh            # dev
./scripts/deploy-admin.sh --env prod
```

### Running Locally

```bash
cd packages/api && npm run dev                    # API on port 3000
cd packages/social-app && flutter run            # iOS simulator
cd packages/react-admin && npm run dev            # React admin on port 3630
./scripts/run-react-admin.sh                      # with env setup
```

### Smoke Test After Deploy

```bash
./scripts/api-smoke.sh [--env dev|prod]
# Hits: /health, /auth/request-code (magic prefix), /specialties, /admin/dashboard
```

### Environments

| | Dev | Prod |
|---|---|---|
| API domain | `dev-api.industrynight.net` | `api.industrynight.net` |
| Admin domain | `dev-admin.industrynight.net` | `admin.industrynight.net` |
| K8s namespace | `industrynight-dev` | `industrynight` |
| AWS profile | `industrynight-admin` | `industrynight-admin` |

Default for all scripts: `--env dev`. Production requires explicit `--env prod`.

---

## 5. Established Codebase Patterns

### SQL: Always Parameterized

```typescript
// CORRECT — parameterized, safe
db.query('SELECT * FROM users WHERE id = $1', [userId])

// NEVER — string interpolation is a SQL injection vector
db.query(`SELECT * FROM users WHERE id = '${userId}'`) // ❌ BANNED
```

### Service Layer: Graceful Degradation

Every service module (`sms.ts`, `email.ts`, `storage.ts`, `fcm.ts`) exports:
- `const serviceAvailable: boolean` — true only when env vars are present and valid
- Functions that return `false` or fallback values when unavailable — **never throw** on missing config

Example pattern from `sms.ts`:
```typescript
export const twilioAvailable = !!process.env.TWILIO_ACCOUNT_SID && !!process.env.TWILIO_AUTH_TOKEN
export async function sendSms(phone: string, message: string): Promise<boolean> {
  if (!twilioAvailable) return false
  // ... send
}
```

### Route Validation: Always Use `validate` Middleware

```typescript
router.post('/endpoint', authenticate, validate({ body: myZodSchema }), async (req, res) => {
  // req.body is fully typed and validated here
})
```

### Admin vs Social Auth

- Admin routes: `authenticateAdmin` middleware (checks `tokenFamily: 'admin'`)
- Social routes: `authenticate` middleware (checks `tokenFamily: 'social'`)
- Never mix them — cross-family token rejection is a security requirement

### `audit_log` Cascade Is SET NULL (Not CASCADE)

The `audit_log` table uses `SET NULL` on user FK — history is preserved even when users are deleted. **Do not change this.** It is an intentional design decision for compliance.

### Flutter Theme Class Names

```dart
CardThemeData(...)      // NOT CardTheme(...)
DialogThemeData(...)    // NOT DialogTheme(...)
Color.withValues(alpha: 0.5)  // NOT Color.withOpacity(0.5)
```

### Flutter Dialog Context

When using `showDialog`, always use `dialogContext` from the builder for `Navigator.pop()`. Using the parent `context` pops the wrong route.

```dart
showDialog(
  context: context,
  builder: (dialogContext) => AlertDialog(
    actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), ...)],
  ),
)
```

### GoRouter: Created Once, Not in a Consumer

`GoRouter` must be created once in `initState()`. NOT inside any widget that rebuilds (e.g., `Consumer<AppState>`). Auth re-evaluation is handled automatically by `refreshListenable: appState`.

### JWT Auto-Refresh

`ApiClient.onTokenExpired` must be wired in `AppState` constructor. Access tokens expire in 15 minutes. Without auto-refresh, users get 401 errors after the expiry window.

---

## 6. Process Gates Reference

| Gate | Requirement | Who Validates |
|------|-------------|--------------|
| **A** | Branch + PR URL, commit scope, deviations disclosed | Execution agent declares; Control verifies |
| **B** | Local dev review + GitHub PR review complete; ALL findings dispositioned | Control verifies PR status |
| **C** | Runtime/smoke evidence with environment declared (local / shared-dev / AWS dev) | Execution agent declares; Control verifies |
| **D** | Log entry complete, carry-forward finalized, tracker updated, stakeholder signoff | Control-only |

### Completion Log Location

```
docs/codex/log/track-{X}/{ID}/control-decision.md     ← Control writes this
docs/codex/log/track-{X}/{ID}/completion-report.md    ← Execution agent writes this (if separate)
```

Example: `docs/codex/log/track-A/A0/control-decision.md`

### Finding Your Carry-Forward

Before starting a prompt, check `docs/codex/carry-forward/` for a carry-forward report that patches your prompt. Look for any "A0 Mopup Handoff" or "Winner Handoff" sections at the top of your prompt spec — those supersede anything stated in CLAUDE.md for the area they cover.

### CLAUDE.md Staleness Warning

**CLAUDE.md may be stale.** It is not auto-updated after every prompt. Always prefer:
1. Handoff sections in your specific prompt spec
2. This `EXECUTION_CONTEXT.md` for API ground truth
3. The actual source code in `packages/api/src/routes/` and `packages/database/migrations/`

If you discover CLAUDE.md is wrong about something in your scope, flag it in your completion log under "Unspecced Work / Deviations." The control agent will update CLAUDE.md as part of closeout.

---

## 7. Known Technical Debt (Don't Fix Unless Assigned)

- CI/CD does not auto-run migrations on deploy (manual step required)
- `/health` endpoint does not check DB connectivity
- No rollback migration files (`.down.sql`) exist
- Flutter admin app (`packages/admin-app/`) is deprecated in favor of React admin (`packages/react-admin/`) — do not add new features to Flutter admin
- `venues` table exists for legacy data only — new events use `venue_name`/`venue_address` text fields directly on `events`

---

## Appendix: Track Dependency Map (Quick Reference)

```
X1 (schema consolidation) — must precede: C1, C2, E0

C0 ✅ → C1 → C2 → C3 → C4
A0 ✅ → A1 → A2 → A3
B0    → B1 → B2 → B3
D0    → D1 → D2
E0    → E1 → E2 → E3

B0 depends on: nothing
C1 depends on: C0, X1
C2 depends on: C0, C1, X1
B2 depends on: B1, C1, C2
D0 depends on: C0, C1, A1
E0 depends on: C0, C2, X1
```

Status: C0 ✅ Closed (Claude lane winner) | A0 ✅ Closed (GPT lane winner) | X1 🟡 Unblocked | All others: Not started
