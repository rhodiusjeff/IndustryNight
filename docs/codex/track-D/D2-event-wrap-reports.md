# [Track-D2] Event Wrap Reports — Automated Post-Event Summaries

**Track:** D (LLM Pipeline + Analytics)
**Sequence:** 3 of 3 in Track D
**Model:** claude-sonnet-4-6
**Alternate Model:** gpt-5.4 ← preferred for longer-context generation and structured output parsing
**A/B Test:** No
**Estimated Effort:** Medium (6–8 hours)
**Dependencies:** D0 (moderation data), D1 (analytics data), C0 (schema foundation)

## Execution Mode (Required)

- [ ] Stage 1 (required): execute and validate locally first (local Postgres + local API + local admin/mobile against local endpoint).
- [ ] Stage 2 (required for backend/integration-impacting tracks): run shared-dev integration smoke only after local pass.
- [ ] Stage 3 (required before PR merge): run AWS dev deploy/integration smoke for final confidence.
- [ ] Completion log must explicitly record: execution mode used, exact commands run, evidence links, and cleanup actions.


---

## Context

Read these before writing any code:

- `CLAUDE.md` — full project reference (database, API routes, Admin app routes, state management)
- `docs/product/requirements.md` — Section 4.2 "Event Wrap Reports" (product vision)
- `packages/database/migrations/001_baseline_schema.sql` — current baseline schema
- `packages/database/migrations/NNN_event_reports.sql` — use the next sequential migration number when implementing (provided below)
- `packages/api/src/services/` — existing services (auth, email, storage, posh)
- `packages/api/src/routes/admin.ts` — admin endpoints pattern
- `packages/api/src/__tests__/` — existing test patterns (customers.test.ts for reference)
- Track D0 prompt (`docs/codex/track-D/D0-moderation-pipeline.md`) — moderation service usage
- Track D1 prompt (`docs/codex/track-D/D1-analytics-pipeline.md`) — analytics service usage

---

## Goal

Automatically generate post-event wrap reports using Claude Sonnet 24 hours after an event completes. Reports summarize attendance and engagement stats, top community content, network connection patterns, sponsor/partner performance, and a qualitative narrative. Reports are persisted in a new `event_reports` table and accessible to platformAdmins via API. Establish the foundation for a future commercial product: customer-facing exports (PDF, branded with sponsor performance data).

---

## Acceptance Criteria

- [ ] Migration file exists at `packages/database/migrations/NNN_event_reports.sql` (next sequential number)
- [ ] `event_reports` table created with all required columns (see schema below)
- [ ] `generateEventWrapReport(eventId: string)` service function exists at `packages/api/src/services/event-wrap.ts`
- [ ] Function calls Claude Sonnet with structured prompt; parses JSON response into all report sections
- [ ] All report sections (`headline`, `narrative`, `top_moments`, `network_highlights`, `sponsor_summary`, `recommendations`, `full_report_markdown`) are populated
- [ ] `llm_usage_log` entry created for each report generation with feature = 'event_wrap_report'
- [ ] Cron job runs every hour; generates reports for events 24+ hours completed and without a complete report (max 3 per hour)
- [ ] Manual trigger: `POST /admin/events/:id/generate-report` returns 202 Accepted; report generated within 60 seconds
- [ ] `GET /admin/events/:id/report` returns full event_reports row with all sections (404 if not yet generated)
- [ ] `GET /admin/events/:id/report/markdown` returns raw markdown (text/markdown content type) for copy/paste or PDF export
- [ ] `DELETE /admin/events/:id/report` deletes report; next cron tick or manual trigger regenerates
- [ ] Rate limiting: max 3 reports generated per hour via cron (queued beyond limit); manual trigger not rate-limited
- [ ] Report generates gracefully for events with zero attendance, posts, or connections (notes engagement level in narrative)
- [ ] If Sonnet call fails: status set to 'failed', error_message populated, retry on next cron tick
- [ ] Platform config respected: `llm.event_wrap.model` controls which model is used (default: claude-sonnet-4-6)
- [ ] No report generated for events with status != 'completed'
- [ ] Migration is idempotent (safe to re-run)
- [ ] All existing data preserved; zero rows deleted or corrupted

---

## User Stories

| Actor | Story | Notes |
|-------|-------|-------|
| Platform Admin | As a platformAdmin, I receive an auto-generated wrap report 24 hours after an event completes, showing attendance, connections formed, top content, and sponsor performance | Report appears without admin action |
| Platform Admin | As a platformAdmin, I can view the event wrap report in the admin app, reading narrative sections and checking engagement stats | Future B3 integration shows report in event detail screen |
| Platform Admin | As a platformAdmin, I can export the wrap report as markdown to paste into a stakeholder email or Slack message | No additional tooling needed for v1 |
| Platform Admin | As a platformAdmin, I can manually trigger report generation via the API if auto-generation fails or I want to regenerate | `POST /admin/events/:id/generate-report` |
| Event Operator | As an eventOps admin user, I want the wrap report to highlight sponsor engagement (redemption rates, estimated reach) so I can measure partner ROI | Populated in sponsor_summary section |
| Sponsor (future) | As a sponsor/customer, I want a branded, customer-facing event report showing my perks' performance and estimated audience engagement so I can measure ROI of my sponsorship | Future phase — data structure reserved in D2 |
| System | As the LLM pipeline, I want visibility into event wrap report generation costs and performance through `llm_usage_log` | feature = 'event_wrap_report' |

---

## Technical Spec

### 1. Database Migration: `NNN_event_reports.sql`

Create migration file at `packages/database/migrations/NNN_event_reports.sql` (replace `NNN` with the next sequential migration number):

