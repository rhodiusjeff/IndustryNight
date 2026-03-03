# Data Products & Report Generation Plan

> **Status:** Planning
> **Created:** 2026-03-03
> **Purpose:** Define the data products Industry Night can sell to sponsors and vendors, and the technical work required to generate them from existing platform data.

## Overview

Industry Night generates three categories of data product, each building on the previous:

1. **Post-Event Sponsor Report** — delivered to each sponsor after every event
2. **Verified Audience Access** — perk/discount distribution with redemption tracking
3. **Market Intelligence Brief** — quarterly derived insights, graph analytics, cohort analysis

None of these products expose raw database records. All deliverables are aggregated, anonymized, and derived. Sponsors never receive user PII, contact lists, or individual-level data.

---

## Product 1: Post-Event Sponsor Report

### What it is

A branded PDF delivered to each event sponsor within 48 hours of an event. Contains attendance metrics, demographic breakdown, networking activity, and event photography.

### Report contents

| Section | Data source | Status |
|---------|-------------|--------|
| Event summary (name, date, venue) | `events` table | **Available now** |
| Total attendance | `tickets` + `posh_orders` (count by event_id) | **Available now** |
| Demographic breakdown by specialty | `users.specialties[]` joined via `tickets.user_id` | **Available now** |
| Connections made at event | `connections` WHERE `event_id` = target | **Available now** |
| Avg connections per attendee | connections_count / attendee_count | **Available now** |
| Cross-specialty connection rate | connections joined to both users' specialties | **Available now** |
| Repeat attendee rate | users with tickets to >1 event prior to this one | **Available now** |
| Sponsor visibility (logo shown, tier) | `event_sponsors` + `sponsors` | **Available now** |
| Event photography | External (uploaded by ops team post-event) | **Manual process** |

### What needs to be built

#### 1. Report generation API endpoint

New endpoint: `GET /admin/reports/event/:eventId/sponsor/:sponsorId`

Returns JSON with all computed metrics for the report. The admin app (or a script) calls this endpoint, receives structured data, and generates the PDF.

```
Response shape:
{
  event: { name, date, venue_name, venue_address },
  sponsor: { name, tier, logo_url },
  attendance: {
    total: number,
    checked_in: number,
    posh_tickets: number,
    walk_ins: number
  },
  demographics: {
    by_specialty: [{ specialty: string, count: number, percentage: number }],
    verification_breakdown: { verified: number, checked_in: number, new: number }
  },
  networking: {
    total_connections: number,
    avg_per_attendee: number,
    cross_specialty_rate: number,
    top_pairings: [{ specialty_a: string, specialty_b: string, count: number }]
  },
  retention: {
    repeat_attendees: number,
    repeat_rate: number,
    first_timers: number
  }
}
```

#### 2. SQL queries (new file: `packages/api/src/queries/reports.ts`)

Each metric maps to a straightforward query against existing tables:

- **Attendance:** `SELECT COUNT(*) FROM tickets WHERE event_id = $1 AND status = 'checkedIn'` + `SELECT COUNT(*) FROM posh_orders WHERE event_id = $1`
- **Demographics:** Join `tickets` → `users`, unnest `specialties[]`, group by specialty
- **Connections at event:** `SELECT COUNT(*) FROM connections WHERE event_id = $1`
- **Cross-specialty rate:** Join connections to both user_a and user_b specialties, calculate % where specialty_a ≠ specialty_b
- **Repeat rate:** Subquery for users who have tickets to any prior event
- **Top pairings:** Group connections by (specialty_a, specialty_b), order by count desc, limit 5

No schema changes required. All data exists in current tables.

#### 3. PDF generation

Two options:

**Option A: Server-side PDF generation (recommended for MVP)**
- Add `pdfkit` or `puppeteer` to API dependencies
- Create a report template in code
- Endpoint returns PDF binary or S3 URL
- Admin clicks "Generate Report" on event detail screen → downloads PDF

**Option B: Client-side in admin app**
- Admin app fetches JSON from report endpoint
- Generates PDF using `pdf` package in Flutter
- More complex, but keeps API stateless

**Recommendation:** Option A. Server-side is simpler, and reports are an operational artifact — they don't need to render in the Flutter UI.

#### 4. Admin app integration

- Add "Reports" tab or section to `event_detail_screen.dart`
- Show list of sponsors for the event
- "Generate Report" button per sponsor → calls endpoint → downloads PDF
- Optional: "Generate All" to batch-generate for all sponsors on an event

#### 5. Event photography handling

Reports should include 2-4 event photos. Options:

- **Simple:** Admin uploads "report photos" (separate from event_images used in the social app) via a new upload field on the event detail screen. Stored in S3 under `reports/{event_id}/`.
- **Simpler:** Reuse existing `event_images` — the hero image and top 3 by sort_order are included automatically.

**Recommendation:** Reuse `event_images` for MVP. Add dedicated report image uploads later if sponsors want curated photos.

### Implementation estimate

| Task | Effort |
|------|--------|
| Report queries (`queries/reports.ts`) | 4-6 hours |
| Report API endpoint | 2-3 hours |
| PDF template + generation | 6-8 hours |
| Admin app UI (generate/download) | 4-6 hours |
| **Total** | **16-23 hours** |

---

## Product 2: Verified Audience Access (Redemption Tracking)

### What it is

Sponsors provide discount codes or perks. Industry Night delivers them exclusively to verified attendees via the app. The system tracks engagement (views, taps, self-reported usage) and includes this data in sponsor reports.

### Current state

The `discounts` table already stores sponsor perks with codes, types, values, and date ranges. The `sponsors` table has tiers. The social app has a perks screen (currently hardcoded/stub). The data model is mostly in place.

### What needs to be built

#### 1. New table: `discount_impressions`

Tracks when a verified user views or engages with a perk.

```sql
CREATE TABLE discount_impressions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    discount_id UUID NOT NULL REFERENCES discounts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    event_id UUID REFERENCES events(id) ON DELETE SET NULL,
    action VARCHAR(20) NOT NULL,  -- 'viewed', 'copied_code', 'self_reported_used'
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_discount_imp_discount ON discount_impressions(discount_id);
CREATE INDEX idx_discount_imp_user ON discount_impressions(user_id);
CREATE INDEX idx_discount_imp_action ON discount_impressions(action);
```

