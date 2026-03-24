# [Track-D1] Analytics Pipeline — DuckDB + Influence Scores

**Track:** D (LLM Pipeline + Analytics)
**Sequence:** 2 of 2 in Track D
**Model:** claude-sonnet-4-6
**Alternate Model:** gpt-5.3-codex ← preferred for terminal-first SQL optimization
**A/B Test:** No
**Estimated Effort:** Medium (6-8 hours)
**Dependencies:** C0 (analytics tables created), D0 (moderation data feeds analytics)

## Execution Mode (Required)

- [ ] Stage 1 (required): execute and validate locally first (local Postgres + local API + local admin/mobile against local endpoint).
- [ ] Stage 2 (required for backend/integration-impacting tracks): run shared-dev integration smoke only after local pass.
- [ ] Stage 3 (required before PR merge): run AWS dev deploy/integration smoke for final confidence.
- [ ] Completion log must explicitly record: execution mode used, exact commands run, evidence links, and cleanup actions.


---

## Context

Read these before writing any code:

- `CLAUDE.md` — project reference (database section, analytics tables inventory, architecture decisions)
- `docs/product/master_plan_v2.md` — Section 5.x "Analytics Pipeline" (DuckDB decision, influence scoring algorithm)
- `packages/database/migrations/001_baseline_schema.sql` — analytics tables schema (analytics_connections_daily, analytics_users_daily, analytics_events, analytics_influence)
- `packages/api/src/routes/admin.ts` — where to add manual trigger endpoints
- `packages/api/src/index.ts` — where to register cron jobs
- `packages/api/package.json` — existing dependencies (verify duckdb availability)

---

## Goal

Implement the nightly analytics pipeline using DuckDB (embedded in Node.js) to compute daily user stats, event performance metrics, and network influence scores (PageRank-based). Results populate the `analytics_*` tables in PostgreSQL. The Admin Dashboard reads from these tables to display growth charts, event performance, and community influence rankings.

DuckDB runs as an in-memory compute engine within the Node.js cron job process. It reads historical connection and activity data from PostgreSQL, applies algorithms (PageRank, aggregations), and writes results back to the analytics tables.

---

## Acceptance Criteria

- [ ] DuckDB is installed and initialized in Node.js (`npm install duckdb`)
- [ ] DuckDB attaches to PostgreSQL via the postgres extension (uses same env vars as main API)
- [ ] `packages/api/src/jobs/analytics.ts` exists with two main functions: `computeDailyStats(date)` and `computeInfluenceScores()`
- [ ] Daily stats job upserts correct counts into `analytics_users_daily`, `analytics_connections_daily`, `analytics_events`
- [ ] Influence scores computed for all users with >= `platform_config['analytics.influence.min_connections']` (default 3)
- [ ] Influence score range is 0–100, composite of PageRank (50%), post activity (25%), event attendance (25%)
- [ ] Cron job runs at 2 AM nightly (verified via log output: "Analytics pipeline started at 02:00")
- [ ] Manual trigger endpoint `POST /admin/jobs/analytics` executes pipeline on-demand, returns stats within 30 seconds for 1000 users
- [ ] `GET /admin/analytics/influence` returns ranked list of top 50 users with scores, connection counts, post counts, event counts
- [ ] `GET /admin/analytics/daily` returns 30-day daily stats (new users, connections, events) for charting
- [ ] Platform config `analytics.influence.min_connections` is respected: changing to 5 and re-running removes users with 3–4 connections from rankings
- [ ] DuckDB errors are caught and logged; analytics failure does not crash the API server
- [ ] `llm_usage_log` is NOT used for D1 analytics (no LLM calls — pure computation)
- [ ] All existing API tests still pass; no regressions in routes, auth, or middleware

---

## User Stories

| Actor | Story | Notes |
|-------|-------|-------|
| Platform Admin | As a platform admin, I open the dashboard and see a 30-day user growth chart | Chart populated by `analytics_users_daily` via GET /admin/dashboard |
| Platform Admin | As a platform admin, I see "Top Influencers" showing most connected and active community members | Ranked by influence_score from `analytics_influence` |
| Platform Admin | As a platform admin setting up a new environment, I trigger analytics manually to backfill data | POST /admin/jobs/analytics runs pipeline immediately |
| Event Producer | As an event producer, I see performance stats for my event (attendees, connections made, posts created) | From `analytics_events` per-event record |
| System | As the platform (cron), analytics runs nightly and dashboard reflects current data | CronJob "0 2 * * *" executes `computeDailyStats` + `computeInfluenceScores` |
| System | As the admin API, I query influence and daily stats for admin UI | GET /admin/analytics/influence, GET /admin/analytics/daily return real-time data |