```sql
-- NNN_event_reports.sql
-- Event wrap reports: automated Sonnet-generated summaries of completed events
-- Stores stats, narrative sections, and full markdown for admin viewing and export

BEGIN;

-- event_reports: Sonnet-generated wrap reports per event
CREATE TABLE event_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID REFERENCES events(id) ON DELETE CASCADE,
  UNIQUE(event_id),

  -- Generation metadata
  generated_at TIMESTAMPTZ DEFAULT NOW(),
  model VARCHAR(100) NOT NULL,
  tokens_used INTEGER,
  latency_ms INTEGER,

  -- Structured stats (machine-readable, JSONB)
  -- { totalAttendees, poshAttendees, walkIns, checkedIn, uniqueSpecialties,
  --   connectionsFormed, postsCreated, totalLikes, totalComments, avgConnectionsPerAttendee }
  stats JSONB NOT NULL DEFAULT '{}',

  -- Generated narrative sections (Sonnet output)
  headline VARCHAR(500),              -- One-line event summary (max 100 words, ~500 chars)
  narrative TEXT,                     -- 2-3 paragraph overview
  top_moments TEXT,                   -- 3-5 specific highlights from the event
  network_highlights TEXT,            -- Connection patterns, notable clusters
  sponsor_summary TEXT,               -- Sponsor/partner performance summary
  recommendations TEXT,               -- 2-3 suggestions for next event

  -- Full report as markdown (all sections combined)
  full_report_markdown TEXT,

  -- Status tracking
  status VARCHAR(20) DEFAULT 'pending',  -- pending, generating, complete, failed
  error_message TEXT,

  -- Audit
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for cron query (find pending/failed reports for completed events)
CREATE INDEX IF NOT EXISTS idx_event_reports_status_created ON event_reports(status, created_at);

-- Index for lookups by event_id
CREATE INDEX IF NOT EXISTS idx_event_reports_event_id ON event_reports(event_id);

COMMIT;
```

---

### 2. Service: `packages/api/src/services/event-wrap.ts`

Create new service file:

```typescript
// packages/api/src/services/event-wrap.ts
// Event wrap report generation: Sonnet-based event summary

import { Client } from 'pg';
import Anthropic from '@anthropic-ai/sdk';
import { logger } from '../utils/logger';
import { logLlmUsage } from './llm-usage';

interface EventContext {
  event: {
    id: string;
    name: string;
    venueName: string;
    venueAddress: string;
    startTime: string;
    endTime: string;
    duration: string; // human-readable, e.g. "3 hours"
  };
  attendance: {
    totalAttendees: number;
    poshAttendees: number;
    walkIns: number;
    checkedIn: number;
  };
  network: {
    connectionsFormed: number;
    uniqueSpecialties: number;
    topConnectors: Array<{
      name: string;
      specialty: string;
      connectionCount: number;
    }>;
  };
  content: {
    postsCreated: number;
    topPosts: Array<{
      author: string;
      text: string;
      likeCount: number;
    }>;
    totalLikes: number;
    totalComments: number;
  };
  sponsors: {
    partnersCount: number;
    partners: Array<{
      name: string;
      productType: string;
      perksOffered: number;
      redemptions: number;
      estimatedReach: string;
    }>;
  };
  topAttendees: Array<{
    name: string;
    specialty: string;
    connectionCount: number;
  }>;
  engagementLevel: 'high' | 'medium' | 'low'; // derived from stats
}

interface EventWrapReportResponse {
  headline: string;
  narrative: string;
  top_moments: string;
  network_highlights: string;
  sponsor_summary: string;
  recommendations: string;
}

/**
 * Generate a comprehensive event wrap report using Claude Sonnet.
 * Called 24+ hours after event completion.
 * Updates event_reports table with generated content and marks status = 'complete'.
 * Logs to llm_usage_log for cost tracking.
 */
export async function generateEventWrapReport(
  db: Client,
  eventId: string,
  model: string = 'claude-sonnet-4-6'
): Promise<void> {
  const startTime = Date.now();

  try {
    // 1. Fetch event and related data
    const context = await buildEventContext(db, eventId);

    if (!context) {
      throw new Error(`Event ${eventId} not found or not completed`);
    }

    // 2. Mark report as 'generating'
    await db.query(
      `UPDATE event_reports SET status = $1, updated_at = NOW() WHERE event_id = $2`,
      ['generating', eventId]
    );

    // 3. Call Claude Sonnet
    const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

    const prompt = buildWrapReportPrompt(context);

    const startTokenTime = Date.now();
    const response = await client.messages.create({
      model,
      max_tokens: 3000,
      messages: [
        {
          role: 'user',
          content: prompt,
        },
      ],
    });
    const latencyMs = Date.now() - startTokenTime;

    // Parse response
    const responseText = response.content[0].type === 'text' ? response.content[0].text : '';
    const parsed = parseWrapReportResponse(responseText);

    // Calculate stats for event_reports.stats JSONB
    const reportStats = {
      totalAttendees: context.attendance.totalAttendees,
      poshAttendees: context.attendance.poshAttendees,
      walkIns: context.attendance.walkIns,
      checkedIn: context.attendance.checkedIn,
      uniqueSpecialties: context.network.uniqueSpecialties,
      connectionsFormed: context.network.connectionsFormed,
      postsCreated: context.content.postsCreated,
      totalLikes: context.content.totalLikes,
      totalComments: context.content.totalComments,
      avgConnectionsPerAttendee:
        context.attendance.totalAttendees > 0
          ? parseFloat((context.network.connectionsFormed / context.attendance.totalAttendees).toFixed(2))
          : 0,
      engagementLevel: context.engagementLevel,
    };

    // Build markdown report
    const fullMarkdown = buildFullReportMarkdown(context, parsed);

    // 4. Upsert into event_reports
    await db.query(
      `INSERT INTO event_reports
        (event_id, model, tokens_used, latency_ms, stats, headline, narrative,
         top_moments, network_highlights, sponsor_summary, recommendations,
         full_report_markdown, status, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, NOW())
       ON CONFLICT (event_id) DO UPDATE SET
        model = $2, tokens_used = $3, latency_ms = $4, stats = $5,
        headline = $6, narrative = $7, top_moments = $8, network_highlights = $9,
        sponsor_summary = $10, recommendations = $11, full_report_markdown = $12,
        status = $13, updated_at = NOW()`,
      [
        eventId,
        model,
        response.usage.input_tokens + response.usage.output_tokens,
        latencyMs,
        JSON.stringify(reportStats),
        parsed.headline,
        parsed.narrative,
        parsed.top_moments,
        parsed.network_highlights,
        parsed.sponsor_summary,
        parsed.recommendations,
        fullMarkdown,
        'complete',
      ]
    );

    // 5. Log to llm_usage_log
    await logLlmUsage(db, {
      feature: 'event_wrap_report',
      model,
      inputTokens: response.usage.input_tokens,
      outputTokens: response.usage.output_tokens,
      latencyMs,
      success: true,
      error: null,
    });

    logger.info(`Event wrap report generated for event ${eventId}`, {
      model,
      tokens: response.usage.input_tokens + response.usage.output_tokens,
      latencyMs,
    });
  } catch (error) {
    const latencyMs = Date.now() - startTime;
    const errorMessage = error instanceof Error ? error.message : String(error);

    logger.error(`Failed to generate event wrap report for ${eventId}`, { error: errorMessage });

    // Mark as failed and store error
    await db.query(
      `INSERT INTO event_reports (event_id, model, status, error_message, updated_at)
       VALUES ($1, $2, $3, $4, NOW())
       ON CONFLICT (event_id) DO UPDATE SET
        status = $3, error_message = $4, updated_at = NOW()`,
      [eventId, model, 'failed', errorMessage]
    );

    // Log failure
    await logLlmUsage(db, {
      feature: 'event_wrap_report',
      model,
      inputTokens: null,
      outputTokens: null,
      latencyMs,
      success: false,
      error: errorMessage,
    });
  }
}

/**
 * Build event context from database joins.
 * Returns null if event not found or status != 'completed'.
 */
async function buildEventContext(db: Client, eventId: string): Promise<EventContext | null> {
  // Fetch event
  const eventResult = await db.query(
    `SELECT id, name, venue_name, venue_address, start_time, end_time
     FROM events WHERE id = $1 AND status = $2`,
    [eventId, 'completed']
  );

  if (eventResult.rows.length === 0) {
    return null;
  }

  const event = eventResult.rows[0];
  const startTime = new Date(event.start_time);
  const endTime = new Date(event.end_time);
  const durationMs = endTime.getTime() - startTime.getTime();
  const hours = Math.round(durationMs / (1000 * 60 * 60) * 10) / 10; // round to nearest 0.1
  const duration = hours === 1 ? '1 hour' : `${hours} hours`;

  // Fetch attendance
  const attendanceResult = await db.query(
    `SELECT
       COUNT(DISTINCT COALESCE(t.user_id, po.user_id)) as total_attendees,
       COUNT(DISTINCT po.id) as posh_attendees,
       COUNT(DISTINCT CASE WHEN po.id IS NULL THEN t.id END) as walk_ins,
       COUNT(DISTINCT CASE WHEN t.checked_in_at IS NOT NULL THEN t.id END) +
       COUNT(DISTINCT CASE WHEN po.checked_in_at IS NOT NULL THEN po.id END) as checked_in
     FROM events e
     LEFT JOIN tickets t ON e.id = t.event_id
     LEFT JOIN posh_orders po ON e.id = po.event_id
     WHERE e.id = $1`,
    [eventId]
  );

  const attendance = attendanceResult.rows[0];

  // Fetch connections formed at this event (from analytics_connections_daily or connection table)
  const connectionsResult = await db.query(
    `SELECT COUNT(*) as count FROM connections
     WHERE event_id = $1`,
    [eventId]
  );

  // Fetch unique specialties
  const specialtiesResult = await db.query(
    `SELECT COUNT(DISTINCT us.specialty_id) as count
     FROM users u
     JOIN user_specialties us ON u.id = us.user_id
     WHERE u.id IN (
       SELECT DISTINCT COALESCE(t.user_id, po.user_id)
       FROM tickets t
       LEFT JOIN posh_orders po ON t.event_id = po.event_id
       WHERE t.event_id = $1 OR po.event_id = $1
     )`,
    [eventId]
  );

  // Fetch top connectors at this event
  const topConnectorsResult = await db.query(
    `SELECT
       u.name, s.name as specialty,
       COUNT(*) as connection_count
     FROM connections c
     JOIN users u ON c.initiator_id = u.id OR c.scanner_id = u.id
     LEFT JOIN specialties s ON u.primary_specialty_id = s.id
     WHERE c.event_id = $1
     GROUP BY u.id, u.name, s.name
     ORDER BY connection_count DESC
     LIMIT 5`,
    [eventId]
  );

  // Fetch posts created at this event
  const postsResult = await db.query(
    `SELECT COUNT(*) as count FROM posts
     WHERE event_id = $1`,
    [eventId]
  );

  // Fetch top posts
  const topPostsResult = await db.query(
    `SELECT
       u.name,
       p.text,
       (SELECT COUNT(*) FROM post_likes WHERE post_id = p.id) as like_count
     FROM posts p
     JOIN users u ON p.user_id = u.id
     WHERE p.event_id = $1
     ORDER BY like_count DESC
     LIMIT 5`,
    [eventId]
  );

  // Fetch likes and comments
  const likesCommentsResult = await db.query(
    `SELECT
       (SELECT COUNT(*) FROM post_likes pl JOIN posts p ON pl.post_id = p.id WHERE p.event_id = $1) as likes,
       (SELECT COUNT(*) FROM post_comments pc JOIN posts p ON pc.post_id = p.id WHERE p.event_id = $1) as comments`,
    [eventId]
  );

  // Fetch sponsors/partners
  const partnersResult = await db.query(
    `SELECT
       c.id, c.name, p.type as product_type,
       (SELECT COUNT(*) FROM discounts WHERE customer_id = c.id) as perks_offered,
       (SELECT COUNT(*) FROM discount_redemptions WHERE discount_id IN
         (SELECT id FROM discounts WHERE customer_id = c.id)) as redemptions,
       CASE WHEN redemptions > 0 THEN
         (SELECT COUNT(DISTINCT user_id) FROM discount_redemptions
          WHERE discount_id IN (SELECT id FROM discounts WHERE customer_id = c.id))
       ELSE 0 END as estimated_reach
     FROM customer_products cp
     JOIN customers c ON cp.customer_id = c.id
     JOIN products p ON cp.product_id = p.id
     WHERE cp.event_id = $1`,
    [eventId]
  );

  // Fetch top attendees by connections
  const topAttendeesResult = await db.query(
    `SELECT
       u.name, s.name as specialty,
       COUNT(*) as connection_count
     FROM users u
     LEFT JOIN specialties s ON u.primary_specialty_id = s.id
     WHERE u.id IN (
       SELECT DISTINCT COALESCE(t.user_id, po.user_id)
       FROM tickets t
       LEFT JOIN posh_orders po ON t.event_id = po.event_id
       WHERE t.event_id = $1 OR po.event_id = $1
     )
     LEFT JOIN connections c ON (u.id = c.initiator_id OR u.id = c.scanner_id) AND c.event_id = $1
     GROUP BY u.id, u.name, s.name
     ORDER BY connection_count DESC
     LIMIT 10`,
    [eventId]
  );

  // Determine engagement level
  const totalAttendees = parseInt(attendance.total_attendees) || 0;
  const connectionsFormed = parseInt(connectionsResult.rows[0].count) || 0;
  const avgConnections = totalAttendees > 0 ? connectionsFormed / totalAttendees : 0;
  const postsCreated = parseInt(postsResult.rows[0].count) || 0;

  let engagementLevel: 'high' | 'medium' | 'low' = 'low';
  if (avgConnections > 2 || postsCreated > 10) {
    engagementLevel = 'high';
  } else if (avgConnections > 1 || postsCreated > 5) {
    engagementLevel = 'medium';
  }

  return {
    event: {
      id: eventId,
      name: event.name,
      venueName: event.venue_name,
      venueAddress: event.venue_address,
      startTime: event.start_time,
      endTime: event.end_time,
      duration,
    },
    attendance: {
      totalAttendees,
      poshAttendees: parseInt(attendance.posh_attendees) || 0,
      walkIns: parseInt(attendance.walk_ins) || 0,
      checkedIn: parseInt(attendance.checked_in) || 0,
    },
    network: {
      connectionsFormed,
      uniqueSpecialties: parseInt(specialtiesResult.rows[0].count) || 0,
      topConnectors: topConnectorsResult.rows.map((r: any) => ({
        name: r.name,
        specialty: r.specialty || 'Unknown',
        connectionCount: parseInt(r.connection_count),
      })),
    },
    content: {
      postsCreated,
      topPosts: topPostsResult.rows.map((r: any) => ({
        author: r.name,
        text: r.text.substring(0, 150), // truncate for context size
        likeCount: parseInt(r.like_count),
      })),
      totalLikes: parseInt(likesCommentsResult.rows[0].likes) || 0,
      totalComments: parseInt(likesCommentsResult.rows[0].comments) || 0,
    },
    sponsors: {
      partnersCount: partnersResult.rows.length,
      partners: partnersResult.rows.map((r: any) => ({
        name: r.name,
        productType: r.product_type,
        perksOffered: parseInt(r.perks_offered),
        redemptions: parseInt(r.redemptions),
        estimatedReach: `${parseInt(r.estimated_reach)} unique users`,
      })),
    },
    topAttendees: topAttendeesResult.rows.map((r: any) => ({
      name: r.name,
      specialty: r.specialty || 'Unknown',
      connectionCount: parseInt(r.connection_count) || 0,
    })),
    engagementLevel,
  };
}

/**
 * Build structured prompt for Sonnet wrap report generation.
 */
function buildWrapReportPrompt(context: EventContext): string {
  return `You are writing a post-event wrap report for Industry Night, a networking event for creative professionals held at ${context.event.venueName}.