This is the attribution layer. It answers: "How many verified professionals saw this perk? How many copied the code? How many said they used it?"

#### 2. API endpoints for perk engagement

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/perks` | List active perks for verified user (requires verification gating) |
| `POST` | `/perks/:discountId/impression` | Record view, code copy, or self-reported usage |
| `GET` | `/admin/reports/sponsor/:sponsorId/perks` | Aggregated perk performance for sponsor report |

#### 3. Wire up social app perks screen

- Replace hardcoded data with real API calls
- When user taps "Copy Code" → POST impression with action `copied_code`
- Add "I Used This" button → POST impression with action `self_reported_used`
- Gate access behind `verification_status = 'verified'` (requires Issue #14 — API-level verification gating)

#### 4. Perk performance in sponsor reports

Add a new section to the Post-Event Sponsor Report:

```
Perk Performance:
  - "20% Off All Services" (code: INDUSTRY20)
    - Views: 142
    - Code copies: 67
    - Self-reported uses: 23
    - Engagement rate: 47% (copies / views)
```

Also support a standalone perk report across events:

`GET /admin/reports/sponsor/:sponsorId/perks?from=2026-01-01&to=2026-03-31`

Returns aggregated perk metrics for a date range, suitable for quarterly sponsor reviews.

#### 5. Unique codes per event (phase 2)

For stronger attribution, generate event-specific discount codes:

- Sponsor provides base offer (e.g., "20% off")
- System generates unique code per event (e.g., `IN-APR25-20OFF`)
- Sponsor configures their POS/e-commerce to accept these codes
- At quarter end, sponsor shares redemption counts per code
- System correlates with self-reported data for calibration

This doesn't require schema changes — just an operational process and a `source_event_id` field on `discounts` to track which event a code was created for.

### Dependencies

- **Issue #14 (P1):** API-level verification gating. Without this, unverified users can access perks, which destroys the value proposition to sponsors ("verified professionals only").
- **Perks screen wiring:** Social app stub needs to call real endpoints.

### Implementation estimate

| Task | Effort |
|------|--------|
| Migration: `discount_impressions` table | 1 hour |
| Perk engagement API endpoints | 4-6 hours |
| Admin perk performance endpoint | 3-4 hours |
| Social app perks screen wiring | 6-8 hours |
| Verification gating middleware (Issue #14) | 4-6 hours |
| Integrate perk data into sponsor report | 2-3 hours |
| **Total** | **20-28 hours** |

---

## Product 3: Market Intelligence Brief

### What it is

A quarterly PDF report containing derived insights about the creative professional community. Graph analytics (clustering, cohort affinity), growth trends, specialty dynamics, and networking patterns. No raw data is shared — only aggregated analysis and visualizations.

### Brief contents

| Section | What it shows | Data source |
|---------|---------------|-------------|
| Executive summary | Key trends, notable shifts | Derived from all below |
| Community growth | Total members, growth rate, new vs returning | `analytics_users_daily` |
| Specialty landscape | Distribution, fastest-growing segments, emerging specialties | `users.specialties[]` over time |
| Networking patterns | Avg connections per event, connection velocity trends | `analytics_events` + `analytics_connections_daily` |
| Cohort affinity matrix | Which specialties connect with which, and at what rate | `connections` joined to user specialties (aggregated) |
| Cluster analysis | Natural community groupings, bridge nodes | Graph analysis on `connections` table |
| Influence topology | Most-connected professionals by specialty (anonymized), network hubs | `analytics_influence` (anonymized — no names, just specialty + rank) |
| Event benchmarks | Attendance trends, per-event networking intensity | `analytics_events` time series |
| Emerging signals | Qualitative observations, early pattern detection | Editorial (human-written, data-informed) |

### What needs to be built

#### 1. Analytics computation jobs

The four `analytics_*` tables exist but are empty. We need scheduled jobs to populate them.

**Job 1: `compute_event_analytics`** — runs after each event completes
```
For event_id:
  - Count check-ins (tickets WHERE status = 'checkedIn')
  - Count unique attendees
  - Count connections made
  - Compute top specialties (join tickets → users, unnest specialties, group)
  - Compute avg connections per user
  - Compute cross-specialty rate
  - UPSERT into analytics_events
```

**Job 2: `compute_daily_analytics`** — runs nightly (or on-demand)
```
For each day:
  - Count new users by specialty and city
  - Count active users (made a connection or checked in)
  - Count verified users
  - Count check-ins
  - UPSERT into analytics_users_daily

  - Count connections by specialty pairing
  - UPSERT into analytics_connections_daily
```

**Job 3: `compute_influence_scores`** — runs weekly
```
For each user:
  - connection_count: COUNT connections
  - events_attended: COUNT tickets with checkedIn status
  - network_reach: COUNT distinct 2nd-degree connections
  - specialty_rank: RANK within their primary specialty
  - city_rank: RANK within their city (when market_area is added)
  - influence_score: weighted composite
  - UPSERT into analytics_influence
```

**Job 4: `compute_graph_analytics`** — runs quarterly (or on-demand for briefs)
```
  - Build adjacency list from connections table
  - Run community detection (Louvain or label propagation)
  - Identify bridge nodes (high betweenness centrality)
  - Compute cohort affinity matrix (specialty × specialty connection rates)
  - Output: JSON artifacts stored in S3 or a new analytics_graph_snapshots table