---

## Technical Spec

### 1. DuckDB Setup

**Install and initialization:**

```bash
npm install duckdb
```

**DuckDB instance creation** (in `packages/api/src/jobs/analytics.ts`):

```typescript
import Database from 'duckdb';

const db = new Database(':memory:');  // In-memory database
const conn = db.connect();

// Load PostgreSQL extension
await conn.exec('INSTALL postgres');
await conn.exec('LOAD postgres');

// Attach to PostgreSQL
const pgConnStr = `dbname=${process.env.DB_NAME}
  host=${process.env.DB_HOST}
  user=${process.env.DB_USER}
  password=${process.env.DB_PASSWORD}`;

await conn.exec(`ATTACH '${pgConnStr}' AS pg (TYPE postgres)`);
```

**Connection management:**
- Create connection once per analytics job run
- Use `conn.exec()` for DDL and DML
- Use `conn.query()` for SELECT statements (returns Arrow/Parquet format)
- Close connection after job completes: `conn.close()`
- Wrap in try-catch to prevent API server crash on DuckDB errors

**Environment variables** (same as main API):
- `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD` (required)
- `DB_TIMEZONE` (optional, defaults to UTC)

### 2. `packages/api/src/jobs/analytics.ts` — Main Analytics Job

Create this new file with three exported functions:

#### 2.1 `computeDailyStats(date: string): Promise<void>`

Runs daily aggregations for a given date (format: `YYYY-MM-DD`). Called by cron job with `new Date().toISOString().split('T')[0]`.

**Computes and upserts into `analytics_users_daily`:**

```sql
-- Query via DuckDB
SELECT
  DATE($1) as stat_date,
  COUNT(*) as total_users,
  COUNT(*) FILTER (WHERE created_at::date = $1) as new_users_today,
  COUNT(*) FILTER (WHERE last_active_at::date = $1) as active_today,
  COUNT(*) FILTER (WHERE verification_status = 'verified') as verified_users,
  COUNT(DISTINCT specialties) as unique_specialties,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY post_count) as median_posts_per_user
FROM pg.users
```

Then upsert result into PostgreSQL:

```sql
INSERT INTO analytics_users_daily (stat_date, total_users, new_users_today, active_today, verified_users, unique_specialties, median_posts, computed_at)
VALUES (...)
ON CONFLICT (stat_date) DO UPDATE SET
  total_users = EXCLUDED.total_users,
  new_users_today = EXCLUDED.new_users_today,
  active_today = EXCLUDED.active_today,
  verified_users = EXCLUDED.verified_users,
  unique_specialties = EXCLUDED.unique_specialties,
  median_posts = EXCLUDED.median_posts,
  computed_at = NOW()
```

**Computes and upserts into `analytics_connections_daily`:**

```sql
SELECT
  DATE($1) as stat_date,
  COUNT(*) as total_connections_made,
  COUNT(DISTINCT user_id_1) as unique_users_initiating,
  (SELECT name FROM pg.events WHERE id IN (
    SELECT event_id FROM pg.tickets t
    WHERE DATE(t.created_at) = $1
    GROUP BY t.event_id ORDER BY COUNT(*) DESC LIMIT 1
  )) as peak_event_name
FROM pg.connections
WHERE DATE(created_at) = $1
```

**Computes and upserts into `analytics_events` (for events completed yesterday):**

```sql
SELECT
  e.id as event_id,
  e.name,
  (SELECT COUNT(*) FROM pg.tickets WHERE event_id = e.id AND status = 'checkedIn') +
  (SELECT COUNT(*) FROM pg.posh_orders WHERE event_id = e.id) as total_attendees,
  (SELECT COUNT(*) FROM pg.posh_orders WHERE event_id = e.id) as posh_attendees,
  (SELECT COUNT(*) FROM pg.tickets WHERE event_id = e.id AND status = 'checkedIn') as walkin_attendees,
  (SELECT COUNT(*) FROM pg.connections WHERE event_id = e.id) as connections_made,
  (SELECT COUNT(*) FROM pg.posts WHERE event_id = e.id) as posts_created,
  (SELECT COUNT(DISTINCT specialty_id) FROM pg.users u
   JOIN pg.tickets t ON u.id = t.user_id WHERE t.event_id = e.id) as unique_specialties
FROM pg.events e
WHERE e.status = 'completed' AND DATE(e.end_time) = DATE(NOW()) - INTERVAL '1 day'
```