EVENT DATA:
${JSON.stringify(context, null, 2)}

Generate a comprehensive wrap report with these exact JSON sections. Use professional, upbeat tone appropriate for sharing with sponsors and platform stakeholders. Be specific with numbers and metrics.

INSTRUCTIONS:
1. HEADLINE: One compelling sentence summarizing the event (max 100 words). Include key stat.
2. NARRATIVE: 2-3 paragraphs telling the story of the event — what made it special, key moments, overall energy and impact.
3. TOP_MOMENTS: 3-5 specific, numbered highlights from the event data (e.g., "847 connections formed across 12+ specialties").
4. NETWORK_HIGHLIGHTS: Analysis of how the creative community connected — which specialties linked most, any notable clusters or surprising collaborations.
5. SPONSOR_SUMMARY: How each sponsor/partner performed — their perks, redemption numbers, estimated reach. If no sponsors, note the organic community focus.
6. RECOMMENDATIONS: 2-3 actionable suggestions for the next Industry Night based on this event's data.

Respond ONLY with valid JSON (no markdown, no extra text). Use these exact field names:
{
  "headline": "...",
  "narrative": "...",
  "top_moments": "...",
  "network_highlights": "...",
  "sponsor_summary": "...",
  "recommendations": "..."
}`;
}

/**
 * Parse Sonnet JSON response into structured format.
 */
function parseWrapReportResponse(responseText: string): EventWrapReportResponse {
  const cleanText = responseText.trim();

  try {
    return JSON.parse(cleanText) as EventWrapReportResponse;
  } catch (e) {
    logger.warn('Failed to parse Sonnet response as JSON; extracting fields manually', {
      response: cleanText.substring(0, 200),
    });

    // Fallback: extract fields using regex
    const headlines = cleanText.match(/"headline"\s*:\s*"([^"]+)"/);
    const narratives = cleanText.match(/"narrative"\s*:\s*"([^"]+)"/s);
    const moments = cleanText.match(/"top_moments"\s*:\s*"([^"]+)"/s);
    const highlights = cleanText.match(/"network_highlights"\s*:\s*"([^"]+)"/s);
    const sponsors = cleanText.match(/"sponsor_summary"\s*:\s*"([^"]+)"/s);
    const recs = cleanText.match(/"recommendations"\s*:\s*"([^"]+)"/s);

    return {
      headline: headlines?.[1] || 'Event wrap report generated.',
      narrative: narratives?.[1] || 'See full report below.',
      top_moments: moments?.[1] || 'Multiple highlights observed.',
      network_highlights: highlights?.[1] || 'Strong networking activity.',
      sponsor_summary: sponsors?.[1] || 'Partners engaged with the community.',
      recommendations: recs?.[1] || 'Continue momentum for next event.',
    };
  }
}

/**
 * Build full markdown report combining all sections.
 */
function buildFullReportMarkdown(context: EventContext, parsed: EventWrapReportResponse): string {
  const date = new Date(context.event.startTime).toLocaleDateString();

  return `# Industry Night Wrap Report

