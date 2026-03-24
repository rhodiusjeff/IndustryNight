# [Track-D0] Content Moderation Pipeline — Haiku → Sonnet Escalation

**Track:** D (LLM Pipeline + Analytics)
**Sequence:** 1 of 5 in Track D
**Model:** claude-opus-4-6
**Alternate Model:** gpt-5.4 ← preferred for structured JSON reliability and cost-per-token advantage at scale
**A/B Test:** Yes ⚡ — run both models on `feature/D0-moderation-pipeline-claude` and `feature/D0-moderation-pipeline-gpt`; adversarial panel review before merging to `integration`
**Estimated Effort:** Large (6–8 hours)
**Dependencies:** C0 (platform_config + llm_usage_log tables), C1 (post_reports table exists), A1 (posts table exists with community feed feature)

## Execution Mode (Required)

- [ ] Stage 1 (required): execute and validate locally first (local Postgres + local API + local admin/mobile against local endpoint).
- [ ] Stage 2 (required for backend/integration-impacting tracks): run shared-dev integration smoke only after local pass.
- [ ] Stage 3 (required before PR merge): run AWS dev deploy/integration smoke for final confidence.
- [ ] Completion log must explicitly record: execution mode used, exact commands run, evidence links, and cleanup actions.


---

## Context

Read these before writing any code:

- `CLAUDE.md` — database section (post_moderation_queue schema), LLM pipeline architecture overview
- `docs/product/requirements.md` — Section 5 "Community Moderation" (automated screening vs human review)
- `packages/api/src/services/` — existing services pattern (sms.ts, storage.ts, posh.ts for reference)
- `packages/api/src/__tests__/customers.test.ts` — test structure pattern (jest + testcontainers)
- `docs/codex/track-C/C0-schema-migrations.md` — platform_config and llm_usage_log table reference

---

## Goal

Implement a two-stage LLM content moderation pipeline that automatically screens every new post for policy violations, escalates borderline content to human moderators, and provides platform operators with an actionable review queue. The pipeline must gracefully degrade when API keys are missing (dev safety), integrate with platform config for operator-controlled thresholds, and log all LLM telemetry for cost/performance analysis.

**Architecture:**

```
New Post Created (POST /posts)
      │
      ▼
  [Haiku Screen]  ◄── 3–5 sec latency, low cost
  confidence < threshold?
  ├── PASS (conf > 0.85): auto-approve, continue
  ├── BLOCK (obvious, conf > 0.99): auto-remove, notify user
  └── REVIEW (conf 0.85–0.99): escalate to Sonnet
                │
                ▼
           [Sonnet Review]  ◄── 8–12 sec latency, deeper analysis
           confidence?
           ├── PASS: approve, no action
           ├── BLOCK (conf > 0.95): auto-remove, notify user
           └── FLAG (conf 0.5–0.95): push to human review queue
                       │
                       ▼
                  [Admin Queue]
                  Moderators review
                  and approve or remove
```

User-reported posts (from C1) skip Haiku and go straight to Sonnet.

---

## Acceptance Criteria

**Database:**
- [ ] `post_moderation_queue` table exists (schema defined below)
- [ ] `posts.moderation_status VARCHAR(20) DEFAULT 'pending'` column added
- [ ] Valid statuses: `pending` (just created), `approved`, `flagged`, `removed`
- [ ] Indexes on `post_moderation_queue(post_id)`, `post_id(decision)` for WHERE decision='flag'

**Moderation service (`packages/api/src/services/moderation.ts`):**
- [ ] `ModerationResult` interface exported with: decision, confidence, categories, reasoning, model, tokensUsed, latencyMs
- [ ] `screenPost(postId, content)` function exists; calls Haiku, returns result, sets post.moderation_status
- [ ] `reviewPost(postId, content)` function exists; calls Sonnet, returns result, creates queue entry
- [ ] `escalateToSonnet(haiku_result)` logic: REVIEW decision → call reviewPost()
- [ ] Haiku prompt matches spec below (JSON-only response, fast classification)
- [ ] Sonnet prompt matches spec below (JSON-only response, context-aware review)
- [ ] Graceful fallback when `ANTHROPIC_API_KEY` not set: resolve to { decision: 'pass', confidence: 1.0 } without error
- [ ] All Anthropic API calls go through ApiClient-like wrapper (for retry + error handling)
- [ ] All LLM calls logged to `llm_usage_log` (feature, model, tokens_input, tokens_output, latency_ms, success, metadata)
- [ ] Platform config integration: read `llm_moderation.confidence_haiku_threshold`, `llm_moderation.model_haiku`, `llm_moderation.model_sonnet`, etc. from platform_config; cache with 5-min TTL
- [ ] Async fire-and-forget: post creation does NOT wait for Haiku screening; screenPost() called via `setImmediate`; errors logged but don't crash response