**Upsert into PostgreSQL `analytics_events`:**

```sql
INSERT INTO analytics_events (event_id, total_attendees, posh_attendees, walkin_attendees, connections_made, posts_created, unique_specialties, computed_at)
VALUES (...)
ON CONFLICT (event_id) DO UPDATE SET ...
```

**Error handling:**
- Wrap in try-catch
- Log error: `logger.error('Daily stats computation failed', { date, error })`
- Do not throw (allow cron to continue)
- Return void (no retry logic in D1)

#### 2.2 `computeInfluenceScores(): Promise<void>`

Computes PageRank-based influence scores for all users. Called nightly after daily stats.

**Algorithm:**

1. Load connections graph from PostgreSQL into DuckDB temp tables
2. Run PageRank (20 iterations, damping factor 0.85)
3. Join with user activity metrics (post_count, event_count)
4. Compute composite score: `(pagerank * 0.5) + (post_activity_percentile * 0.25) + (event_attendance_percentile * 0.25)`
5. Normalize to 0–100 range
6. Filter: only users with `connection_count >= platform_config['analytics.influence.min_connections']`
7. Upsert into `analytics_influence`

**DuckDB SQL for PageRank:**

```sql
-- Create edges table (bidirectional graph)
CREATE TEMP TABLE edges AS
SELECT user_id_1 as src, user_id_2 as dst FROM pg.connections
UNION ALL
SELECT user_id_2 as src, user_id_1 as dst FROM pg.connections;

-- Out-degree per node
CREATE TEMP TABLE out_degree AS
SELECT src, COUNT(*) as degree FROM edges GROUP BY src;

-- Initialize PageRank (all nodes with score 1.0)
CREATE TEMP TABLE nodes AS
SELECT DISTINCT src as node FROM edges;

CREATE TEMP TABLE pr AS
SELECT node, 1.0 / (SELECT COUNT(*) FROM nodes) as score FROM nodes;

-- PageRank iteration (20 rounds)
-- Loop: pr_new = (1-d)/N + d * SUM(pr[neighbor]/out_degree[neighbor])
CREATE TEMP TABLE pr_iteration AS
WITH RECURSIVE iter AS (
  SELECT 1 as round, pr.node, pr.score FROM pr
  UNION ALL
  SELECT
    iter.round + 1,
    pr.node,
    0.15 / (SELECT COUNT(*) FROM nodes) +
    0.85 * COALESCE(SUM(iter.score / COALESCE(od.degree, 1)), 0) as new_score
  FROM iter
  LEFT JOIN edges ON iter.node = edges.dst
  LEFT JOIN pr ON pr.node = edges.src
  LEFT JOIN out_degree od ON pr.node = od.src
  LEFT JOIN pr ON pr.node = iter.node
  WHERE iter.round < 20
  GROUP BY iter.round, pr.node
)
SELECT node, score FROM iter WHERE round = 20;

-- Normalize PageRank to 0-100
CREATE TEMP TABLE pagerank_normalized AS
SELECT
  node as user_id,
  (score - MIN(score) OVER()) / NULLIF(MAX(score) OVER() - MIN(score) OVER(), 0) * 100 as pagerank_score
FROM pr_iteration;

-- User activity metrics
CREATE TEMP TABLE user_activity AS
SELECT
  u.id as user_id,
  COUNT(DISTINCT c.id) as connection_count,
  COUNT(DISTINCT p.id) as post_count,
  COUNT(DISTINCT t.event_id) as event_count
FROM pg.users u
LEFT JOIN pg.connections c ON u.id = c.user_id_1 OR u.id = c.user_id_2
LEFT JOIN pg.posts p ON u.id = p.user_id
LEFT JOIN pg.tickets t ON u.id = t.user_id AND t.status = 'checkedIn'
GROUP BY u.id;

-- Percentile ranks for activity
CREATE TEMP TABLE activity_percentiles AS
SELECT
  user_id,
  connection_count,
  post_count,
  event_count,
  PERCENT_RANK() OVER (ORDER BY post_count) * 100 as post_percentile,
  PERCENT_RANK() OVER (ORDER BY event_count) * 100 as event_percentile
FROM user_activity;

-- Final influence score composition
CREATE TEMP TABLE influence_scores AS
SELECT
  pr.user_id,
  (pr.pagerank_score * 0.5 + ap.post_percentile * 0.25 + ap.event_percentile * 0.25) as influence_score,
  ap.connection_count,
  ap.post_count,
  ap.event_count
FROM pagerank_normalized pr
JOIN activity_percentiles ap ON pr.user_id = ap.user_id
WHERE ap.connection_count >= $1;  -- platform_config min_connections

-- Select and return for upsert
SELECT user_id, influence_score, connection_count, post_count, event_count
FROM influence_scores
ORDER BY influence_score DESC;
```