**Event:** ${context.event.name}
**Date:** ${date}
**Venue:** ${context.event.venueName}, ${context.event.venueAddress}
**Duration:** ${context.event.duration}

---

## Headline

${parsed.headline}

---

## Event Overview

${parsed.narrative}

---

## Top Moments

${parsed.top_moments}

---

## Network Highlights

${parsed.network_highlights}

---

## Sponsor Performance

${parsed.sponsor_summary}

---

## Recommendations for Next Event

${parsed.recommendations}

---

## Key Metrics

| Metric | Count |
|--------|-------|
| **Total Attendees** | ${context.attendance.totalAttendees} |
| **Posh Ticket Holders** | ${context.attendance.poshAttendees} |
| **Walk-in Attendees** | ${context.attendance.walkIns} |
| **Checked-in** | ${context.attendance.checkedIn} |
| **Connections Formed** | ${context.network.connectionsFormed} |
| **Avg Connections per Attendee** | ${context.attendance.totalAttendees > 0 ? (context.network.connectionsFormed / context.attendance.totalAttendees).toFixed(2) : 0} |
| **Unique Specialties** | ${context.network.uniqueSpecialties} |
| **Posts Created** | ${context.content.postsCreated} |
| **Total Likes** | ${context.content.totalLikes} |
| **Total Comments** | ${context.content.totalComments} |
| **Engagement Level** | ${context.engagementLevel.toUpperCase()} |

---

*Report generated automatically 24 hours after event completion using Claude Sonnet.*
`;
}

/**
 * Cron-triggered job: generate pending event wrap reports.
 * Runs every hour; generates up to 3 reports per invocation (rate limit).
 * Targets events completed 24+ hours ago without a complete report.
 */
export async function cronGenerateEventWrapReports(
  db: Client,
  config: { eventWrapModel: string; maxReportsPerHour: number } = {
    eventWrapModel: 'claude-sonnet-4-6',
    maxReportsPerHour: 3,
  }
): Promise<void> {
  try {
    // Find events completed 24+ hours ago without a complete report
    const eventsResult = await db.query(
      `SELECT e.id
       FROM events e
       LEFT JOIN event_reports er ON e.id = er.event_id
       WHERE e.status = $1
       AND e.end_time < NOW() - INTERVAL '24 hours'
       AND (er.id IS NULL OR er.status != $2)
       LIMIT $3`,
      ['completed', 'complete', config.maxReportsPerHour]
    );

    const eventIds = eventsResult.rows.map((r: any) => r.id);

    if (eventIds.length === 0) {
      logger.debug('No pending event wrap reports to generate');
      return;
    }

    logger.info(`Generating ${eventIds.length} event wrap reports`, { eventIds });

    for (const eventId of eventIds) {
      await generateEventWrapReport(db, eventId, config.eventWrapModel);
    }
  } catch (error) {
    logger.error('Cron event wrap report generation failed', {
      error: error instanceof Error ? error.message : String(error),
    });
  }
}
```

---

### 3. Jobs: Add cron trigger to `packages/api/src/jobs/index.ts`

Add (or update existing cron job orchestrator):

```typescript
// In packages/api/src/jobs/index.ts
import { cronGenerateEventWrapReports } from '../services/event-wrap';
import { getConfigValue } from '../services/platform-config';

/**
 * Initialize all cron jobs (called on API startup).
 */
export async function initCronJobs(db: Client): Promise<void> {
  // Event wrap reports: every hour
  setInterval(async () => {
    try {
      const model = await getConfigValue(db, 'llm.event_wrap.model', 'claude-sonnet-4-6');
      const maxPerHour = 3; // rate limit

      await cronGenerateEventWrapReports(db, {
        eventWrapModel: model,
        maxReportsPerHour: maxPerHour,
      });
    } catch (error) {
      logger.error('Event wrap cron job error', { error });
    }
  }, 60 * 60 * 1000); // 1 hour

  logger.info('Cron jobs initialized');
}
```

---

### 4. Admin API Routes: `packages/api/src/routes/admin.ts`

Add endpoints for event report management:

```typescript
// Add to routes/admin.ts (in AdminRouter class or function)

/**
 * GET /admin/events/:id/report
 * Fetch the event wrap report for a specific event.
 * Returns 404 if report not yet generated or event not found.
 */
router.get('/events/:id/report', authenticateAdmin, async (req, res) => {
  try {
    const { id: eventId } = req.params;

    const result = await db.query(
      `SELECT * FROM event_reports WHERE event_id = $1`,
      [eventId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Report not found' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    logger.error('GET /admin/events/:id/report error', { error });
    res.status(500).json({ error: 'Failed to fetch report' });
  }
});

/**
 * GET /admin/events/:id/report/markdown
 * Export the full event wrap report as markdown.
 * Content-Type: text/markdown
 */
router.get('/events/:id/report/markdown', authenticateAdmin, async (req, res) => {
  try {
    const { id: eventId } = req.params;

    const result = await db.query(
      `SELECT full_report_markdown FROM event_reports WHERE event_id = $1`,
      [eventId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Report not found' });
    }

    const markdown = result.rows[0].full_report_markdown;

    res.setHeader('Content-Type', 'text/markdown; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="event-wrap-${eventId}.md"`);
    res.send(markdown);
  } catch (error) {
    logger.error('GET /admin/events/:id/report/markdown error', { error });
    res.status(500).json({ error: 'Failed to export markdown' });
  }
});

/**
 * POST /admin/events/:id/generate-report
 * Manually trigger event wrap report generation.
 * Returns 202 Accepted (async operation).
 * Returns 409 if report already complete (with link to GET endpoint).
 */