**Post mutation flow:**
- [ ] On Haiku PASS (>0.85): set `posts.moderation_status = 'approved'`; no queue entry
- [ ] On Haiku BLOCK (>0.99 violation confidence): set `posts.moderation_status = 'removed'`; create queue entry with decision='block', flagged_by='haiku_screen'
- [ ] On Haiku REVIEW: call reviewPost() asynchronously; wait max 30 sec; result determines final status
- [ ] On Sonnet PASS: set `posts.moderation_status = 'approved'`; create queue entry with decision='pass' (for audit)
- [ ] On Sonnet BLOCK (>0.95): set `posts.moderation_status = 'removed'`; create queue entry with decision='block', flagged_by='sonnet_review'
- [ ] On Sonnet FLAG (0.5–0.95): set `posts.moderation_status = 'flagged'`; create queue entry with decision='flag', stage='human_review'
- [ ] On user-reported post: skip Haiku entirely; call reviewPost() directly; same Sonnet thresholds apply

**Admin queue endpoints (add to `packages/api/src/routes/admin.ts`):**
- [ ] `GET /admin/moderation/queue` — returns posts with moderation_status='flagged' or queue entries where decision='flag' and admin_decision IS NULL
  - Fields: postId, postContent, authorId, authorName, authorAvatar, categories (from last LLM decision), reasoning, haiku_reasoning, sonnet_reasoning, reportCount, createdAt
  - Query filters: `?status=pending|all|removed`, `?sort=newest|oldest|reports`
  - Pagination: `?limit=20&offset=0`
- [ ] `POST /admin/moderation/queue/:queueId/decision` — admin approves or removes flagged post
  - Body: `{ decision: 'approve' | 'remove', notes?: string }`
  - 'approve': set posts.moderation_status='approved'; set queue entry admin_decision='approved', reviewed_by_admin_id, reviewed_at, admin_notes
  - 'remove': set posts.moderation_status='removed'; set queue entry admin_decision='removed', reviewed_by_admin_id, reviewed_at, admin_notes
  - Both: create audit_log entry (action='update', entity='post', entityId=post_id, changes={moderation_status, admin_decision})
  - Returns: updated queue entry + post
- [ ] Require `requirePlatformAdmin` middleware on both endpoints

