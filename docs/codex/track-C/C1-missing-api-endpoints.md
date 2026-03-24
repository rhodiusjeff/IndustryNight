# [Track-C1] Missing API Endpoints — Unblock Flutter Wiring

**Track:** C (Backend + Schema)
**Sequence:** 2 of 5 in Track C
**Model:** claude-sonnet-4-6
**Alternate Model:** gpt-5.3-codex ← preferred if running inside OpenAI Codex platform; terminal-first workflow (curl, node test runner, jest output parsing) is where GPT-5.3-Codex's Terminal-Bench advantage is most tangible
**A/B Test:** No
**Estimated Effort:** Small–Medium (3–5 hours)
**Dependencies:** C0 (schema migrations must be applied first; `post_reports` table created in this prompt)

## Execution Mode (Required)

- [ ] Stage 1 (required): execute and validate locally first (local Postgres + local API + local admin/mobile against local endpoint).
- [ ] Stage 2 (required for backend/integration-impacting tracks): run shared-dev integration smoke only after local pass.
- [ ] Stage 3 (required before PR merge): run AWS dev deploy/integration smoke for final confidence.
- [ ] Completion log must explicitly record: execution mode used, exact commands run, evidence links, and cleanup actions.


### C0 Winner Handoff (Control Session)

- Winner for C0 execution/apply authority: `claude-sonnet-4-6` (control session decision).
- Source-of-truth migration: `packages/database/migrations/004_phase0_foundation.sql`.
- Assume these C0 outputs exist before implementing C1:
  - `admin_role` includes `platformAdmin`, `moderator`, `eventOps`
  - `user_role` no longer includes `venueStaff`
  - `platform_config` and `llm_usage_log` tables exist
  - `users.fcm_token`, `users.primary_specialty_id`, and `tickets.wristband_issued_at` columns exist
- Do not edit C0 migration in this prompt. Any schema adjustment discovered in C1 must be a new migration file.

---

## Context

Read these before writing any code:

- `CLAUDE.md` — full project reference (API routes section, middleware patterns, services)
- `packages/api/src/routes/` — existing route files (patterns: exports `router`, uses `validate` middleware, parameterized queries)
- `packages/api/src/middleware/` — auth and validation middleware
- `packages/database/migrations/` — understand migration naming and structure from C0
- `packages/shared/lib/models/` — Dart model definitions (for API response shapes)
- `packages/api/src/__tests__/` — existing test patterns (testcontainers setup, supertest pattern)

---

## Goal

Implement all 8 missing API endpoints required by the social app screens and admin features. These endpoints are blocking dependencies for subsequent tracks (A1 check-in flow, B3 moderation pipeline, admin event ops screens). All endpoints must return correct HTTP status codes, validate inputs via Zod, and use parameterized SQL queries.

---

## Acceptance Criteria

- [ ] All 8 endpoints return correct HTTP status codes and JSON response shapes
- [ ] All endpoints validate inputs with Zod schemas (use existing `validate` middleware pattern)
- [ ] All SQL queries use parameterized `$1, $2` syntax — zero string interpolation
- [ ] `POST /events/:id/checkin` returns 400 if code is wrong (not 404 — preserve event existence)
- [ ] `PATCH /users/me/device-token` returns 204 No Content on success
- [ ] `GET /connections?since=ISO8601timestamp` parses and filters by creation time
- [ ] `POST /posts/:id/report` returns 409 if user already reported this post
- [ ] `GET /admin/events/:id/attendees` returns combined tickets + posh_orders with consistent shape
- [ ] `PATCH /admin/events/:id/attendees/:ticketId/wristband` updates wristband_issued_at
- [ ] `GET /admin/posh-exceptions` returns only unmatched posh_orders (user_id IS NULL)
- [ ] `PATCH /admin/posh-exceptions/:orderId/resolve` links order to user
- [ ] `post_reports` migration created as `005_post_reports.sql` in `packages/database/migrations/`
- [ ] All new route files created in `packages/api/src/routes/` (e.g., `checkin.ts`, additions to `admin.ts`)
- [ ] Admin endpoints require `authenticateAdmin` middleware and appropriate role checks
- [ ] Social endpoints require `authenticate` middleware
- [ ] Test suite passes: all 8 endpoints covered in Jest (testcontainers pattern)
- [ ] Migration applied cleanly and is idempotent