router.post('/events/:id/generate-report', authenticateAdmin, requirePlatformAdmin, async (req, res) => {
  try {
    const { id: eventId } = req.params;

    // Check if report already exists and is complete
    const existing = await db.query(
      `SELECT status FROM event_reports WHERE event_id = $1`,
      [eventId]
    );

    if (existing.rows.length > 0 && existing.rows[0].status === 'complete') {
      return res.status(409).json({
        error: 'Report already exists',
        message: 'Fetch the existing report or delete and regenerate',
        reportUrl: `/admin/events/${eventId}/report`,
      });
    }

    // Mark for generation (or create pending entry)
    await db.query(
      `INSERT INTO event_reports (event_id, status)
       VALUES ($1, $2)
       ON CONFLICT (event_id) DO UPDATE SET status = $2, updated_at = NOW()`,
      [eventId, 'pending']
    );

    // Trigger async generation
    const config = await getConfigValue(db, 'llm.event_wrap.model', 'claude-sonnet-4-6');
    generateEventWrapReport(db, eventId, config).catch((error) => {
      logger.error('generateEventWrapReport error', { eventId, error });
    });

    res.status(202).json({
      message: 'Report generation started',
      reportUrl: `/admin/events/${eventId}/report`,
    });
  } catch (error) {
    logger.error('POST /admin/events/:id/generate-report error', { error });
    res.status(500).json({ error: 'Failed to trigger report generation' });
  }
});

/**
 * DELETE /admin/events/:id/report
 * Delete an existing event wrap report to force regeneration.
 * Subsequent calls to GET will return 404 until report is regenerated.
 */