**Push notifications (add to `packages/api/src/services/moderation.ts`):**
- [ ] On auto-BLOCK (Haiku or Sonnet): if user.fcm_token exists, send FCM notification: `{ title: "Post Removed", body: "Your post was removed for violating community guidelines.", data: { categories: JSON.stringify(categories), decision: 'block' } }`
- [ ] If FCM send fails (no token, FCM error): log and continue (don't crash)
- [ ] Use existing FCM integration from C2 (assume it exists; import from there if available, or stub for now)

**Social app feed query:**
- [ ] Update POST /posts list query: `WHERE moderation_status IN ('approved', 'pending') AND ...`
- [ ] 'removed' posts hidden from all users except their author (who sees "This post was removed")
- [ ] 'flagged' posts still visible (admin decision is pending; assume innocent until moderated)
- [ ] Add `moderation_status` to Post model response (for future in-app UI like "pending review")

**Tests (`packages/api/src/__tests__/moderation.test.ts`):**
- [ ] Test 1: Haiku returns PASS → post.moderation_status='approved', no queue entry
- [ ] Test 2: Haiku returns REVIEW → Sonnet called asynchronously → Sonnet returns FLAG → queue entry created with decision='flag'
- [ ] Test 3: Haiku returns BLOCK (>0.99) → post.moderation_status='removed', queue entry created with flagged_by='haiku_screen'
- [ ] Test 4: Sonnet returns BLOCK (>0.95) → post.moderation_status='removed'
- [ ] Test 5: Invalid JSON response from Anthropic → graceful fallback (log error in llm_usage_log, treat as PASS)
- [ ] Test 6: ANTHROPIC_API_KEY not set → screenPost resolves to { decision: 'pass' } without API call
- [ ] Test 7: Platform config threshold 0.90 → Haiku REVIEW confidence=0.87 doesn't escalate (PASS instead)
- [ ] Test 8: POST /admin/moderation/queue returns flagged posts with correct fields
- [ ] Test 9: POST /admin/moderation/queue/:queueId/decision { decision: 'approve' } → post.moderation_status='approved', audit log entry created
- [ ] Test 10: User-reported post → skips Haiku, goes straight to Sonnet
- [ ] Test 11: Async timing → post creation returns immediately; screenPost called via setImmediate; verification via polling in test
- [ ] Test 12: FCM notification sent on auto-BLOCK if user has fcm_token

**Interrogative session:**
- [ ] 5 agent questions + 3 Jeff questions (below)

---

## Technical Spec

### 1. Database Migration

Add to `packages/database/migrations/004_moderation.sql` (or append to C0/C1 migration if that's preferred):

```sql
-- Post moderation status tracking
ALTER TABLE posts ADD COLUMN IF NOT EXISTS moderation_status VARCHAR(20) DEFAULT 'pending';

-- Moderation queue for flagged posts and LLM decisions
CREATE TABLE IF NOT EXISTS post_moderation_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  flagged_by VARCHAR(50) NOT NULL,  -- 'haiku_screen', 'sonnet_review', 'user_report', 'manual'
  stage VARCHAR(30) NOT NULL,        -- 'haiku_screen', 'sonnet_review', 'human_review'
  decision VARCHAR(20),              -- 'pass', 'block', 'flag', 'pending'
  confidence DECIMAL(5,3),           -- 0.000 to 1.000
  categories JSONB DEFAULT '[]',     -- e.g., ["spam", "harassment"]
  reasoning TEXT,                    -- brief explanation from LLM
  model VARCHAR(100),                -- 'claude-haiku-4-5-20251001', 'claude-sonnet-4-6', etc.
  haiku_reasoning TEXT,              -- reasoning from Haiku stage (if escalated)
  sonnet_reasoning TEXT,             -- reasoning from Sonnet stage (if reached)
  reviewed_at TIMESTAMPTZ,
  reviewed_by_admin_id UUID REFERENCES admin_users(id) ON DELETE SET NULL,
  admin_decision VARCHAR(20),        -- 'approved', 'removed', NULL (pending)
  admin_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pmq_post_id ON post_moderation_queue(post_id);
CREATE INDEX IF NOT EXISTS idx_pmq_decision_pending ON post_moderation_queue(decision)
  WHERE decision = 'flag' AND admin_decision IS NULL;
CREATE INDEX IF NOT EXISTS idx_pmq_created ON post_moderation_queue(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_moderation ON posts(moderation_status);

-- Audit trail constraint: if decision='block', it must have been flagged by haiku/sonnet/manual
-- (no explicit constraint needed; enforced at app layer)
```

### 2. Moderation Service

Create `packages/api/src/services/moderation.ts`:

```typescript
import Anthropic from "@anthropic-ai/sdk";
import { db } from "../lib/db";
import { logLlmUsage } from "./llm-logger";
import { getPlatformConfig, PlatformConfig } from "./platform-config";
import { sendFcmNotification } from "./fcm";  // stub if not yet implemented

const anthropic = process.env.ANTHROPIC_API_KEY
  ? new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY })
  : null;

export interface ModerationResult {
  decision: "pass" | "block" | "flag" | "review";
  confidence: number;
  categories: string[];
  reasoning: string;
  model: string;
  tokensUsed: number;
  latencyMs: number;
}

interface HaikuResponse {
  decision: "PASS" | "REVIEW" | "BLOCK";
  confidence: number;
  categories: string[];
  reasoning: string;
}

interface SonnetResponse {
  decision: "PASS" | "FLAG" | "BLOCK";
  confidence: number;
  categories: string[];
  reasoning: string;
}

/**
 * Stage 1: Fast pre-screening with Haiku
 * Returns immediately; decision determines if escalation to Sonnet is needed
 */
export async function screenPost(
  postId: string,
  content: string
): Promise<ModerationResult> {
  if (!anthropic) {
    // No API key: pass through (dev safety)
    return {
      decision: "pass",
      confidence: 1.0,
      categories: [],
      reasoning: "No API key configured; moderation disabled",
      model: "none",
      tokensUsed: 0,
      latencyMs: 0,
    };
  }

  const config = await getPlatformConfig();
  const startTime = Date.now();
  const haiku_model = config.llm_moderation_model_haiku || "claude-haiku-4-5-20251001";
  const threshold = config.llm_moderation_confidence_auto_approve || 0.85;

  const prompt = `You are a content moderator for Industry Night, a professional platform for creative workers (hair stylists, makeup artists, photographers, videographers, producers).

Review this post and classify it:
- PASS: Professional content appropriate for the platform
- REVIEW: Borderline content that needs closer review
- BLOCK: Clear violation (spam, harassment, hate speech, explicit sexual content, illegal content)

Post content: "${content.replace(/"/g, '\\"')}"