```

#### 2. New table: `analytics_graph_snapshots`

```sql
CREATE TABLE analytics_graph_snapshots (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    snapshot_date DATE NOT NULL,
    snapshot_type VARCHAR(50) NOT NULL,  -- 'clusters', 'affinity_matrix', 'bridge_nodes'
    data JSONB NOT NULL,
    metadata JSONB,  -- { node_count, edge_count, algorithm, parameters }
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_graph_snapshots_date ON analytics_graph_snapshots(snapshot_date DESC);
CREATE INDEX idx_graph_snapshots_type ON analytics_graph_snapshots(snapshot_type);
```

#### 3. Graph analytics implementation

Two approaches:

**Option A: In-process Node.js (recommended for MVP)**
- Use `graphology` npm package for graph construction and algorithms
- Community detection via Louvain (available in `graphology-communities-louvain`)
- Betweenness centrality via `graphology-metrics`
- Load connections into memory, compute, store results
- Works fine up to ~50K edges (plenty for early stage)

**Option B: External graph database (future scale)**
- Export connections to Neo4j or AWS Neptune
- Run Cypher queries for complex graph patterns
- Overkill until community exceeds 10K+ active users

#### 4. Brief generation

Unlike the per-event sponsor report, the brief is a higher-touch deliverable:

- Computation layer produces all the metrics and graph artifacts
- A report template assembles them into a structured document
- The "Emerging Signals" section is editorial — written by the ops team informed by the data
- Brief is generated as PDF, branded, and delivered to intelligence subscribers

**Generation endpoint:** `GET /admin/reports/intelligence?quarter=2026-Q1`

Returns structured JSON with all computed metrics. A separate PDF generation step (same infrastructure as Product 1) renders the final document.

#### 5. Customization layer (for premium/exclusive briefs)

For category-exclusive versions:

- Filter the cohort affinity data to highlight the sponsor's relevant specialties
- Add a "Your Category" section with targeted insights
- Same underlying data, different lens per sponsor

This is a presentation layer concern, not a data computation concern. The same quarterly computation serves all versions of the brief.

### Implementation estimate

| Task | Effort |
|------|--------|
| Event analytics job | 4-6 hours |
| Daily analytics job | 4-6 hours |
| Influence scoring job | 6-8 hours |
| Graph analytics (clustering, affinity) | 8-12 hours |
| Graph snapshots migration + storage | 2-3 hours |
| Intelligence report endpoint | 4-6 hours |
| Brief PDF template + generation | 8-12 hours |
| Admin UI for report generation | 4-6 hours |
| **Total** | **40-59 hours** |

---

## Schema Changes Summary

All changes are additive (no modifications to existing tables):

| Migration | Table | Purpose |
|-----------|-------|---------|
| `002_discount_impressions.sql` | `discount_impressions` | Track perk views, code copies, self-reported usage |
| `003_graph_snapshots.sql` | `analytics_graph_snapshots` | Store quarterly graph analysis results |
| `004_generated_reports.sql` | `generated_reports` | Store AI-generated report data, narratives, and output files |

Optional future additions:
- `discounts.source_event_id` — link event-specific discount codes to their origin event
- `users.market_area` — enable geographic segmentation (Issue #19)
- `report_images` table — if dedicated report photography is needed separate from event_images

---

## API Endpoints Summary

### Report generation endpoints (all require `authenticateAdmin`)

| Method | Path | Product | Description |
|--------|------|---------|-------------|
| `GET` | `/admin/reports/event/:eventId` | P1 | Event metrics (all sponsors) |
| `GET` | `/admin/reports/event/:eventId/sponsor/:sponsorId` | P1 | Event metrics for specific sponsor |
| `GET` | `/admin/reports/event/:eventId/pdf` | P1 | Generate sponsor report PDF |
| `GET` | `/admin/reports/sponsor/:sponsorId/perks` | P2 | Perk performance over date range |
| `GET` | `/admin/reports/intelligence` | P3 | Quarterly intelligence brief data |
| `GET` | `/admin/reports/intelligence/pdf` | P3 | Generate intelligence brief PDF |

### Perk engagement endpoints (require `authenticate` + verified status)

| Method | Path | Product | Description |
|--------|------|---------|-------------|
| `GET` | `/perks` | P2 | List active perks for verified user |
| `POST` | `/perks/:discountId/impression` | P2 | Record view/copy/usage |

### Computation job triggers (require `authenticateAdmin`)

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/admin/analytics/compute/event/:eventId` | Compute event analytics |
| `POST` | `/admin/analytics/compute/daily` | Run daily analytics |
| `POST` | `/admin/analytics/compute/influence` | Recompute influence scores |
| `POST` | `/admin/analytics/compute/graph` | Run graph analytics |

---

## Implementation Priority

### Phase 1: Post-Event Sponsor Report (Product 1)
**Why first:** Can sell immediately. No schema changes. All data exists. Highest ROI per hour invested.

Sequence:
1. Build report queries (`queries/reports.ts`)
2. Build report API endpoint
3. Build PDF generation
4. Add admin UI for generation/download
5. **Generate first real report from an actual event and iterate**

### Phase 2: Redemption Tracking (Product 2)
**Why second:** Unlocks 5-10x sponsor pricing. Requires schema migration + Issue #14.

Sequence:
1. Create `discount_impressions` migration
2. Build perk engagement endpoints
3. Wire social app perks screen
4. Implement verification gating (Issue #14)
5. Integrate perk data into sponsor report template

### Phase 3: Market Intelligence (Product 3)
**Why third:** Highest revenue potential but requires community scale to be meaningful. Start computing early, sell when data is rich enough.

Sequence:
1. Build event analytics computation job (run after each event)
2. Build daily analytics job
3. Build influence scoring
4. Build graph analytics (clustering, affinity)
5. Build intelligence brief template + PDF generation

---

## Privacy & Data Ethics

### Principles

1. **No PII in reports.** Sponsor reports contain aggregate counts and percentages, never names, phone numbers, or individual profiles.
2. **No contact lists.** Sponsors reach users through the IN platform (perks, visibility). They never receive email lists or phone numbers.
3. **Consent-gated analytics.** The `analytics_consent` flag on users controls inclusion in analytics computation. Users who opt out are excluded from all aggregate calculations.
4. **Anonymized influence data.** Intelligence briefs reference "the most connected photographer in NYC" or "top 10 MUAs by network reach" — never by name. Sponsors see specialty + rank, not identity.
5. **Managed channel only.** The value proposition to sponsors is access through IN, not access to IN's data. The platform is the intermediary. This protects users and creates ongoing dependency (sponsors must stay subscribed to maintain access).

### Consent implementation

- `analytics_consent` is already in the `users` schema (defaults to `false`)
- All analytics queries must include `WHERE analytics_consent = true`
- Onboarding flow should explain and request consent
- Settings screen should allow toggling at any time
- Opting out removes user from future computations; does not retroactively remove from historical aggregates (aggregates are anonymous and can't be disaggregated)

---

## AI-Powered Report Generation

### Architecture

Reports are generated through a two-layer pipeline: a **deterministic data layer** that computes metrics from SQL, and a **generative narrative layer** that synthesizes those metrics into human-readable insight. The data layer ensures numbers are always correct. The narrative layer interprets them.

```
┌─────────────────────────────────────────────────────────────────┐
│                     REPORT GENERATION PIPELINE                  │
│                                                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────┐   │
│  │  SQL Queries  │───▶│ Structured   │───▶│  LLM Narrative   │   │
│  │  (reports.ts) │    │ JSON Payload │    │  Generation      │   │
│  └──────────────┘    └──────────────┘    └────────┬─────────┘   │
│                                                    │             │
│  ┌──────────────┐    ┌──────────────┐    ┌────────▼─────────┐   │
│  │  Report       │───▶│ Merge Data + │───▶│  Final PDF/DOCX  │   │
│  │  Template     │    │ Narrative    │    │  Deliverable     │   │
│  └──────────────┘    └──────────────┘    └──────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### What the LLM generates vs. what stays deterministic

| Report section | Source | Why |
|----------------|--------|-----|
| KPI numbers (attendance, connections, rates) | **Deterministic** (SQL) | Numbers must be exact. No hallucination risk. |
| Demographic tables, affinity matrix | **Deterministic** (SQL) | Structured data rendered from queries. |
| Executive summary | **LLM-generated** | Synthesizes key findings into narrative. |
| "What This Means for Your Brand" | **LLM-generated** | Contextualizes data for the specific sponsor's category. |
| Emerging Signals | **LLM-generated** | Identifies patterns across the dataset that may not be obvious from individual metrics. |
| Event-over-event comparisons | **LLM-generated** | Notices anomalies, trends, and context-specific observations. |
| Perk performance interpretation | **LLM-generated** | Translates engagement rates into actionable sponsor recommendations. |
| Methodology, disclaimers, footer | **Deterministic** (template) | Boilerplate that doesn't change. |

### How it works

#### Step 1: Data computation (existing pipeline)

The report endpoint computes structured JSON from SQL queries. This is the same endpoint described in Products 1-3 above. Example payload:

```json
{
  "event": { "name": "IN NYC — April 2026", "date": "2026-04-17", ... },
  "sponsor": { "name": "Olaplex Professional", "tier": "gold", "category": "hair care" },
  "attendance": { "total": 247, "checked_in": 231, ... },
  "demographics": { "by_specialty": [...] },
  "networking": { "total_connections": 487, "cross_specialty_rate": 0.67, "top_pairings": [...] },
  "retention": { "repeat_rate": 35.5, ... },
  "perk_performance": { "views": 142, "code_copies": 67, ... },
  "historical_comparison": {
    "prev_event": { "attendance": 218, "connections": 445, ... },
    "quarterly_avg": { "attendance": 213, "connections": 422, ... }
  }
}
```

#### Step 2: LLM narrative generation

The structured JSON is sent to Claude (Opus or Sonnet) with a system prompt that defines:

1. **Report format** — section structure, tone, length constraints
2. **Sponsor context** — the sponsor's category, tier, what they care about
3. **Analytical directives** — what kinds of insights to look for

```
System prompt structure:

You are generating the narrative sections of a post-event sponsor report
for Industry Night, a verified networking platform for creative professionals.

SPONSOR CONTEXT:
- Name: {sponsor.name}
- Category: {sponsor.category}
- Tier: {sponsor.tier}
- Previous events sponsored: {sponsor.history}

SECTIONS TO GENERATE:
1. Executive Summary (2-3 sentences, lead with the most relevant finding
   for this sponsor's category)
2. What This Means for Your Brand (3 paragraphs, connect the data to
   the sponsor's specific business interests)
3. Notable Observations (2-3 bullet points highlighting anything unusual
   compared to historical averages)

RULES:
- Never invent or modify numbers. Only reference data present in the payload.
- Emphasize metrics relevant to the sponsor's category.
- Flag anomalies (values >20% above/below historical average).
- Tone: professional, insight-driven, concise. Not salesy.
- If the sponsor's category aligns with a top specialty pairing, lead with that.

DATA PAYLOAD:
{json_payload}
```

#### Step 3: Template merge

The deterministic template sections (KPIs, tables, charts) are generated from the raw data. The LLM-generated narrative sections are inserted into designated slots in the document template. The final document is rendered as PDF/DOCX.

### Why this is better than static templates

| Static template | AI-generated narrative |
|-----------------|----------------------|
| "67% of connections were cross-specialty" | "Hair stylists connected with MUAs at 3.1x the baseline rate — your brand reached both segments through organic professional word-of-mouth" |
| "Attendance: 247" | "Attendance hit 247, up 13% from last month and the highest since the platform launched. The growth was driven by a 47% surge in nail technicians." |
| Same text every report, sponsor ignores it | Each report reads like a custom briefing, sponsor shares it internally |
| "Emerging Signals" section left blank or manually written | LLM identifies that a new cluster is forming, or that a pairing is accelerating, from patterns in the data |

The key insight: **the same underlying data tells a different story to a hair care brand than it does to a camera manufacturer.** The AI tailors the narrative to the audience without anyone manually rewriting each report.

### For the Intelligence Brief specifically

The intelligence brief benefits even more from AI generation because its highest-value section — Emerging Signals — is inherently interpretive. The LLM receives:

- Current quarter's computed analytics (growth, affinity matrix, clusters, influence scores)
- Previous quarter's analytics (for trend detection)
- The graph snapshot data (cluster composition, bridge nodes, betweenness centrality)

With this context, it can surface observations like:

- "A new cluster (F) has formed around nail and lash technicians that didn't exist in Q4. It's the fastest-growing cluster and is beginning to bridge into the Hair/MUA cluster (A) through shared attendance at Brooklyn events."
- "The photographer/videographer segment is punching above its weight in influence: despite being 14% of the community, they hold 3 of the top 10 influence positions, because their cross-specialty connection rate (72%) makes them network bridges."
- "Repeat attendees are now making 40% more connections per event than first-timers. This power-user effect suggests that tenure-based tiers or loyalty features could amplify the most engaged members."

These are observations a human analyst would eventually reach, but the LLM produces them in seconds from the structured data.

### Customization per sponsor

The same quarterly data supports multiple sponsor-specific briefs by varying the system prompt:

- **Hair care brand:** "Emphasize hair stylist segment trends, Hair ↔ MUA affinity, influence rankings within hair specialty, and growth in beauty-adjacent segments that overlap with hair services."
- **Camera manufacturer:** "Emphasize photographer and videographer segments, Photo ↔ Model and Photo ↔ Video affinities, content creator cluster analysis, and cross-specialty bridge effects."
- **Beauty supply distributor:** "Emphasize full beauty spectrum trends (hair + nails + lash + MUA), cluster convergence across beauty segments, and geographic expansion signals for new retail locations."

Same data, same computation cost, different narrative lens. Each sponsor receives a brief that feels written for them, because it was.

### Implementation

| Component | Technology | Notes |
|-----------|-----------|-------|
| LLM API client | Anthropic SDK (`@anthropic-ai/sdk`) | Already a Node.js project; SDK is a natural fit |
| Model selection | Claude Sonnet for sponsor reports, Claude Opus for intelligence briefs | Sonnet is fast and cheap enough for per-event reports; Opus for the higher-value quarterly briefs |
| Prompt templates | Stored in `packages/api/src/prompts/` | Version-controlled, iterable |
| Caching | Cache LLM output keyed by (event_id, sponsor_id, data_hash) | Avoid re-generating if data hasn't changed |
| Fallback | If LLM call fails, render report with data-only sections (no narrative) | Report still valuable without prose; never block delivery on LLM availability |
| Cost estimate | ~$0.10-0.30 per sponsor report, ~$1-3 per intelligence brief | Based on Sonnet/Opus input/output token pricing for structured data + narrative |

### New API endpoints

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/admin/reports/event/:eventId/sponsor/:sponsorId/generate` | Generate AI-narrated sponsor report |
| `POST` | `/admin/reports/intelligence/generate` | Generate AI-narrated intelligence brief |
| `GET` | `/admin/reports/generated/:reportId` | Retrieve a previously generated report |
| `GET` | `/admin/reports/generated` | List all generated reports (with status, date, type) |

### New table: `generated_reports`

```sql
CREATE TABLE generated_reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    report_type VARCHAR(50) NOT NULL,  -- 'sponsor_event', 'intelligence_brief'
    event_id UUID REFERENCES events(id) ON DELETE SET NULL,
    sponsor_id UUID REFERENCES sponsors(id) ON DELETE SET NULL,
    quarter VARCHAR(7),  -- '2026-Q1' for intelligence briefs
    data_payload JSONB NOT NULL,  -- the structured data sent to the LLM
    narrative_sections JSONB NOT NULL,  -- the LLM-generated text, by section
    model_used VARCHAR(100),  -- 'claude-sonnet-4-5-20250929'
    file_url TEXT,  -- S3 URL of generated PDF/DOCX
    status VARCHAR(20) NOT NULL DEFAULT 'generating',  -- 'generating', 'completed', 'failed'
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    generated_by UUID REFERENCES admin_users(id) ON DELETE SET NULL
);

CREATE INDEX idx_generated_reports_type ON generated_reports(report_type);
CREATE INDEX idx_generated_reports_event ON generated_reports(event_id);
CREATE INDEX idx_generated_reports_sponsor ON generated_reports(sponsor_id);
CREATE INDEX idx_generated_reports_status ON generated_reports(status);
```

This stores both the input data and the generated narrative, enabling:
- Re-rendering without re-calling the LLM (if template changes)
- Audit trail of what data produced what narrative
- Regeneration with a different model or prompt version
- A/B testing different prompt strategies

### Admin app workflow

1. Admin navigates to event detail screen → "Reports" tab
2. Sees list of sponsors for this event
3. Clicks "Generate Report" for a sponsor
4. System computes data payload → calls LLM → merges into template → stores PDF
5. Status shows "Generating..." → "Ready" (typically 10-30 seconds)
6. Admin can preview, download, or regenerate with "Regenerate" button
7. For intelligence briefs: similar flow from a "Market Intelligence" section in the admin dashboard

### Implementation estimate (additive to base report generation)

| Task | Effort |
|------|--------|
| Anthropic SDK integration + prompt templates | 4-6 hours |
| LLM narrative generation service | 6-8 hours |
| `generated_reports` migration | 1 hour |
| Template merge (data + narrative → PDF) | 4-6 hours |
| Admin UI for generate/preview/download | 6-8 hours |
| Prompt iteration and quality tuning | 8-12 hours |
| **Total (AI layer)** | **29-41 hours** |

This is additive to the base report generation estimates. The AI layer depends on the data computation layer being built first.

### Updated schema changes summary

| Migration | Table | Purpose |
|-----------|-------|---------|
| `002_discount_impressions.sql` | `discount_impressions` | Track perk views, code copies, self-reported usage |
| `003_graph_snapshots.sql` | `analytics_graph_snapshots` | Store quarterly graph analysis results |
| `004_generated_reports.sql` | `generated_reports` | Store AI-generated report data, narratives, and files |

---

## Test Data Generation

### Why this matters

The report generation pipeline, analytics computation jobs, graph analytics, and AI narrative generation all need realistic data to develop against. The current `dev_seed.sql` creates 4 users, 2 events, 1 connection, and 2 sponsors — far too thin to test demographic breakdowns, affinity matrices, cluster detection, or trend analysis. We need a data generation system that produces realistic community-scale data with the statistical properties that make reports interesting.

### What needs to be generated

| Entity | Target volume | Key properties |
|--------|--------------|----------------|
| Users | 500-1,000 | Realistic specialty distribution (weighted toward hair/MUA), varied verification statuses, consent flags, created_at spread over 6+ months |
| Events | 20-30 | Spread across 6 months, mix of statuses (completed, published, draft), varying capacities (100-300), different venues |
| Event images | 2-4 per event | Placeholder URLs (S3 or local), hero image (sort_order 0) per event |
| Tickets | 150-250 per event | Linked to users with specialty-weighted attendance (hair stylists over-represented at beauty-focused events), mix of checkedIn/purchased statuses |
| Connections | 400-600 per event | Specialty-affinity-weighted (Hair↔MUA at 3x, Photo↔Model at 2.5x, etc.), only between users who attended the same event |
| Sponsors | 8-12 | Across tiers (bronze through platinum), varied categories |
| Event-sponsor links | 2-4 per event | Linked to completed/published events |
| Discounts | 1-3 per sponsor | Active codes, varied types (percentage, fixedAmount, freeItem) |
| Discount impressions | 50-200 per event-sponsor pair | Funnel: views > code_copies > self_reported_used (realistic drop-off ratios) |
| Posts | 100-200 | Authored by verified users, spread over time, mix of types |
| Post comments/likes | 2-5 per post | From connected users (realistic — you engage with people you know) |
| Posh orders | 100-180 per event | Some linked to user accounts, some orphaned (simulates pre-registration buyers) |

### Specialty distribution (weighted)

Based on realistic NYC creative community composition:

```
hair_stylist:       25-30%
makeup_artist:      18-22%
photographer:       12-15%
nail_tech:           8-10%
videographer:        6-8%
model:               5-7%
barber:              3-5%
stylist:             3-4%
producer:            2-3%
all others:          5-10% (long tail)
```

### Connection affinity weights

Connections should follow realistic affinity patterns. When generating connections at an event, the probability of two attendees connecting is weighted by their specialty pairing:

```
hair_stylist ↔ makeup_artist:   3.0x baseline
photographer ↔ model:           2.5x baseline
hair_stylist ↔ photographer:    1.8x baseline
photographer ↔ videographer:    1.6x baseline
makeup_artist ↔ nail_tech:      1.6x baseline
makeup_artist ↔ model:          1.4x baseline
hair_stylist ↔ nail_tech:       1.4x baseline
videographer ↔ model:           1.3x baseline
same specialty ↔ same:          1.2x baseline (peer networking)
all other pairings:             1.0x baseline
```

This ensures that when we run affinity analysis on the generated data, the matrix shows realistic patterns rather than uniform noise.

### Temporal patterns

Data should exhibit realistic time-series properties:

- **Community growth:** 15-25% month-over-month new user registration, accelerating slightly over time
- **Seasonal attendance:** Higher in spring/fall, slight dip in summer and holidays
- **Repeat attendance:** ~30-35% of attendees at any event have attended a prior event; repeat rate increases over time
- **Connection velocity:** Average connections per attendee increases slightly over time (3.2 → 4.5 over 6 months) as the community matures
- **Specialty growth rates:** Nail tech and lash growing fastest (+40-50% QoQ), hair/MUA steady (+15-20%), photo stable (+10-12%)

### Implementation: `scripts/generate-test-data.js`

A standalone Node.js script (using `pg` from `packages/api/node_modules`, same as other db scripts) that:

1. Accepts parameters: `--users 800 --events 24 --months 6 --env dev`
2. Generates all entities with realistic distributions and relationships
3. Inserts directly into the database (runs after `migrate.js`, before or instead of `dev_seed.sql`)
4. Is idempotent — can be re-run after `db-reset.js`
5. Populates the analytics tables too (runs the computation logic after inserting raw data)
6. Outputs a summary: "Generated 800 users, 24 events, 4,821 connections, 12 sponsors..."

```bash
# Usage
DB_PASSWORD=xxx node scripts/generate-test-data.js --users 800 --events 24 --months 6

# Quick smoke test (small dataset)
DB_PASSWORD=xxx node scripts/generate-test-data.js --users 50 --events 3 --months 1

# Full dataset for report testing
DB_PASSWORD=xxx node scripts/generate-test-data.js --users 1000 --events 30 --months 9
```

### Data generation sequence

Order matters due to foreign key constraints:

```
1. specialties (reference data — already seeded)
2. admin_users (1 dev admin)
3. users (weighted specialty distribution, staggered created_at)
4. events (spread across date range, varied venues/statuses)
5. event_images (placeholder URLs, hero per event)
6. sponsors + discounts
7. event_sponsors (link sponsors to events)
8. tickets (specialty-weighted attendance per event)
9. posh_orders (subset of ticket holders + some unlinked)
10. connections (affinity-weighted, only between co-attendees)
11. discount_impressions (funnel: view → copy → use)
12. posts + comments + likes (from verified users)
13. analytics_events (computed from generated tickets + connections)
14. analytics_users_daily (computed from generated users + tickets)
15. analytics_connections_daily (computed from generated connections)
16. analytics_influence (computed from generated connections + tickets)
17. analytics_graph_snapshots (computed from connection graph)
```

Steps 13-17 simulate running the analytics computation jobs, so the full report pipeline can be tested end-to-end without needing to implement the jobs first.

### Deterministic seed option

For reproducible testing, support `--seed 12345` which seeds the random number generator. Same seed = same dataset every time. This is important for:
- Comparing report output across code changes (same input data)
- Debugging specific data scenarios
- CI/CD test fixtures

### Implementation estimate

| Task | Effort |
|------|--------|
| Core generator (users, events, tickets, connections) | 8-12 hours |
| Affinity-weighted connection generation | 4-6 hours |
| Analytics table population | 4-6 hours |
| Graph snapshot generation | 3-4 hours |
| Discount impressions + posts/comments | 3-4 hours |
| Testing + parameter tuning | 4-6 hours |
| **Total** | **26-38 hours** |

---

## App Instrumentation Plan

### Why this matters

The current app tracks almost nothing about user behavior. We know *that* someone checked in and *that* they made a connection, but we don't know what they looked at, how long they spent on screens, what they tapped, or how they navigated. Without instrumentation, the report pipeline is limited to transactional data (tickets, connections, perks). With it, we can tell sponsors things like "142 verified professionals viewed your perk, and they spent an average of 8 seconds on the perk detail screen" or "the community feed generates 12 minutes of engagement per user per week."

This data also feeds the AI narrative layer — the LLM can write much richer insights from behavioral data than from transaction counts alone.

### Instrumentation architecture

#### Event tracking service

A lightweight client-side service in the shared package that queues behavioral events and batch-sends them to the API.

**New file: `packages/shared/lib/services/analytics_service.dart`**

```dart
class AnalyticsService {
  final ApiClient _client;
  final List<AnalyticsEvent> _queue = [];
  Timer? _flushTimer;

  // Core tracking method
  void track(String eventName, {Map<String, dynamic>? properties});

  // Convenience methods
  void trackScreenView(String screenName, {String? referrer});
  void trackTap(String element, {String? screen, Map<String, dynamic>? context});
  void trackScroll(String screen, {double depth = 0});
  void trackDuration(String screen, Duration duration);

  // Flush queue to API (batch send every 30 seconds or on app background)
  Future<void> flush();
}
```

#### Event payload structure

```json
{
  "events": [
    {
      "name": "screen_view",
      "timestamp": "2026-04-17T22:14:33Z",
      "properties": {
        "screen": "perk_detail",
        "sponsor_id": "uuid",
        "discount_id": "uuid",
        "referrer": "perks_list"
      }
    },
    {
      "name": "perk_code_copy",
      "timestamp": "2026-04-17T22:14:41Z",
      "properties": {
        "discount_id": "uuid",
        "sponsor_id": "uuid",
        "code": "INOLAPLEX20",
        "time_on_screen_ms": 8200
      }
    }
  ]
}
```

#### Backend ingestion

**New endpoint: `POST /analytics/events`** (requires `authenticate`)

Accepts a batch of events, validates, and writes to a new `user_events` table (high-write, append-only):

```sql
CREATE TABLE user_analytics_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    event_name VARCHAR(100) NOT NULL,
    properties JSONB,
    screen VARCHAR(100),
    session_id UUID,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_user_analytics_name ON user_analytics_events(event_name);
CREATE INDEX idx_user_analytics_user ON user_analytics_events(user_id);
CREATE INDEX idx_user_analytics_screen ON user_analytics_events(screen);
CREATE INDEX idx_user_analytics_created ON user_analytics_events(created_at DESC);

-- Partition by month for performance at scale (optional, add when needed)
```

This table grows fast. Plan for retention policy: aggregate after 90 days, purge raw events after 180 days. The aggregated data feeds into the existing analytics tables.

### What to track: Social App

#### Tier 1: Track immediately (feeds directly into sponsor reports)

| Event name | Screen | Properties | Report value |
|------------|--------|------------|--------------|
| `screen_view` | `perks_list` | `event_id` | "X users browsed sponsor perks" |
| `screen_view` | `perk_detail` | `sponsor_id`, `discount_id` | "X users viewed your specific perk" |
| `perk_code_copy` | `perk_detail` | `discount_id`, `code` | "X users copied your discount code" |
| `perk_self_report_used` | `perk_detail` | `discount_id` | "X users reported using your offer" |
| `screen_view` | `sponsor_detail` | `sponsor_id` | "X users viewed your sponsor profile" |
| `sponsor_link_tap` | `sponsor_detail` | `sponsor_id`, `link_type` (website/instagram/etc) | "X users clicked through to your website" |
| `event_checkin` | `activation_code` | `event_id`, `method` (qr/manual) | Already tracked via tickets, but adds method detail |
| `qr_scan` | `qr_scanner` | `event_id`, `target_user_id` | Connection initiation (enriches connection data) |

#### Tier 2: Track next (feeds into engagement metrics and intelligence briefs)

| Event name | Screen | Properties | Report value |
|------------|--------|------------|--------------|
| `screen_view` | `event_detail` | `event_id`, `referrer` | Event interest / discovery patterns |
| `screen_view` | `event_list` | `filter`, `sort` | What users are looking for |
| `screen_view` | `community_feed` | `session_count` | Feed engagement frequency |
| `post_view` | `post_detail` | `post_id`, `post_type` | Content engagement by type |
| `post_create` | `create_post` | `post_type` | Content creation rate |
| `post_like` | `post_detail` or `feed` | `post_id` | Already tracked in posts table, adds context |
| `comment_create` | `post_detail` | `post_id` | Already tracked, adds context |
| `profile_view` | `user_profile` | `viewed_user_id`, `referrer` | Profile discovery patterns |
| `search_query` | `search` | `query`, `result_count` | What the community is searching for |
| `connection_view` | `connections_list` | `count` | How often users review their network |

#### Tier 3: Track for depth (behavioral intelligence, power user identification)

| Event name | Screen | Properties | Report value |
|------------|--------|------------|--------------|
| `app_open` | — | `session_id`, `source` (push/organic/deep_link) | DAU/MAU, session frequency |
| `app_background` | — | `session_id`, `duration_ms` | Session length |
| `screen_duration` | any | `screen`, `duration_ms` | Time-on-screen per feature |
| `scroll_depth` | `community_feed`, `event_list` | `depth_pct`, `items_seen` | Engagement depth |
| `notification_received` | — | `type`, `shown` | Push delivery rate (when push is implemented) |
| `notification_tap` | — | `type`, `target_screen` | Push engagement rate |
| `qr_code_displayed` | `connect_tab` | `event_id`, `duration_ms` | How long users actively network |
| `tab_switch` | — | `from_tab`, `to_tab` | Navigation patterns |

### What to track: Admin App

| Event name | Screen | Properties | Report value |
|------------|--------|------------|--------------|
| `report_generated` | `event_detail` | `event_id`, `sponsor_id`, `report_type` | Report usage tracking |
| `report_downloaded` | `event_detail` | `report_id` | Delivery confirmation |
| `report_regenerated` | `event_detail` | `report_id`, `reason` | Quality feedback loop |
| `event_published` | `event_form` | `event_id` | Operational metric |
| `image_uploaded` | `event_detail` | `event_id`, `image_count` | Content management |
| `sponsor_linked` | `event_detail` | `event_id`, `sponsor_id` | Sponsor management |

### Implementation in Flutter

#### Where to instrument (code changes)

Each screen gets `AnalyticsService.track()` calls at key interaction points. The changes are lightweight — typically 1-3 lines per screen.

**Pattern for screen views:**
```dart
@override
void initState() {
  super.initState();
  context.read<AppState>().analytics.trackScreenView('perk_detail', referrer: 'perks_list');
}
```

**Pattern for taps:**
```dart
onTap: () {
  context.read<AppState>().analytics.trackTap('copy_code',
    screen: 'perk_detail',
    context: {'discount_id': discount.id, 'sponsor_id': sponsor.id}
  );
  // ... existing tap handler
}
```

**Pattern for duration tracking:**
```dart
final _screenEnteredAt = DateTime.now();

@override
void dispose() {
  final duration = DateTime.now().difference(_screenEnteredAt);
  context.read<AppState>().analytics.trackDuration('perk_detail', duration);
  super.dispose();
}
```

#### Screens to instrument (ordered by report value)

| Priority | Screen file | Events to add |
|----------|------------|---------------|
| **P0** | `perks_screen.dart` | screen_view, perk_tap, code_copy, self_report_used |
| **P0** | `sponsor_detail_screen.dart` | screen_view, link_tap, time_on_screen |
| **P0** | `qr_scanner_screen.dart` | scan_initiated, scan_success, scan_error |
| **P0** | `connect_tab_screen.dart` | screen_view, qr_displayed, qr_display_duration |
| **P1** | `event_detail_screen.dart` | screen_view, checkin_tap, share_tap |
| **P1** | `community_feed_screen.dart` | screen_view, scroll_depth, post_tap |
| **P1** | `post_detail_screen.dart` | screen_view, like_tap, comment_submit |
| **P1** | `search_screen.dart` | search_query, result_tap, no_results |
| **P2** | `user_profile_screen.dart` | screen_view, social_link_tap, connect_tap |
| **P2** | `events_list_screen.dart` | screen_view, event_tap, filter_change |
| **P2** | `my_profile_screen.dart` | screen_view, edit_tap, settings_tap |
| **P2** | `connections_list_screen.dart` | screen_view, connection_tap, connection_delete |

### What this unlocks for reports

With instrumentation, sponsor reports can include:

**Perk engagement funnel:**
```
Perks List Views:       312    (100%)
Your Perk Viewed:       142    (45.5%)
Code Copied:             67    (21.5%)
Self-Reported Used:      23    (7.4%)
Avg Time on Perk:       8.2s
Website Clickthroughs:   18
```

**Sponsor visibility metrics:**
```
Sponsor Profile Views:   89
Website Clicks:          31
Instagram Clicks:        47
Total Brand Touchpoints: 167
```

**Engagement context for intelligence briefs:**
```
Avg Session Duration:        4.2 min (up from 3.1 in Q4)
Avg Feed Scroll Depth:       62% (users see most content)
Most Searched Terms:         "photographer brooklyn", "mua editorial"
Peak Usage Hours:            8-11 PM (event nights), 12-2 PM (lunch browsing)
Posts Per Verified User/Mo:  1.8
Comments Per Post:           3.2
```

The LLM narrative layer gets dramatically richer with this data. Instead of "142 users viewed your perk," it can write "142 verified professionals viewed your perk — spending an average of 8.2 seconds on the detail screen, which is 40% longer than the average perk view time. 18 users clicked through to your website directly from the app, and the highest engagement came from hair stylists (who comprised 52% of your perk viewers despite being 35% of the event attendance)."

### Privacy considerations

- All analytics events are tied to `user_id` and respect `analytics_consent`
- Users with `analytics_consent = false` are excluded from tracking entirely (the `AnalyticsService` checks this flag before queuing events)
- Raw events are never exposed to sponsors — only aggregated metrics
- Retention policy: raw events purged after 180 days, aggregates retained indefinitely
- The `user_analytics_events` table is excluded from GDPR data exports (behavioral telemetry, not personal data) but IS included in `DELETE FROM users` cascade

### Schema changes (additive)

| Migration | Table | Purpose |
|-----------|-------|---------|
| `005_user_analytics_events.sql` | `user_analytics_events` | Behavioral event tracking |

### Implementation estimate

| Task | Effort |
|------|--------|
| `AnalyticsService` in shared package | 4-6 hours |
| Backend ingestion endpoint + table | 3-4 hours |
| P0 screen instrumentation (perks, QR, connect) | 4-6 hours |
| P1 screen instrumentation (events, feed, search) | 4-6 hours |
| P2 screen instrumentation (profile, connections) | 3-4 hours |
| Aggregation queries (for report pipeline) | 4-6 hours |
| Integration with report generation endpoints | 3-4 hours |
| Admin app instrumentation | 2-3 hours |
| **Total** | **27-39 hours** |

---

## Updated Schema Changes Summary

All migrations are additive:

| Migration | Table | Purpose |
|-----------|-------|---------|
| `002_discount_impressions.sql` | `discount_impressions` | Track perk views, code copies, self-reported usage |
| `003_graph_snapshots.sql` | `analytics_graph_snapshots` | Store quarterly graph analysis results |
| `004_generated_reports.sql` | `generated_reports` | Store AI-generated report data, narratives, and files |
| `005_user_analytics_events.sql` | `user_analytics_events` | Behavioral event tracking from app instrumentation |

---

## Revenue Projections (Illustrative)

Assuming 2-3 events/month, 150-300 attendees, 2-3 sponsors per event:

| Product | Price range | Frequency | Annual estimate |
|---------|------------|-----------|-----------------|
| Post-Event Sponsor Report | $500-2,000/event | Per event | $24K-144K |
| Verified Audience Access | $2,000-5,000/event | Per event | $96K-360K |
| Market Intelligence Brief | $5,000-20,000/quarter | Quarterly | $20K-80K |
| **Combined** | | | **$140K-584K** |

The wide ranges reflect early-stage pricing (lower) vs. established platform with proven ROI data (higher). The first year will be at the low end while building case studies.