---

## User Stories

| Actor | Story | Notes |
|-------|-------|-------|
| Social user at event | As a user checking into an event, I tap "Enter Activation Code", type the code shown by venue staff, and get a confirmation screen with the ticket ID and check-in time | Requires `POST /events/:id/checkin` endpoint with activation_code validation |
| Social user | As a user, I want my FCM push token registered automatically (on every app launch) so that I can receive real-time notifications | Requires `PATCH /users/me/device-token` endpoint; 204 response means fire-and-forget |
| Social user (QR connect) | As a user in the connect tab, I want to see new connections appear in real time. The app polls `GET /connections?since=` every 4 seconds to detect when someone scanned my QR code | Requires `GET /connections?since=` endpoint with timestamp filtering |
| Social user (moderation) | As a user, I can report a post that violates community guidelines by clicking "Report" and selecting a reason | Requires `POST /posts/:id/report` endpoint and `post_reports` table |
| Event Ops staff | As an eventOps admin, I see a real-time list of checked-in attendees for an event, sorted by most recent | Requires `GET /admin/events/:id/attendees` endpoint with combined tickets + posh_orders |
| Event Ops staff | As eventOps, I scan an attendee's wristband confirmation QR, find them in the check-in list, and tap "Issued" to confirm the wristband was given | Requires `PATCH /admin/events/:id/attendees/:ticketId/wristband` endpoint |
| Platform Admin | As a platform admin, I see a list of Posh orders that didn't auto-match to a user account (e.g., buyer name didn't match any user) | Requires `GET /admin/posh-exceptions` endpoint |
| Platform Admin | As a platform admin, I can manually link a Posh order to a user account if the auto-match failed | Requires `PATCH /admin/posh-exceptions/:orderId/resolve` endpoint |
| Moderation system (D0) | As the moderation pipeline (LLM + human review), I want to read reported posts from `post_reports` table to route them to the review queue | Requires `post_reports` table and `POST /posts/:id/report` endpoint |

---

## Technical Spec

### 1. POST /events/:id/checkin

**Route:** `packages/api/src/routes/checkin.ts` (new file)

**Auth:** `authenticate` middleware (social user)

**Body schema:**
```typescript
const checkInSchema = z.object({
  activationCode: z.string().min(1).max(20),
});
```

**Logic:**
- Find event by `:id` and load `activation_code` field
- Compare request body `activationCode` with event's `activation_code` (case-insensitive)
- If no match: return 400 with message "Invalid activation code"
- If match:
  - Check if ticket exists for this user + event: `SELECT id FROM tickets WHERE event_id = $1 AND user_id = $2`
  - If exists: update `checked_in_at = NOW()` where `checked_in_at IS NULL`, return 400 if already checked in with message "Already checked in"
  - If not exists: insert new ticket row: `INSERT INTO tickets (id, event_id, user_id, status, created_at, checked_in_at) VALUES (gen_random_uuid(), $1, $2, 'checkedIn', NOW(), NOW())`
- Return 200 with response shape: `{ ticketId: string, checkedInAt: ISO8601, eventName: string }`

**Errors:**
- 401: unauthenticated
- 404: event not found (event must be published)
- 400: activation code invalid OR already checked in

**Notes:**
- `activation_code` is a plain text field on `events` table (generated by admin when creating event)
- This endpoint is public-facing on the published event, but requires social user authentication
- Tickets table has schema: `id UUID, event_id UUID, user_id UUID, status ticket_status, created_at, checked_in_at, updated_at`

---

### 2. PATCH /users/me/device-token

**Route:** `packages/api/src/routes/users.ts` (add to existing file)

**Auth:** `authenticate` middleware

**Body schema:**
```typescript
const deviceTokenSchema = z.object({
  token: z.string().min(10).max(1000),
});
```

**Logic:**
- Extract user ID from `req.user.userId` (set by `authenticate` middleware)
- Update: `UPDATE users SET fcm_token = $1 WHERE id = $2`
- Return 204 No Content (no body)

**Errors:**
- 401: unauthenticated
- 400: token field missing or invalid

**Notes:**
- No response body needed; 204 is standard for "fire and forget" operations
- Called on every app launch to keep FCM token fresh
- `users.fcm_token` exists from C0 migration

---

### 3. GET /connections

**Route:** `packages/api/src/routes/connections.ts` (existing file — verify or enhance)