Respond with JSON only:
{"decision": "PASS|REVIEW|BLOCK", "confidence": 0.0-1.0, "categories": [], "reasoning": "brief explanation"}`;

  try {
    const message = await anthropic.messages.create({
      model: haiku_model,
      max_tokens: 256,
      messages: [{ role: "user", content: prompt }],
    });

    const latencyMs = Date.now() - startTime;
    const responseText =
      message.content[0].type === "text" ? message.content[0].text : "";
    const parsed: HaikuResponse = JSON.parse(responseText);

    const tokensUsed =
      (message.usage?.input_tokens || 0) + (message.usage?.output_tokens || 0);

    // Log to LLM usage table
    await logLlmUsage({
      feature: "post_moderation_haiku",
      model: haiku_model,
      input_tokens: message.usage?.input_tokens || 0,
      output_tokens: message.usage?.output_tokens || 0,
      latency_ms: latencyMs,
      success: true,
      metadata: { postId, decision: parsed.decision, confidence: parsed.confidence },
    });

    const result: ModerationResult = {
      decision:
        parsed.decision === "PASS"
          ? "pass"
          : parsed.decision === "REVIEW"
            ? "review"
            : "block",
      confidence: parsed.confidence,
      categories: parsed.categories || [],
      reasoning: parsed.reasoning,
      model: haiku_model,
      tokensUsed,
      latencyMs,
    };

    // Update post status and queue based on decision
    if (result.decision === "pass" && result.confidence > threshold) {
      // Auto-approve
      await db.query("UPDATE posts SET moderation_status = $1 WHERE id = $2", [
        "approved",
        postId,
      ]);
    } else if (result.decision === "block" && result.confidence > 0.99) {
      // Auto-remove
      await db.query("UPDATE posts SET moderation_status = $1 WHERE id = $2", [
        "removed",
        postId,
      ]);

      // Create queue entry
      await db.query(
        `INSERT INTO post_moderation_queue (post_id, flagged_by, stage, decision, confidence, categories, reasoning, model)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
        [
          postId,
          "haiku_screen",
          "haiku_screen",
          "block",
          result.confidence,
          JSON.stringify(result.categories),
          result.reasoning,
          haiku_model,
        ]
      );

      // Send FCM notification to post author
      try {
        const postResult = await db.query(
          "SELECT user_id FROM posts WHERE id = $1",
          [postId]
        );
        const authorId = postResult.rows[0]?.user_id;
        if (authorId) {
          const userResult = await db.query(
            "SELECT fcm_token FROM users WHERE id = $1",
            [authorId]
          );
          const fcmToken = userResult.rows[0]?.fcm_token;
          if (fcmToken) {
            await sendFcmNotification(fcmToken, {
              title: "Post Removed",
              body: "Your post was removed for violating community guidelines.",
              data: {
                categories: JSON.stringify(result.categories),
                decision: "block",
              },
            }).catch((err) =>
              console.error("FCM send failed:", err.message)
            );
          }
        }
      } catch (err) {
        console.error("FCM notification error:", err);
      }
    } else if (result.decision === "review") {
      // Escalate to Sonnet
      setImmediate(() => {
        reviewPost(postId, content, result.reasoning).catch((err) =>
          console.error("Sonnet review failed:", err.message)
        );
      });
    }

    return result;
  } catch (err) {
    const latencyMs = Date.now() - startTime;
    console.error("Haiku screening error:", err);

    // Log failure
    await logLlmUsage({
      feature: "post_moderation_haiku",
      model: haiku_model,
      input_tokens: 0,
      output_tokens: 0,
      latency_ms: latencyMs,
      success: false,
      error: err instanceof Error ? err.message : String(err),
      metadata: { postId },
    }).catch(() => {});

    // Graceful fallback: treat as pass
    return {
      decision: "pass",
      confidence: 1.0,
      categories: [],
      reasoning: "Moderation service error; defaulting to pass",
      model: haiku_model,
      tokensUsed: 0,
      latencyMs,
    };
  }
}

/**
 * Stage 2: Deeper review with Sonnet
 * Called for borderline content or user-reported posts
 */