**Upsert into PostgreSQL:**

```typescript
// Read platform_config value for min_connections
const minConnResult = await apiDb.query(
  `SELECT value FROM platform_config WHERE key = 'analytics.influence.min_connections'`
);
const minConnections = parseInt(minConnResult.rows[0]?.value ?? '3');

// Run DuckDB PageRank query with parameter binding
const influenceRows = await duckDbConn.query(`...`);  // Above SQL

// Upsert into PostgreSQL
for (const row of influenceRows) {
  await apiDb.query(`
    INSERT INTO analytics_influence (user_id, influence_score, connection_count, post_count, event_count, computed_at)
    VALUES ($1, $2, $3, $4, $5, NOW())
    ON CONFLICT (user_id) DO UPDATE SET
      influence_score = EXCLUDED.influence_score,
      connection_count = EXCLUDED.connection_count,
      post_count = EXCLUDED.post_count,
      event_count = EXCLUDED.event_count,
      computed_at = NOW()
  `, [row.user_id, row.influence_score, row.connection_count, row.post_count, row.event_count]);
}
```

**Error handling:**
- Wrap in try-catch
- Log: `logger.error('Influence score computation failed', { error })`
- Do not throw (allow cron to continue)

#### 2.3 Main Pipeline Entry Point

```typescript
export async function runAnalyticsPipeline(): Promise<{
  usersProcessed: number;
  eventsProcessed: number;
  influenceScoresComputed: number;
  duration: number;
}> {
  const startTime = Date.now();

  try {
    logger.info('Analytics pipeline started');

    // Connect to DuckDB
    const db = new Database(':memory:');
    const duckDbConn = db.connect();

    // Attach PostgreSQL
    await duckDbConn.exec('INSTALL postgres');
    await duckDbConn.exec('LOAD postgres');
    const pgConnStr = `dbname=${process.env.DB_NAME} host=${process.env.DB_HOST} user=${process.env.DB_USER} password=${process.env.DB_PASSWORD}`;
    await duckDbConn.exec(`ATTACH '${pgConnStr}' AS pg (TYPE postgres)`);

    // Run daily stats
    const today = new Date().toISOString().split('T')[0];
    await computeDailyStats(duckDbConn, today);

    // Run influence scores
    await computeInfluenceScores(duckDbConn);

    // Close connection
    duckDbConn.close();

    const duration = Date.now() - startTime;
    logger.info('Analytics pipeline completed', { duration });

    return {
      usersProcessed: 0,  // Count from analytics_users_daily
      eventsProcessed: 0,  // Count from analytics_events
      influenceScoresComputed: 0,  // Count from analytics_influence
      duration,
    };
  } catch (err) {
    const duration = Date.now() - startTime;
    logger.error('Analytics pipeline failed', { error: err, duration });
    throw err;
  }
}
```

### 3. Cron Job Registration (`packages/api/src/jobs/index.ts`)

Create this new file:

```typescript
import { CronJob } from 'cron';
import { runAnalyticsPipeline } from './analytics';
import logger from '../utils/logger';

// Analytics: 2 AM nightly (UTC timezone)
new CronJob('0 2 * * *', async () => {
  try {
    logger.info('Analytics cron job triggered');
    await runAnalyticsPipeline();
  } catch (err) {
    logger.error('Analytics cron job failed', { error: err });
    // Do not re-throw; allow scheduler to continue
  }
}, null, true, 'UTC');

logger.info('Cron jobs registered (analytics, etc.)');
```