**Auth:** `authenticate` middleware

**Query params:**
```typescript
const connectionsQuerySchema = z.object({
  since: z.string().datetime().optional(),
});
```

**Logic:**
- Extract user ID from `req.user.userId`
- If `since` query param provided:
  - Parse ISO8601 timestamp: `const sinceTime = new Date(req.query.since as string)`
  - Query: `SELECT c.*, u.name, u.photo_url, u.specialties FROM connections c JOIN users u ON (u.id = c.user_id OR u.id = c.connected_user_id) WHERE (c.user_id = $1 OR c.connected_user_id = $1) AND c.created_at > $2 ORDER BY c.created_at DESC`
  - Note: connection query logic must return the "other" user in the connection, not the current user
- If no `since`: return all connections ordered by created_at DESC
- Return 200 with array: `{ id, userId, connectedUserId, otherUser: { id, name, photoUrl, specialties }, connectedAt }`

**Errors:**
- 401: unauthenticated
- 400: `since` param is not a valid ISO8601 timestamp

**Notes:**
- The `connect_tab_screen` calls this every 4 seconds with `?since=` (the timestamp from the last check) to detect new connections (QR scan → mutual connection created)
- Two users already in `connections` table do NOT appear twice; the row has both `user_id` and `connected_user_id`, and it's shared
- Returning the "other user's" profile info (not the current user's) is critical for the UX (current user wants to see who connected with them)

---

### 4. POST /posts/:id/report

**Route:** `packages/api/src/routes/posts.ts` (add to existing file)

**Auth:** `authenticate` middleware

**Body schema:**
```typescript
const postReportSchema = z.object({
  reason: z.string().min(1).max(500),
});
```

**Logic:**
- Extract user ID from `req.user.userId`
- Check if user already reported this post: `SELECT id FROM post_reports WHERE post_id = $1 AND reported_by = $2`
- If exists: return 409 with message "You have already reported this post"
- If not: insert: `INSERT INTO post_reports (id, post_id, reported_by, reason, created_at) VALUES (gen_random_uuid(), $1, $2, $3, NOW())`
- Return 201 with response: `{ id, postId, reportedAt }`

**Errors:**
- 401: unauthenticated
- 404: post not found
- 409: duplicate report (same user reported same post before)
- 400: reason field missing or invalid

**Notes:**
- `post_reports` table created in migration `005_post_reports.sql` (see below)
- Moderation system (Track D0) will read from this table and process reports

---

### 5. Migration: 005_post_reports.sql

**Location:** `packages/database/migrations/005_post_reports.sql`

**Schema:**
```sql
-- 005_post_reports.sql
-- Post reporting and moderation tracking

BEGIN;

-- post_reports: Track user reports on community posts
CREATE TABLE IF NOT EXISTS post_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  reported_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reason TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  reviewed_at TIMESTAMPTZ,
  reviewer_id UUID REFERENCES admin_users(id) ON DELETE SET NULL,
  resolution TEXT,
  CONSTRAINT unique_report_per_user UNIQUE (post_id, reported_by)
);

CREATE INDEX IF NOT EXISTS idx_post_reports_created_at ON post_reports(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_post_reports_reviewed_at ON post_reports(reviewed_at DESC) WHERE reviewed_at IS NULL;

COMMIT;
```

**Notes:**
- Unique constraint prevents duplicate reports from same user on same post
- `reviewed_at` and `reviewer_id` are populated by the moderation system (D0 track)
- `resolution` is a free-text field for the reviewer to note action taken

---

### 6. GET /admin/events/:id/attendees

**Route:** `packages/api/src/routes/admin.ts` (add to existing file)

**Auth:** `authenticateAdmin` + role check (eventOps or platformAdmin can access)

**Query params:**
```typescript
const attendeesQuerySchema = z.object({
  status: z.enum(['checkedIn', 'all']).default('checkedIn'),
});
```

**Logic:**
- Extract event ID from `:id`
- If `status=checkedIn`: filter to rows where `checked_in_at IS NOT NULL`
- If `status=all`: return all attendee records
- Query tickets + posh_orders:
  ```sql
  (SELECT
    t.id as ticket_id,
    t.user_id,
    u.name,
    u.photo_url,
    t.checked_in_at,
    NULL::UUID as posh_order_id,
    t.wristband_issued_at,
    'ticket' as source,
    t.created_at
  FROM tickets t
  LEFT JOIN users u ON u.id = t.user_id
  WHERE t.event_id = $1)
  UNION ALL
  (SELECT
    NULL::UUID as ticket_id,
    po.user_id,
    u.name,
    u.photo_url,
    po.checked_in_at,
    po.id as posh_order_id,
    po.wristband_issued_at,
    'posh' as source,
    po.created_at
  FROM posh_orders po
  LEFT JOIN users u ON u.id = po.user_id
  WHERE po.event_id = $1 AND po.checked_in_at IS NOT NULL)
  ORDER BY checked_in_at DESC
  ```
- If `status=checkedIn`: add `WHERE checked_in_at IS NOT NULL` before ORDER BY
- Return 200 with array: `{ ticketId, userId, name, photoUrl, checkedInAt, poshOrderId, wristbandIssuedAt, source: 'ticket'|'posh' }`

**Errors:**
- 401: unauthenticated
- 403: insufficient role (not eventOps or platformAdmin)
- 404: event not found

**Notes:**
- Both `tickets` and `posh_orders` have `wristband_issued_at` fields (added in C0 migration)
- `posh_orders.user_id` can be NULL (for unmatched Posh buyers); return NULL for those rows
- Sorted by most recent check-in first (DESC)

---

### 7. PATCH /admin/events/:id/attendees/:ticketId/wristband

**Route:** `packages/api/src/routes/admin.ts` (add to existing file)

**Auth:** `authenticateAdmin` + role check (eventOps or platformAdmin)

**Logic:**
- Extract event ID from `:id` and ticket ID from `:ticketId`
- Verify ticket belongs to event: `SELECT * FROM tickets WHERE id = $1 AND event_id = $2`
- If not found: return 404
- Update: `UPDATE tickets SET wristband_issued_at = NOW() WHERE id = $1 RETURNING *`
- Return 200 with updated ticket: `{ ticketId, userId, eventId, status, checkedInAt, wristbandIssuedAt, createdAt, updatedAt }`

**Errors:**
- 401: unauthenticated
- 403: insufficient role
- 404: ticket or event not found

**Notes:**
- Simple one-way update; once marked as issued, cannot be unmarked
- Idempotent: setting `wristband_issued_at` multiple times is a no-op

---

### 8. GET /admin/posh-exceptions

**Route:** `packages/api/src/routes/admin.ts` (add to existing file)

**Auth:** `authenticateAdmin` + `requirePlatformAdmin` (platform admins only)

**Query params:**
```typescript
const poshExceptionsQuerySchema = z.object({
  eventId: z.string().uuid().optional(),
});
```

**Logic:**
- Query unmatched posh_orders:
  ```sql
  SELECT
    po.*,
    e.name as event_name
  FROM posh_orders po
  LEFT JOIN events e ON e.id = po.event_id
  WHERE po.user_id IS NULL
  ORDER BY po.created_at DESC
  ```
- If `eventId` param provided: add `AND po.event_id = $1`
- Return 200 with array of orders

**Errors:**
- 401: unauthenticated
- 403: insufficient role (must be platformAdmin)

**Notes:**
- Shows Posh orders that didn't auto-match to a user account (no phone/email match found in users table)
- Used for manual reconciliation workflow

---

### 9. PATCH /admin/posh-exceptions/:orderId/resolve

**Route:** `packages/api/src/routes/admin.ts` (add to existing file)

**Auth:** `authenticateAdmin` + `requirePlatformAdmin`

**Body schema:**
```typescript
const resolvePoshExceptionSchema = z.object({
  userId: z.string().uuid(),
});
```

**Logic:**
- Extract order ID from `:orderId`
- Verify order exists and `user_id IS NULL`: `SELECT * FROM posh_orders WHERE id = $1 AND user_id IS NULL`
- If not found or already matched: return 404 with message "Order not found or already resolved"
- Verify user exists: `SELECT id FROM users WHERE id = $1`
- If not found: return 400 with message "User not found"
- Update: `UPDATE posh_orders SET user_id = $1 WHERE id = $2 RETURNING *`
- Return 200 with updated order

**Errors:**
- 401: unauthenticated
- 403: insufficient role
- 404: order not found or already resolved
- 400: user not found

**Notes:**
- One-way operation: once linked, cannot be unlinked (delete operation would be separate)

---

## Route File Organization

**New files:**
- `packages/api/src/routes/checkin.ts` — exports `router` for `POST /events/:id/checkin`

**Enhanced files:**
- `packages/api/src/routes/users.ts` — add `PATCH /users/me/device-token` (register FCM token)
- `packages/api/src/routes/posts.ts` — add `POST /posts/:id/report` (report post)
- `packages/api/src/routes/admin.ts` — add all 4 admin endpoints (attendees list, wristband mark, posh exceptions list, resolve exception)

**Main entry point:**
- `packages/api/src/index.ts` — mount `checkin` router at `/events` (or similar; align with existing pattern)

---

## Implementation Patterns

### Parameterized queries (required)
```typescript
// GOOD
const result = await db.query('SELECT * FROM events WHERE id = $1', [eventId]);

// BAD — string interpolation
const result = await db.query(`SELECT * FROM events WHERE id = ${eventId}`);
```

### Zod validation
```typescript
// Apply validation middleware to route handler
router.post('/:id/checkin', validate({ body: checkInSchema }), async (req, res) => {
  // req.body is now validated and typed
  const { activationCode } = req.body;
  // ...
});
```

### Error responses
```typescript
// 404
res.status(404).json({ error: 'Event not found' });

// 400
res.status(400).json({ error: 'Invalid activation code' });

// 409 (conflict)
res.status(409).json({ error: 'You have already reported this post' });

// 204 No Content
res.status(204).send();
```

---

## Test Suite

### Manual Verification (run after implementation)

```bash
# Start port-forward to dev DB and run API server
./scripts/pf-db.sh start
cd packages/api && npm run dev

# In another terminal:

# Test POST /events/:id/checkin
curl -X POST http://localhost:3000/events/[eventId]/checkin \
  -H "Authorization: Bearer [socialToken]" \
  -H "Content-Type: application/json" \
  -d '{"activationCode":"ABC123"}'

# Test PATCH /users/me/device-token
curl -X PATCH http://localhost:3000/users/me/device-token \
  -H "Authorization: Bearer [socialToken]" \
  -H "Content-Type: application/json" \
  -d '{"token":"fcm_device_token_xyz"}'

# Test GET /connections?since=
curl http://localhost:3000/connections?since=2026-03-22T10:00:00Z \
  -H "Authorization: Bearer [socialToken]"

# Test POST /posts/:id/report
curl -X POST http://localhost:3000/posts/[postId]/report \
  -H "Authorization: Bearer [socialToken]" \
  -H "Content-Type: application/json" \
  -d '{"reason":"Offensive content"}'

# Test GET /admin/events/:id/attendees
curl http://localhost:3000/admin/events/[eventId]/attendees \
  -H "Authorization: Bearer [adminToken]"

# Test PATCH /admin/posh-exceptions/:orderId/resolve
curl -X PATCH http://localhost:3000/admin/posh-exceptions/[orderId]/resolve \
  -H "Authorization: Bearer [adminToken]" \
  -H "Content-Type: application/json" \
  -d '{"userId":"[userId]"}'
```

### Automated Tests (add to `packages/api/src/__tests__/`)

**Create `checkin.test.ts`:**
```typescript
describe('POST /events/:id/checkin', () => {
  it('returns 200 with ticket on valid activation code', async () => {
    const event = /* create test event with activation_code */;
    const user = /* create test user and get token */;

    const res = await request(app)
      .post(`/events/${event.id}/checkin`)
      .set('Authorization', `Bearer ${token}`)
      .send({ activationCode: event.activation_code });

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('ticketId');
    expect(res.body).toHaveProperty('checkedInAt');
  });

  it('returns 400 on invalid activation code', async () => {
    const res = await request(app)
      .post(`/events/${event.id}/checkin`)
      .set('Authorization', `Bearer ${token}`)
      .send({ activationCode: 'WRONG' });

    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/invalid/i);
  });

  it('returns 400 if already checked in', async () => {
    // First check-in succeeds
    // Second check-in with same user returns 400
  });

  it('returns 401 if unauthenticated', async () => {
    const res = await request(app)
      .post(`/events/${event.id}/checkin`)
      .send({ activationCode: 'ABC' });
    expect(res.status).toBe(401);
  });
});
```

**Create `device-token.test.ts`:**
```typescript
describe('PATCH /users/me/device-token', () => {
  it('returns 204 on valid token', async () => {
    const res = await request(app)
      .patch('/users/me/device-token')
      .set('Authorization', `Bearer ${token}`)
      .send({ token: 'fcm_device_token_abc123' });

    expect(res.status).toBe(204);
  });

  it('updates users.fcm_token in database', async () => {
    await request(app)
      .patch('/users/me/device-token')
      .set('Authorization', `Bearer ${token}`)
      .send({ token: 'new_token' });

    const updatedUser = await db.query('SELECT fcm_token FROM users WHERE id = $1', [userId]);
    expect(updatedUser.rows[0].fcm_token).toBe('new_token');
  });

  it('returns 400 if token field missing', async () => {
    const res = await request(app)
      .patch('/users/me/device-token')
      .set('Authorization', `Bearer ${token}`)
      .send({});
    expect(res.status).toBe(400);
  });

  it('returns 401 if unauthenticated', async () => {
    const res = await request(app)
      .patch('/users/me/device-token')
      .send({ token: 'abc' });
    expect(res.status).toBe(401);
  });
});
```

**Create `connections.test.ts` (add to existing if present):**
```typescript
describe('GET /connections', () => {
  it('returns all connections for authenticated user', async () => {
    const res = await request(app)
      .get('/connections')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });

  it('filters by since timestamp', async () => {
    const before = new Date(Date.now() - 1000000).toISOString();
    const res = await request(app)
      .get(`/connections?since=${before}`)
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    // All returned connections should have createdAt > before
    res.body.forEach(c => {
      expect(new Date(c.connectedAt) > new Date(before)).toBe(true);
    });
  });

  it('returns 400 on invalid ISO timestamp', async () => {
    const res = await request(app)
      .get('/connections?since=not-a-date')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(400);
  });

  it('returns 401 if unauthenticated', async () => {
    const res = await request(app).get('/connections');
    expect(res.status).toBe(401);
  });
});
```

**Create `post-reports.test.ts`:**
```typescript
describe('POST /posts/:id/report', () => {
  it('returns 201 on first report', async () => {
    const res = await request(app)
      .post(`/posts/${post.id}/report`)
      .set('Authorization', `Bearer ${token}`)
      .send({ reason: 'Offensive content' });

    expect(res.status).toBe(201);
    expect(res.body).toHaveProperty('id');
    expect(res.body).toHaveProperty('postId', post.id);
  });

  it('returns 409 on duplicate report from same user', async () => {
    // First report succeeds
    await request(app)
      .post(`/posts/${post.id}/report`)
      .set('Authorization', `Bearer ${token}`)
      .send({ reason: 'Offensive' });

    // Second report fails
    const res = await request(app)
      .post(`/posts/${post.id}/report`)
      .set('Authorization', `Bearer ${token}`)
      .send({ reason: 'Still offensive' });

    expect(res.status).toBe(409);
  });

  it('returns 400 on invalid reason', async () => {
    const res = await request(app)
      .post(`/posts/${post.id}/report`)
      .set('Authorization', `Bearer ${token}`)
      .send({ reason: '' });
    expect(res.status).toBe(400);
  });

  it('returns 401 if unauthenticated', async () => {
    const res = await request(app)
      .post(`/posts/${post.id}/report`)
      .send({ reason: 'Test' });
    expect(res.status).toBe(401);
  });
});
```

**Create `admin-attendees.test.ts`:**
```typescript
describe('GET /admin/events/:id/attendees', () => {
  it('returns combined tickets and posh_orders for event', async () => {
    const res = await request(app)
      .get(`/admin/events/${event.id}/attendees`)
      .set('Authorization', `Bearer ${adminToken}`);

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    res.body.forEach(a => {
      expect(['ticket', 'posh']).toContain(a.source);
    });
  });

  it('filters by status=checkedIn', async () => {
    const res = await request(app)
      .get(`/admin/events/${event.id}/attendees?status=checkedIn`)
      .set('Authorization', `Bearer ${adminToken}`);

    res.body.forEach(a => {
      expect(a.checkedInAt).not.toBeNull();
    });
  });

  it('returns 404 if event not found', async () => {
    const res = await request(app)
      .get('/admin/events/invalid-id/attendees')
      .set('Authorization', `Bearer ${adminToken}`);
    expect(res.status).toBe(404);
  });
});

describe('PATCH /admin/events/:id/attendees/:ticketId/wristband', () => {
  it('updates wristband_issued_at on valid ticket', async () => {
    const res = await request(app)
      .patch(`/admin/events/${event.id}/attendees/${ticket.id}/wristband`)
      .set('Authorization', `Bearer ${adminToken}`);

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('wristbandIssuedAt');
    expect(res.body.wristbandIssuedAt).not.toBeNull();
  });

  it('returns 404 if ticket not found', async () => {
    const res = await request(app)
      .patch(`/admin/events/${event.id}/attendees/invalid-id/wristband`)
      .set('Authorization', `Bearer ${adminToken}`);
    expect(res.status).toBe(404);
  });
});
```

**Create `posh-exceptions.test.ts`:**
```typescript
describe('GET /admin/posh-exceptions', () => {
  it('returns only unmatched posh_orders', async () => {
    const res = await request(app)
      .get('/admin/posh-exceptions')
      .set('Authorization', `Bearer ${adminToken}`);

    expect(res.status).toBe(200);
    res.body.forEach(order => {
      expect(order.userId).toBeNull();
    });
  });

  it('filters by eventId param', async () => {
    const res = await request(app)
      .get(`/admin/posh-exceptions?eventId=${event.id}`)
      .set('Authorization', `Bearer ${adminToken}`);

    res.body.forEach(order => {
      expect(order.eventId).toBe(event.id);
    });
  });

  it('returns 403 if not platformAdmin', async () => {
    const res = await request(app)
      .get('/admin/posh-exceptions')
      .set('Authorization', `Bearer ${eventOpsToken}`); // eventOps, not platformAdmin
    expect(res.status).toBe(403);
  });
});

describe('PATCH /admin/posh-exceptions/:orderId/resolve', () => {
  it('links posh_order to user on valid request', async () => {
    const res = await request(app)
      .patch(`/admin/posh-exceptions/${order.id}/resolve`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ userId: user.id });

    expect(res.status).toBe(200);
    expect(res.body.userId).toBe(user.id);
  });

  it('returns 404 if order already resolved', async () => {
    // First resolve succeeds, second fails
    await request(app)
      .patch(`/admin/posh-exceptions/${order.id}/resolve`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ userId: user.id });

    const res = await request(app)
      .patch(`/admin/posh-exceptions/${order.id}/resolve`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ userId: otherUser.id });

    expect(res.status).toBe(404);
  });

  it('returns 400 if user not found', async () => {
    const res = await request(app)
      .patch(`/admin/posh-exceptions/${order.id}/resolve`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ userId: 'invalid-user-id' });
    expect(res.status).toBe(400);
  });
});
```

### CI/CD Integration

These tests will run automatically in `api.yml` via `npx jest`. The testcontainers PostgreSQL setup will apply all migrations (including `005_post_reports.sql`) before tests run.

---

## Definition of Done

- [ ] `packages/database/migrations/005_post_reports.sql` committed
- [ ] Migration applied successfully to dev DB: `DB_PASSWORD=xxx node scripts/migrate.js`
- [ ] All 8 endpoints implemented in `packages/api/src/routes/`
- [ ] All Zod schemas defined and validation middleware applied
- [ ] All SQL queries use parameterized syntax (`$1, $2`, etc.)
- [ ] All test files created and tests pass: `cd packages/api && npx jest`
- [ ] No breaking changes to existing endpoints
- [ ] Completion Report filled in (below)
- [ ] Interrogative Session completed

---

## Completion Report

> To be filled in by the executing agent after implementation is complete.

**Branch:** `feature/C1-missing-api-endpoints`
**Model used:** —
**Date completed:** —

### What I implemented exactly as specced
-

### What I deviated from the spec and why
-

### What I deferred or left incomplete
-

### Technical debt introduced
-

### What the next prompt in this track (C2) should know
-

---

## Interrogative Session

**Q1: Do all 8 endpoints pass their test suites and return correct status codes for all error paths?**
> Jeff:

**Q2: Does the migration `005_post_reports.sql` apply cleanly and idempotently, and does the unique constraint on (post_id, reported_by) work as expected?**
> Jeff:

**Q3: Are there any ambiguities in the endpoint specs that would cause confusion during Flutter wiring in Track A or B?**
> Jeff:

**Ready for review:** ☐ Yes