export async function reviewPost(
  postId: string,
  content: string,
  haiku_reasoning?: string
): Promise<ModerationResult> {
  if (!anthropic) {
    return {
      decision: "pass",
      confidence: 1.0,
      categories: [],
      reasoning: "No API key configured",
      model: "none",
      tokensUsed: 0,
      latencyMs: 0,
    };
  }

  const config = await getPlatformConfig();
  const startTime = Date.now();
  const sonnet_model =
    config.llm_moderation_model_sonnet || "claude-sonnet-4-6";

  const prompt = `You are a senior content moderator for Industry Night, a platform for creative professionals. A post has been flagged for secondary review.

Analyze this post carefully:
- PASS: Acceptable for a professional creative community platform
- FLAG: Borderline content — needs human moderator review
- BLOCK: Clear violation that should be removed immediately

Consider: Is this spam? Does it target individuals? Does it contain prohibited content? Is it off-topic for a professional creative platform?

Post content: "${content.replace(/"/g, '\\"')}"
${haiku_reasoning ? `Initial screening notes: ${haiku_reasoning}` : ""}

Respond with JSON only:
{"decision": "PASS|FLAG|BLOCK", "confidence": 0.0-1.0, "categories": [], "reasoning": "explanation for moderators"}`;

  try {
    const message = await anthropic.messages.create({
      model: sonnet_model,
      max_tokens: 512,
      messages: [{ role: "user", content: prompt }],
    });

    const latencyMs = Date.now() - startTime;
    const responseText =
      message.content[0].type === "text" ? message.content[0].text : "";
    const parsed: SonnetResponse = JSON.parse(responseText);

    const tokensUsed =
      (message.usage?.input_tokens || 0) + (message.usage?.output_tokens || 0);

    // Log to LLM usage
    await logLlmUsage({
      feature: "post_moderation_sonnet",
      model: sonnet_model,
      input_tokens: message.usage?.input_tokens || 0,
      output_tokens: message.usage?.output_tokens || 0,
      latency_ms: latencyMs,
      success: true,
      metadata: { postId, decision: parsed.decision, confidence: parsed.confidence },
    });

    const result: ModerationResult = {
      decision:
        parsed.decision === "PASS"
          ? "pass"
          : parsed.decision === "FLAG"
            ? "flag"
            : "block",
      confidence: parsed.confidence,
      categories: parsed.categories || [],
      reasoning: parsed.reasoning,
      model: sonnet_model,
      tokensUsed,
      latencyMs,
    };

    // Update post status
    if (result.decision === "pass") {
      await db.query("UPDATE posts SET moderation_status = $1 WHERE id = $2", [
        "approved",
        postId,
      ]);
    } else if (result.decision === "block" && result.confidence > 0.95) {
      await db.query("UPDATE posts SET moderation_status = $1 WHERE id = $2", [
        "removed",
        postId,
      ]);
    } else if (result.decision === "flag") {
      await db.query("UPDATE posts SET moderation_status = $1 WHERE id = $2", [
        "flagged",
        postId,
      ]);
    }

    // Create or update queue entry
    const existingQueue = await db.query(
      "SELECT id FROM post_moderation_queue WHERE post_id = $1 ORDER BY created_at DESC LIMIT 1",
      [postId]
    );

    if (existingQueue.rows.length > 0) {
      // Update existing entry (escalated from Haiku)
      await db.query(
        `UPDATE post_moderation_queue SET
         stage = $1, decision = $2, confidence = $3, categories = $4, sonnet_reasoning = $5, model = $6
         WHERE id = $7`,
        [
          "sonnet_review",
          result.decision,
          result.confidence,
          JSON.stringify(result.categories),
          result.reasoning,
          sonnet_model,
          existingQueue.rows[0].id,
        ]
      );
    } else {
      // Create new entry (user-reported post)
      await db.query(
        `INSERT INTO post_moderation_queue (post_id, flagged_by, stage, decision, confidence, categories, reasoning, model)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
        [
          postId,
          "user_report",
          "sonnet_review",
          result.decision,
          result.confidence,
          JSON.stringify(result.categories),
          result.reasoning,
          sonnet_model,
        ]
      );
    }

    // Send FCM notification if auto-blocked
    if (result.decision === "block" && result.confidence > 0.95) {
      try {
        const postResult = await db.query(
          "SELECT user_id FROM posts WHERE id = $1",
          [postId]
        );
        const authorId = postResult.rows[0]?.user_id;
        if (authorId) {
          const userResult = await db.query(
            "SELECT fcm_token FROM users WHERE id = $1",
            [authorId]
          );
          const fcmToken = userResult.rows[0]?.fcm_token;
          if (fcmToken) {
            await sendFcmNotification(fcmToken, {
              title: "Post Removed",
              body: "Your post was removed for violating community guidelines.",
              data: {
                categories: JSON.stringify(result.categories),
                decision: "block",
              },
            }).catch((err) =>
              console.error("FCM send failed:", err.message)
            );
          }
        }
      } catch (err) {
        console.error("FCM notification error:", err);
      }
    }

    return result;
  } catch (err) {
    const latencyMs = Date.now() - startTime;
    console.error("Sonnet review error:", err);

    await logLlmUsage({
      feature: "post_moderation_sonnet",
      model: sonnet_model,
      input_tokens: 0,
      output_tokens: 0,
      latency_ms: latencyMs,
      success: false,
      error: err instanceof Error ? err.message : String(err),
      metadata: { postId },
    }).catch(() => {});

    // Graceful fallback: treat as flag (send to human review)
    await db.query("UPDATE posts SET moderation_status = $1 WHERE id = $2", [
      "flagged",
      postId,
    ]);

    const queueResult = await db.query(
      "SELECT id FROM post_moderation_queue WHERE post_id = $1 ORDER BY created_at DESC LIMIT 1",
      [postId]
    );

    if (queueResult.rows.length > 0) {
      await db.query(
        `UPDATE post_moderation_queue SET decision = $1, reasoning = $2, model = $3 WHERE id = $4`,
        [
          "flag",
          "Service error during review; escalating to human review",
          sonnet_model,
          queueResult.rows[0].id,
        ]
      );
    } else {
      await db.query(
        `INSERT INTO post_moderation_queue (post_id, flagged_by, stage, decision, reasoning)
         VALUES ($1, $2, $3, $4, $5)`,
        [
          postId,
          "sonnet_review",
          "human_review",
          "flag",
          "Service error during review; escalating to human review",
        ]
      );
    }

    return {
      decision: "flag",
      confidence: 0.5,
      categories: [],
      reasoning: "Service error; defaulting to flag for human review",
      model: sonnet_model,
      tokensUsed: 0,
      latencyMs,
    };
  }
}
```

### 3. Platform Config Service

Create `packages/api/src/services/platform-config.ts` (if not already exists):

```typescript
import { db } from "../lib/db";

export interface PlatformConfig {
  llm_moderation_model_haiku?: string;
  llm_moderation_model_sonnet?: string;
  llm_moderation_confidence_auto_approve?: number;
  llm_moderation_confidence_auto_reject?: number;
  llm_moderation_confidence_human_floor?: number;
  feature_flag_push_notifications?: boolean;
  [key: string]: any;
}

let configCache: PlatformConfig | null = null;
let cacheExpiredAt: number = 0;

const CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes

export async function getPlatformConfig(): Promise<PlatformConfig> {
  const now = Date.now();

  if (configCache && now < cacheExpiredAt) {
    return configCache;
  }

  try {
    const result = await db.query("SELECT key, value FROM platform_config");
    const config: PlatformConfig = {};

    result.rows.forEach((row) => {
      try {
        config[row.key] = JSON.parse(row.value);
      } catch {
        config[row.key] = row.value;
      }
    });

    configCache = config;
    cacheExpiredAt = now + CACHE_TTL_MS;

    return config;
  } catch (err) {
    console.error("Failed to load platform config:", err);
    // Return defaults
    return {
      llm_moderation_model_haiku: "claude-haiku-4-5-20251001",
      llm_moderation_model_sonnet: "claude-sonnet-4-6",
      llm_moderation_confidence_auto_approve: 0.85,
      llm_moderation_confidence_auto_reject: 0.95,
      llm_moderation_confidence_human_floor: 0.3,
    };
  }
}

export function invalidateConfigCache(): void {
  configCache = null;
  cacheExpiredAt = 0;
}
```

### 4. LLM Logger Service

Create `packages/api/src/services/llm-logger.ts`:

```typescript
import { db } from "../lib/db";

export interface LlmUsageInput {
  feature: string;
  model: string;
  input_tokens: number;
  output_tokens: number;
  latency_ms: number;
  success: boolean;
  error?: string;
  metadata?: Record<string, any>;
}

export async function logLlmUsage(input: LlmUsageInput): Promise<void> {
  try {
    await db.query(
      `INSERT INTO llm_usage_log (feature, model, input_tokens, output_tokens, latency_ms, success, error, metadata)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
      [
        input.feature,
        input.model,
        input.input_tokens,
        input.output_tokens,
        input.latency_ms,
        input.success,
        input.error || null,
        input.metadata ? JSON.stringify(input.metadata) : null,
      ]
    );
  } catch (err) {
    console.error("Failed to log LLM usage:", err);
    // Non-fatal: don't crash if logging fails
  }
}
```

### 5. Admin Moderation Queue Endpoints

Add to `packages/api/src/routes/admin.ts`:

```typescript
// GET /admin/moderation/queue
router.get(
  "/moderation/queue",
  authenticateAdmin,
  requirePlatformAdmin,
  validate({
    query: z.object({
      status: z.enum(["pending", "all"]).default("pending"),
      sort: z.enum(["newest", "oldest", "reports"]).default("newest"),
      limit: z.coerce.number().int().positive().default(20),
      offset: z.coerce.number().int().nonnegative().default(0),
    }),
  }),
  async (req, res, next) => {
    try {
      const { status, sort, limit, offset } = req.query;

      const whereClause =
        status === "pending"
          ? "WHERE pmq.admin_decision IS NULL AND pmq.decision = 'flag'"
          : "WHERE pmq.decision = 'flag'";

      const sortClause =
        sort === "reports"
          ? "ORDER BY (SELECT COUNT(*) FROM post_reports WHERE post_id = p.id) DESC"
          : sort === "oldest"
            ? "ORDER BY pmq.created_at ASC"
            : "ORDER BY pmq.created_at DESC";

      const result = await db.query(
        `
        SELECT
          pmq.id as queue_id,
          p.id as post_id,
          p.content,
          p.user_id as author_id,
          u.name as author_name,
          u.avatar_url as author_avatar,
          pmq.categories,
          pmq.reasoning as sonnet_reasoning,
          pmq.haiku_reasoning,
          (SELECT COUNT(*) FROM post_reports WHERE post_id = p.id) as report_count,
          pmq.created_at,
          pmq.stage,
          pmq.decision,
          pmq.confidence
        FROM post_moderation_queue pmq
        JOIN posts p ON pmq.post_id = p.id
        JOIN users u ON p.user_id = u.id
        ${whereClause}
        ${sortClause}
        LIMIT $1 OFFSET $2
        `,
        [limit, offset]
      );

      res.json({
        items: result.rows,
        total: result.rows.length,
        limit,
        offset,
      });
    } catch (err) {
      next(err);
    }
  }
);

// POST /admin/moderation/queue/:queueId/decision
router.post(
  "/moderation/queue/:queueId/decision",
  authenticateAdmin,
  requirePlatformAdmin,
  validate({
    body: z.object({
      decision: z.enum(["approve", "remove"]),
      notes: z.string().optional(),
    }),
  }),
  async (req, res, next) => {
    try {
      const { queueId } = req.params;
      const { decision, notes } = req.body;
      const adminId = req.user?.userId;

      // Get queue entry and post
      const queueResult = await db.query(
        "SELECT post_id FROM post_moderation_queue WHERE id = $1",
        [queueId]
      );

      if (!queueResult.rows.length) {
        return res.status(404).json({ error: "Queue entry not found" });
      }

      const postId = queueResult.rows[0].post_id;

      // Update post moderation status
      const newStatus = decision === "approve" ? "approved" : "removed";
      await db.query("UPDATE posts SET moderation_status = $1 WHERE id = $2", [
        newStatus,
        postId,
      ]);

      // Update queue entry
      await db.query(
        `UPDATE post_moderation_queue
         SET admin_decision = $1, admin_notes = $2, reviewed_by_admin_id = $3, reviewed_at = NOW()
         WHERE id = $4`,
        [decision, notes || null, adminId, queueId]
      );

      // Audit log
      await db.query(
        `INSERT INTO audit_log (action, entity, entity_id, admin_id, changes)
         VALUES ($1, $2, $3, $4, $5)`,
        [
          "update",
          "post",
          postId,
          adminId || null,
          JSON.stringify({
            moderation_status: newStatus,
            admin_decision: decision,
          }),
        ]
      );

      // Return updated entry
      const updated = await db.query(
        "SELECT * FROM post_moderation_queue WHERE id = $1",
        [queueId]
      );

      res.json(updated.rows[0]);
    } catch (err) {
      next(err);
    }
  }
);
```

### 6. Post Creation Integration

Modify `packages/api/src/routes/posts.ts` (POST /posts):

```typescript
// After inserting post (existing code)
const postId = postResult.rows[0].id;

// Fire-and-forget moderation screening
setImmediate(() => {
  screenPost(postId, content).catch((err) =>
    console.error("Post moderation failed:", err.message)
  );
});

// Return post to client immediately (don't wait for moderation)
res.status(201).json(postResult.rows[0]);
```

### 7. Feed Query Update

Modify `packages/api/src/routes/posts.ts` (GET /posts community feed):

```typescript
// Update WHERE clause to exclude removed posts
const query = `
  SELECT p.* FROM posts p
  WHERE p.moderation_status IN ('approved', 'pending')
    AND ...other filters...
  ORDER BY p.created_at DESC
  LIMIT $1 OFFSET $2
`;
```

---

## A/B Architectural Decision Note

The two models differ in approach:

**Claude (Opus):**
- Uses structured JSON parsing with try-catch fallback to graceful degradation
- Emphasis on recursive escalation logic (Haiku → Sonnet → Queue)
- Fine-grained error handling per stage

**GPT-5.4:**
- Prefers batch processing and simpler state transitions
- May structure queue writes differently (transactional vs. per-stage)
- Likely different FCM integration approach

Panel reviewers should compare:
1. Code clarity and maintainability
2. Robustness of JSON parsing + error handling
3. Efficiency of state transitions (number of DB queries per post)
4. How platform config is cached and invalidated
5. Alignment with existing Industry Night patterns (see C0, customers.test.ts)

---

## Definition of Done

- [ ] `packages/api/src/services/moderation.ts` complete and exported
- [ ] `packages/api/src/services/platform-config.ts` complete with 5-min cache
- [ ] `packages/api/src/services/llm-logger.ts` complete
- [ ] Admin queue endpoints added to `packages/api/src/routes/admin.ts`
- [ ] Post creation flow calls `screenPost()` via setImmediate (fire-and-forget)
- [ ] Feed query updated to exclude removed posts
- [ ] Database migration applied (post_moderation_queue table, posts.moderation_status)
- [ ] All 12 tests passing (moderation.test.ts + moderation-queue.test.ts)
- [ ] ANTHROPIC_API_KEY not set: all endpoints work without errors
- [ ] Platform config values respected: threshold changes take effect within 5 min
- [ ] All LLM calls logged to llm_usage_log with correct metadata
- [ ] FCM notifications sent on auto-BLOCK (if user has fcm_token)
- [ ] Async timing verified (post returns before screenPost completes)
- [ ] Completion Report filled in (below)
- [ ] Interrogative Session completed with Jeff
- [ ] (A/B) Adversarial panel review complete — see `docs/codex/reviews/D0-adversarial-review.md`

---

## Completion Report

> To be filled in by the executing agent after implementation is complete.

**Branch:** `feature/D0-moderation-pipeline-[claude|gpt]`
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

### A/B Architectural Deviation Note

-

### What the next prompt in this track (D1) should know

-

---

## Interrogative Session

**Q1 (Agent):** Does the two-stage pipeline work end-to-end, including the async fire-and-forget timing and state transitions? Can you walk through a specific example (Haiku REVIEW → Sonnet FLAG → queue entry created)?

> Jeff:

**Q2 (Agent):** How does the graceful fallback behave when ANTHROPIC_API_KEY is not set? Does every endpoint remain functional without crashing?

> Jeff:

**Q3 (Agent):** Are the platform config values actually respected? (i.e., changing llm_moderation_confidence_auto_approve to 0.92 causes borderline posts to pass through instead of being reviewed)

> Jeff:

**Q4 (Agent):** Does the admin queue endpoint return the correct fields for UI display, including both haiku_reasoning and sonnet_reasoning when a post was escalated?

> Jeff:

**Q5 (Agent):** Are all LLM calls properly logged to llm_usage_log with correct tokens, latency, and metadata? Can you query the log and see the moderation pipeline in action?

> Jeff:

**Q6 (Human - Jeff):** Does the system handle high-latency Sonnet reviews gracefully? If a post is escalated and Sonnet takes 30+ seconds, does the user see the post immediately or is there a visible delay?

> Agent:

**Q7 (Human - Jeff):** When a post author receives an FCM notification about removal, what information should be included in the notification body vs. the data payload? Should they be able to appeal?

> Agent:

**Q8 (Human - Jeff):** What's the expected volume of posts per day, and how will the moderation queue scale? Should we add pagination, filtering by category, or filtering by admin assignment?

> Agent:

**Ready for review:** ☐ Yes