router.delete('/events/:id/report', authenticateAdmin, requirePlatformAdmin, async (req, res) => {
  try {
    const { id: eventId } = req.params;

    const result = await db.query(
      `DELETE FROM event_reports WHERE event_id = $1 RETURNING id`,
      [eventId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Report not found' });
    }

    res.json({ message: 'Report deleted', eventId });
  } catch (error) {
    logger.error('DELETE /admin/events/:id/report error', { error });
    res.status(500).json({ error: 'Failed to delete report' });
  }
});
```

---

### 5. Platform Config Seed Values

Add to `packages/database/migrations/NNN_event_reports.sql` or via seed script:

```sql
-- Add to migration or seed script (packages/api/src/seeds/)
INSERT INTO platform_config (key, value, description) VALUES
  ('llm.event_wrap.model', '"claude-sonnet-4-6"', 'Model used for event wrap reports')
ON CONFLICT (key) DO NOTHING;
```

---

### 6. LLM Usage Logging Integration

Ensure `logLlmUsage()` service is available (from C0/D1 context):

```typescript
// packages/api/src/services/llm-usage.ts
interface LlmUsageLogInput {
  feature: string;
  model: string;
  inputTokens: number | null;
  outputTokens: number | null;
  latencyMs: number;
  success: boolean;
  error: string | null;
}

export async function logLlmUsage(db: Client, data: LlmUsageLogInput): Promise<void> {
  await db.query(
    `INSERT INTO llm_usage_log (feature, model, input_tokens, output_tokens, latency_ms, success, error)
     VALUES ($1, $2, $3, $4, $5, $6, $7)`,
    [
      data.feature,
      data.model,
      data.inputTokens,
      data.outputTokens,
      data.latencyMs,
      data.success,
      data.error,
    ]
  );
}
```

---

## Admin App Integration (B3 placeholder)

**Note:** Admin app implementation is in Track B3. This section documents the expected data shape and integration point.

### Event Detail Screen: Add "Wrap Report" Tab

Future `EventDetailScreen` enhancement:

```dart
// In event_detail_screen.dart (packages/admin-app/lib/features/events/)
// Add a "Wrap Report" tab alongside "Images" and "Partners"

Tab(text: 'Wrap Report'),
TabBarView(
  children: [
    // existing Images tab
    // existing Partners tab
    EventWrapReportPanel(eventId: event.id), // NEW
  ],
)

// EventWrapReportPanel widget
class EventWrapReportPanel extends StatelessWidget {
  final String eventId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EventReport?>(
      future: adminApi.getEventReport(eventId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('No report yet'),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    await adminApi.generateEventReport(eventId);
                    // Poll until complete
                  },
                  child: Text('Generate Report'),
                ),
              ],
            ),
          );
        }

        final report = snapshot.data!;

        return SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats cards
              StatsGrid(stats: report.stats),
              SizedBox(height: 24),

              // Narrative sections
              ReportSection(title: 'Headline', content: report.headline),
              ReportSection(title: 'Overview', content: report.narrative),
              ReportSection(title: 'Top Moments', content: report.topMoments),
              ReportSection(title: 'Network Highlights', content: report.networkHighlights),
              ReportSection(title: 'Sponsor Performance', content: report.sponsorSummary),
              ReportSection(title: 'Recommendations', content: report.recommendations),

              SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      // Export markdown
                      adminApi.exportEventReportMarkdown(eventId);
                    },
                    icon: Icon(Icons.download),
                    label: Text('Export Markdown'),
                  ),
                  SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      // Regenerate
                      await adminApi.deleteEventReport(eventId);
                      await adminApi.generateEventReport(eventId);
                    },
                    icon: Icon(Icons.refresh),
                    label: Text('Regenerate'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
```

**B3 should add to shared models:**

```dart
// packages/shared/lib/models/event_report.dart
@JsonSerializable(fieldRename: FieldRename.snake)
class EventReport {
  final String id;
  final String eventId;
  final DateTime generatedAt;
  final String model;
  final int? tokensUsed;
  final int? latencyMs;

  final Map<String, dynamic> stats;

  final String? headline;
  final String? narrative;
  final String? topMoments;
  final String? networkHighlights;
  final String? sponsorSummary;
  final String? recommendations;

  final String? fullReportMarkdown;

  final String status; // pending, generating, complete, failed
  final String? errorMessage;

  EventReport({...});

  factory EventReport.fromJson(Map<String, dynamic> json) => _$EventReportFromJson(json);
  Map<String, dynamic> toJson() => _$EventReportToJson(this);
}
```

**B3 should add to AdminApi:**

```dart
// packages/shared/lib/api/admin_api.dart
Future<EventReport?> getEventReport(String eventId) async {
  final response = await get('/admin/events/$eventId/report');
  if (response.statusCode == 404) return null;
  return EventReport.fromJson(response.data);
}

Future<void> generateEventReport(String eventId) async {
  await post('/admin/events/$eventId/generate-report', {});
}

Future<String> exportEventReportMarkdown(String eventId) async {
  return await getRaw('/admin/events/$eventId/report/markdown');
}

Future<void> deleteEventReport(String eventId) async {
  await delete('/admin/events/$eventId/report');
}
```

---

## Future: Customer-Facing Exports (Not D2)

**Status:** Documented for future development (Track E or later).

### Concept

After D2 completes, a subsequent phase can implement customer-facing event wrap exports:

1. **Filtered Report:** Extract sponsor_summary section for a specific customer/sponsor
2. **Brand Document:** Add sponsor logo, colors, custom messaging
3. **PDF Export:** Convert to PDF using the `pdf` skill (see `docs/codex/SKILL.md`)
4. **Endpoint:** `GET /admin/customers/:customerId/events/:eventId/report/pdf`
5. **Access Control:** Customer can only access reports for events where they had a product purchase

This requires:
- Enhanced sponsor_summary to include individual sponsor KPIs
- Template system for PDF branding
- Customer endpoint in admin API

---

## Test Suite

### `packages/api/src/__tests__/event-wrap.test.ts`

```typescript
describe('Event Wrap Report Generation', () => {
  let db: Client;
  let testEventId: string;

  beforeAll(async () => {
    // Setup test DB with migration applied
    db = new Client({ connectionString: process.env.TEST_DATABASE_URL });
    await db.connect();
    // Migrations run automatically in testcontainers setup
  });

  afterAll(async () => {
    await db.end();
  });

  beforeEach(async () => {
    // Create test event marked as completed 25 hours ago
    const result = await db.query(
      `INSERT INTO events (name, venue_name, venue_address, start_time, end_time,
                          capacity, status, posh_event_id)
       VALUES ($1, $2, $3, NOW() - INTERVAL '25 hours', NOW() - INTERVAL '24.5 hours',
               100, $4, $5)
       RETURNING id`,
      ['Test Event', 'Test Venue', '123 Main St', 'completed', 'posh-12345']
    );
    testEventId = result.rows[0].id;
  });

  test('generateEventWrapReport() calls Sonnet with correct prompt structure', async () => {
    await generateEventWrapReport(db, testEventId);

    const result = await db.query(
      `SELECT status, model FROM event_reports WHERE event_id = $1`,
      [testEventId]
    );

    expect(result.rows[0].status).toBe('complete');
    expect(result.rows[0].model).toBe('claude-sonnet-4-6');
  });

  test('parseWrapReportResponse handles valid JSON correctly', async () => {
    const validJson = `{
      "headline": "Successful event",
      "narrative": "Great turnout",
      "top_moments": "Highlights",
      "network_highlights": "Strong connections",
      "sponsor_summary": "Good engagement",
      "recommendations": "Do it again"
    }`;

    const parsed = parseWrapReportResponse(validJson);

    expect(parsed.headline).toBe('Successful event');
    expect(parsed.narrative).toBe('Great turnout');
  });

  test('parseWrapReportResponse gracefully handles invalid JSON', async () => {
    const invalidJson = 'This is not JSON at all';

    const parsed = parseWrapReportResponse(invalidJson);

    expect(parsed.headline).toBeDefined();
    expect(parsed.narrative).toBeDefined();
  });

  test('generateEventWrapReport gracefully handles events with zero engagement', async () => {
    // Event with no attendees, posts, or connections
    await generateEventWrapReport(db, testEventId);

    const result = await db.query(
      `SELECT status, narrative FROM event_reports WHERE event_id = $1`,
      [testEventId]
    );

    expect(result.rows[0].status).toBe('complete');
    expect(result.rows[0].narrative).toBeTruthy();
  });

  test('generateEventWrapReport records llm_usage_log entry', async () => {
    await generateEventWrapReport(db, testEventId);

    const result = await db.query(
      `SELECT feature, success FROM llm_usage_log
       WHERE feature = $1 ORDER BY created_at DESC LIMIT 1`,
      ['event_wrap_report']
    );

    expect(result.rows.length).toBeGreaterThan(0);
    expect(result.rows[0].feature).toBe('event_wrap_report');
    expect(result.rows[0].success).toBe(true);
  });

  test('generateEventWrapReport sets status=failed and error_message on Sonnet failure', async () => {
    // Mock Sonnet failure (e.g., invalid API key for test)
    process.env.ANTHROPIC_API_KEY = 'invalid-key';

    await generateEventWrapReport(db, testEventId);

    const result = await db.query(
      `SELECT status, error_message FROM event_reports WHERE event_id = $1`,
      [testEventId]
    );

    expect(result.rows[0].status).toBe('failed');
    expect(result.rows[0].error_message).toBeTruthy();
  });

  test('buildEventContext returns null for non-completed events', async () => {
    // Create draft event
    const draftResult = await db.query(
      `INSERT INTO events (name, venue_name, venue_address, start_time, end_time,
                          capacity, status, posh_event_id)
       VALUES ($1, $2, $3, NOW(), NOW() + INTERVAL '2 hours', 100, $4, $5)
       RETURNING id`,
      ['Draft Event', 'Venue', 'Address', 'draft', 'posh-999']
    );

    const context = await buildEventContext(db, draftResult.rows[0].id);

    expect(context).toBeNull();
  });

  test('cronGenerateEventWrapReports respects maxReportsPerHour limit', async () => {
    // Create 5 completed events
    const eventIds: string[] = [];
    for (let i = 0; i < 5; i++) {
      const result = await db.query(
        `INSERT INTO events (name, venue_name, venue_address, start_time, end_time,
                            capacity, status, posh_event_id)
         VALUES ($1, $2, $3, NOW() - INTERVAL '25 hours', NOW() - INTERVAL '24.5 hours',
                 100, $4, $5)
         RETURNING id`,
        [
          `Event ${i}`,
          'Venue',
          'Address',
          'completed',
          `posh-${i}`,
        ]
      );
      eventIds.push(result.rows[0].id);
    }

    // Run cron with limit of 2
    await cronGenerateEventWrapReports(db, {
      eventWrapModel: 'claude-sonnet-4-6',
      maxReportsPerHour: 2,
    });

    const result = await db.query(
      `SELECT COUNT(*) FROM event_reports WHERE status = 'complete'`
    );

    // Should have generated at most 2 reports
    expect(parseInt(result.rows[0].count)).toBeLessThanOrEqual(2);
  });
});
```

### `packages/api/src/__tests__/event-report-endpoints.test.ts`

```typescript
describe('Event Report Endpoints', () => {
  let app: Express;
  let db: Client;
  let adminToken: string;
  let testEventId: string;

  beforeAll(async () => {
    // Setup app and auth
    // Create test event
  });

  test('GET /admin/events/:id/report returns 404 when no report', async () => {
    const response = await request(app)
      .get(`/admin/events/${testEventId}/report`)
      .set('Authorization', `Bearer ${adminToken}`);

    expect(response.status).toBe(404);
  });

  test('POST /admin/events/:id/generate-report returns 202 Accepted', async () => {
    const response = await request(app)
      .post(`/admin/events/${testEventId}/generate-report`)
      .set('Authorization', `Bearer ${adminToken}`);

    expect(response.status).toBe(202);
    expect(response.body.reportUrl).toBeDefined();
  });

  test('GET /admin/events/:id/report returns full report after generation', async () => {
    // Trigger generation
    await request(app)
      .post(`/admin/events/${testEventId}/generate-report`)
      .set('Authorization', `Bearer ${adminToken}`);

    // Poll until complete (max 5 seconds)
    let report;
    for (let i = 0; i < 50; i++) {
      const response = await request(app)
        .get(`/admin/events/${testEventId}/report`)
        .set('Authorization', `Bearer ${adminToken}`);

      if (response.status === 200 && response.body.status === 'complete') {
        report = response.body;
        break;
      }
      await new Promise(resolve => setTimeout(resolve, 100));
    }

    expect(report).toBeDefined();
    expect(report.headline).toBeTruthy();
    expect(report.narrative).toBeTruthy();
    expect(report.stats).toBeDefined();
  });

  test('GET /admin/events/:id/report/markdown returns text/markdown', async () => {
    // Generate report first
    await request(app)
      .post(`/admin/events/${testEventId}/generate-report`)
      .set('Authorization', `Bearer ${adminToken}`);

    // Wait for completion
    await waitForReportComplete(testEventId);

    const response = await request(app)
      .get(`/admin/events/${testEventId}/report/markdown`)
      .set('Authorization', `Bearer ${adminToken}`);

    expect(response.status).toBe(200);
    expect(response.headers['content-type']).toMatch(/text\/markdown/);
    expect(response.text).toContain('# Industry Night Wrap Report');
  });

  test('DELETE /admin/events/:id/report removes report', async () => {
    // Generate report
    await request(app)
      .post(`/admin/events/${testEventId}/generate-report`)
      .set('Authorization', `Bearer ${adminToken}`);

    await waitForReportComplete(testEventId);

    // Delete
    const deleteResponse = await request(app)
      .delete(`/admin/events/${testEventId}/report`)
      .set('Authorization', `Bearer ${adminToken}`);

    expect(deleteResponse.status).toBe(200);

    // Verify 404
    const getResponse = await request(app)
      .get(`/admin/events/${testEventId}/report`)
      .set('Authorization', `Bearer ${adminToken}`);

    expect(getResponse.status).toBe(404);
  });

  test('POST returns 409 if report already complete', async () => {
    // Generate report
    await request(app)
      .post(`/admin/events/${testEventId}/generate-report`)
      .set('Authorization', `Bearer ${adminToken}`);

    await waitForReportComplete(testEventId);

    // Try to generate again
    const response = await request(app)
      .post(`/admin/events/${testEventId}/generate-report`)
      .set('Authorization', `Bearer ${adminToken}`);

    expect(response.status).toBe(409);
    expect(response.body.reportUrl).toBeDefined();
  });
});
```

---

## Definition of Done

- [ ] Migration file `packages/database/migrations/NNN_event_reports.sql` created and applied (with correct sequential number)
- [ ] `event_reports` table exists with all columns and indexes
- [ ] `packages/api/src/services/event-wrap.ts` implemented with `generateEventWrapReport()` and `cronGenerateEventWrapReports()`
- [ ] Service tested: Sonnet called with correct prompt; response parsed into all sections
- [ ] Cron job integrated into `packages/api/src/jobs/index.ts`; runs every hour
- [ ] Admin endpoints implemented: GET report, GET markdown, POST generate, DELETE
- [ ] Rate limiting working: max 3 reports/hour via cron
- [ ] llm_usage_log entries created for all report generations
- [ ] Platform config seed value for `llm.event_wrap.model` inserted
- [ ] All tests in `event-wrap.test.ts` and `event-report-endpoints.test.ts` passing
- [ ] Graceful handling of edge cases: zero engagement, Sonnet failures, already-complete reports
- [ ] Manual trigger works: POST returns 202, report visible within 60 seconds
- [ ] Markdown export works: Content-Type correct, downloadable via admin app
- [ ] B3 integration documented: AdminApi clients, EventReport model, UI component spec
- [ ] No regressions to existing endpoints or tests
- [ ] Completion Report filled in (below)
- [ ] Interrogative Session completed with Jeff

---

## Completion Report

> To be filled in by the executing agent after implementation is complete.

**Branch:** `feature/D2-event-wrap-reports`
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

### What the next phase (B3 or Track E) should know

-

---

## Interrogative Session

**Q1: Do all test scenarios pass, including graceful handling of low-engagement events, Sonnet failures, and rate limiting?**
> Jeff:

**Q2: Is the prompt structure (Sonnet instructions, context payload, JSON response parsing) producing coherent, error-free narrative sections across diverse event profiles?**
> Jeff:

**Q3: Does the cron job respect the rate limit and retry failed reports correctly without getting stuck in a loop?**
> Jeff:

**Q4: How will the B3 team integrate the EventReport model and AdminApi methods? Any concerns about data shape or pagination of the stats JSONB?**
> Jeff:

**Q5: Is the customer-facing export feature (future phase) sufficiently documented in sponsor_summary so that Track E can implement it without schema changes?**
> Jeff:

**Ready for review:** ☐ Yes