**Register in `packages/api/src/index.ts`:**

```typescript
// After app setup, before server listen
import './jobs';  // Auto-registers all cron jobs
```

### 4. Manual Trigger Endpoints (add to `packages/api/src/routes/admin.ts`)

**Endpoint: `POST /admin/jobs/analytics`**

```typescript
/**
 * Trigger analytics pipeline immediately (admin only)
 */
router.post('/jobs/analytics', authenticateAdmin, requirePlatformAdmin, async (req, res) => {
  try {
    const result = await runAnalyticsPipeline();
    res.json({
      status: 'success',
      stats: result,
    });
  } catch (err) {
    logger.error('POST /admin/jobs/analytics failed', { error: err });
    res.status(500).json({ error: 'Analytics pipeline failed', details: err.message });
  }
});
```

**Endpoint: `GET /admin/analytics/influence`**

```typescript
/**
 * Get top 50 influence scores (for dashboard display)
 */
router.get('/analytics/influence', authenticateAdmin, async (req, res) => {
  try {
    const limit = Math.min(parseInt(req.query.limit as string) || 50, 500);

    const result = await db.query(`
      SELECT
        ai.user_id,
        u.name,
        u.photo_url,
        ai.influence_score,
        ai.connection_count,
        ai.post_count,
        ai.event_count,
        RANK() OVER (ORDER BY ai.influence_score DESC) as rank
      FROM analytics_influence ai
      JOIN users u ON ai.user_id = u.id
      ORDER BY ai.influence_score DESC
      LIMIT $1
    `, [limit]);

    res.json({
      data: result.rows,
      total: result.rowCount,
    });
  } catch (err) {
    logger.error('GET /admin/analytics/influence failed', { error: err });
    res.status(500).json({ error: 'Failed to fetch influence scores' });
  }
});
```

**Endpoint: `GET /admin/analytics/daily`**

```typescript
/**
 * Get last 30 days of daily stats (for dashboard charts)
 */
router.get('/analytics/daily', authenticateAdmin, async (req, res) => {
  try {
    const days = Math.min(parseInt(req.query.days as string) || 30, 365);

    const result = await db.query(`
      SELECT
        stat_date,
        total_users,
        new_users_today as new_users,
        active_today as active_users,
        verified_users,
        unique_specialties,
        median_posts
      FROM analytics_users_daily
      WHERE stat_date >= NOW() - INTERVAL '1 day' * $1
      ORDER BY stat_date ASC
    `, [days]);

    const connections = await db.query(`
      SELECT
        stat_date,
        total_connections_made,
        unique_users_initiating
      FROM analytics_connections_daily
      WHERE stat_date >= NOW() - INTERVAL '1 day' * $1
      ORDER BY stat_date ASC
    `, [days]);

    res.json({
      users: result.rows,
      connections: connections.rows,
      days,
    });
  } catch (err) {
    logger.error('GET /admin/analytics/daily failed', { error: err });
    res.status(500).json({ error: 'Failed to fetch daily stats' });
  }
});
```

### 5. Extend `GET /admin/dashboard` (in routes/admin.ts)

Add influence top-10 and 30-day trends to the existing dashboard response:

```typescript
// Fetch influence top-10
const influenceResult = await db.query(`
  SELECT
    ai.user_id, u.name, ai.influence_score
  FROM analytics_influence ai
  JOIN users u ON ai.user_id = u.id
  ORDER BY ai.influence_score DESC
  LIMIT 10
`);

// Fetch 30-day trend
const trendResult = await db.query(`
  SELECT stat_date, new_users_today, total_users
  FROM analytics_users_daily
  WHERE stat_date >= NOW() - INTERVAL '30 days'
  ORDER BY stat_date ASC
`);

return {
  ...existingDashboardData,
  influencers: influenceResult.rows,
  userGrowthTrend: trendResult.rows,
};
```

---

## Test Suite

### Unit Tests (`packages/api/src/__tests__/analytics.test.ts`)

Create this new test file:

```typescript
import { Database as DuckDB } from 'duckdb';
import { computeDailyStats, computeInfluenceScores, runAnalyticsPipeline } from '../jobs/analytics';
import { createTestDatabase } from './helpers/testdb';

describe('Analytics Pipeline', () => {
  let testDb: any;
  let duckDb: DuckDB;

  beforeAll(async () => {
    testDb = await createTestDatabase();
    duckDb = new DuckDB(':memory:');
    // Attach test PostgreSQL to DuckDB
  });

  afterAll(async () => {
    await testDb.end();
  });

  describe('computeDailyStats', () => {
    it('upserts user stats for a given date', async () => {
      // Seed test data: 5 users, 1 created today
      // Run computeDailyStats('2026-03-22')
      // Verify analytics_users_daily has row with correct counts
      expect(true).toBe(true);  // Placeholder
    });

    it('upserts connection stats', async () => {
      // Seed: 3 users, 2 connections today
      // Verify analytics_connections_daily row
      expect(true).toBe(true);
    });

    it('upserts event stats for completed events', async () => {
      // Seed: event completed yesterday with 10 attendees, 5 checkins, 3 connections, 2 posts
      // Verify analytics_events row
      expect(true).toBe(true);
    });
  });

  describe('computeInfluenceScores', () => {
    it('computes PageRank-based scores for all users', async () => {
      // Seed: 5-node graph (user connections)
      // Run computeInfluenceScores()
      // Verify all 5 have scores in analytics_influence
      expect(true).toBe(true);
    });

    it('respects platform_config min_connections threshold', async () => {
      // Seed: users with 2, 3, 4 connections (min_connections=3)
      // Verify only 3 and 4 appear in analytics_influence
      expect(true).toBe(true);
    });

    it('normalizes scores to 0-100 range', async () => {
      // Verify all influence_scores between 0 and 100
      expect(true).toBe(true);
    });

    it('weights PageRank (50%), posts (25%), events (25%)', async () => {
      // Verify composite score formula
      expect(true).toBe(true);
    });

    it('excludes users with zero connections', async () => {
      // Seed: 1 user with 0 connections
      // Verify NOT in analytics_influence (or score = 0)
      expect(true).toBe(true);
    });
  });

  describe('Cron Integration', () => {
    it('analytics CronJob is registered at module import', async () => {
      // Import jobs/index.ts
      // Verify CronJob instance exists
      expect(true).toBe(true);
    });

    it('CronJob cron expression is "0 2 * * *" (2 AM daily)', async () => {
      // Verify cron pattern
      expect(true).toBe(true);
    });
  });

  describe('Manual Trigger Endpoints', () => {
    it('POST /admin/jobs/analytics runs pipeline and returns stats', async () => {
      // Mock authenticateAdmin, requirePlatformAdmin
      // POST with valid JWT
      // Verify response: { status, stats: { usersProcessed, duration } }
      expect(true).toBe(true);
    });

    it('GET /admin/analytics/influence returns ranked top-50 list', async () => {
      // Seed analytics_influence with 10 users
      // GET /admin/analytics/influence
      // Verify returns array with userId, name, influenceScore, rank
      expect(true).toBe(true);
    });

    it('GET /admin/analytics/daily returns 30 days of stats', async () => {
      // Seed analytics_users_daily with 30 rows
      // GET /admin/analytics/daily
      // Verify returns users[] and connections[] arrays
      expect(true).toBe(true);
    });
  });

  describe('Error Handling', () => {
    it('DuckDB connection error is caught and logged', async () => {
      // Mock failing DuckDB connection
      // Verify error is logged, promise rejects
      expect(true).toBe(true);
    });

    it('Cron job catches errors without crashing API', async () => {
      // Mock runAnalyticsPipeline to throw
      // Verify cron handler catches it
      expect(true).toBe(true);
    });

    it('manual trigger endpoint returns 500 on pipeline failure', async () => {
      // Mock pipeline failure
      // POST /admin/jobs/analytics
      // Verify response status 500
      expect(true).toBe(true);
    });
  });
});
```

### Integration Tests (existing CI/CD)

Update `api.yml` GitHub Actions workflow to:

```yaml
- name: Run API tests (including analytics)
  run: cd packages/api && npx jest --testPathPattern="analytics.test|health|middleware|customers"
```

### Manual Verification

```bash
# Start port-forward to dev DB
./scripts/pf-db.sh start

# Seed test data (optional — use existing dev database)
# Or reset if starting fresh:
DB_PASSWORD=xxx node scripts/db-reset.js --yes

# Start API server
cd packages/api && npm run dev

# Trigger analytics manually
curl -X POST http://localhost:3000/admin/jobs/analytics \
  -H "Authorization: Bearer <admin-jwt>" \
  -H "Content-Type: application/json"
# Expected response: { status: 'success', stats: { usersProcessed: N, eventsProcessed: M, influenceScoresComputed: P, duration: T } }

# Check daily stats
curl http://localhost:3000/admin/analytics/daily \
  -H "Authorization: Bearer <admin-jwt>"
# Expected: { users: [...], connections: [...], days: 30 }

# Check influence scores
curl http://localhost:3000/admin/analytics/influence \
  -H "Authorization: Bearer <admin-jwt>"
# Expected: { data: [...], total: N }

# Verify cron job runs at 2 AM
# (manually wait or adjust system clock for testing)
tail -f logs/api.log | grep "Analytics pipeline"

# Verify idempotency (run pipeline twice)
curl -X POST http://localhost:3000/admin/jobs/analytics \
  -H "Authorization: Bearer <admin-jwt>"
curl -X POST http://localhost:3000/admin/jobs/analytics \
  -H "Authorization: Bearer <admin-jwt>"
# Both should succeed with same or similar stats

# Verify platform_config respected
psql $DATABASE_URL -c "UPDATE platform_config SET value = '5' WHERE key = 'analytics.influence.min_connections';"
curl -X POST http://localhost:3000/admin/jobs/analytics \
  -H "Authorization: Bearer <admin-jwt>"
curl http://localhost:3000/admin/analytics/influence \
  -H "Authorization: Bearer <admin-jwt>"
# Verify users with 3–4 connections are no longer in top-50 list
```

---

## Definition of Done

- [ ] `packages/api/src/jobs/analytics.ts` implemented with `computeDailyStats()`, `computeInfluenceScores()`, `runAnalyticsPipeline()`
- [ ] `packages/api/src/jobs/index.ts` created with CronJob registration (2 AM daily)
- [ ] DuckDB imported and initialized; PostgreSQL postgres extension loaded and attached
- [ ] Admin endpoints added: `POST /admin/jobs/analytics`, `GET /admin/analytics/influence`, `GET /admin/analytics/daily`
- [ ] Dashboard extended with influence top-10 and 30-day user growth trend
- [ ] All manual verification commands pass
- [ ] Test file `analytics.test.ts` created with placeholder/complete test suites
- [ ] Tests pass: `cd packages/api && npx jest analytics`
- [ ] No regressions in existing tests; all API tests pass
- [ ] Cron job verified running at 2 AM (check logs)
- [ ] Platform config `analytics.influence.min_connections` respected (verification: change to 5, re-run, check rankings)
- [ ] DuckDB errors caught and logged; API server does not crash on analytics failure
- [ ] Code committed to feature branch
- [ ] Completion Report filled in (below)
- [ ] Interrogative Session completed with Jeff

---

## Completion Report

> To be filled in by the executing agent after implementation is complete.

**Branch:** `feature/D1-analytics-pipeline`
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

### Performance notes (if applicable)

- DuckDB query execution time for PageRank with 5000 users: ___ ms
- Influence score computation for daily cron: ___ ms
- Memory usage for in-memory DuckDB: ___ MB

### What the next prompt (D2+) should know

-

---

## Interrogative Session

**Q1: Does DuckDB attach cleanly to PostgreSQL and run PageRank without errors for a 5-user test graph?**
> Jeff:

**Q2: Does the influence score computation correctly weight PageRank/posts/events at 50/25/25, and respect the min_connections threshold?**
> Jeff:

**Q3: Are there any concerns about DuckDB stability in production, or data consistency between PostgreSQL reads and analytics writes (stale read issue)?**
> Jeff:

**Q4: Cron logs show analytics running at 2 AM. Any timezone surprises (UTC vs. user TZ)? Do manual triggers work consistently?**
> Jeff:

**Q5: Does the admin dashboard correctly display the influence rankings and 30-day growth chart after running the pipeline?**
> Jeff:

**Ready for review:** ☐ Yes
