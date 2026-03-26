# [Track-E0] Jobs Board Schema + Backend API — Foundation

**Track:** E (Jobs Board)
**Sequence:** 1 of 4 in Track E
**Model:** claude-sonnet-4-6
**Alternate Model:** gpt-5.3-codex ← preferred if running inside OpenAI Codex platform; terminal-first workflow (psql, node scripts, migration verification) is where GPT-5.3-Codex's Terminal-Bench advantage is most tangible
**A/B Test:** No
**Estimated Effort:** Medium (6–8 hours)
**Dependencies:** C0 (Phase 0 schema migrations), C2 (platform_config feature flagging system), X1 (schema consolidation — must be merged before E0 executes; migration numbering depends on X1 output)

## Execution Mode (Required)

- [ ] Stage 1 (required): execute and validate locally first (local Postgres + local API + local admin/mobile against local endpoint).
- [ ] Stage 2 (required for backend/integration-impacting tracks): run shared-dev integration smoke only after local pass.
- [ ] Stage 3 (required before PR merge): run AWS dev deploy/integration smoke for final confidence.
- [ ] Completion log must explicitly record: execution mode used, exact commands run, evidence links, and cleanup actions.


---

## Context

Read these before writing any SQL or TypeScript:

- `docs/codex/EXECUTION_CONTEXT.md` — living operational context: test infrastructure, migration conventions, API ground truth, deployment patterns (read before touching any code)
- `CLAUDE.md` — full project reference (database design, JWT token families, enum types, existing tables)
- `docs/product/master_plan_v2.md` — Section 3.6 "Jobs Board" (feature overview, probation lifecycle, three account types)
- `docs/product/requirements.md` — Jobs Board requirements and acceptance criteria
- `packages/database/migrations/001_baseline_schema.sql` — baseline schema and enum patterns
- `packages/api/src/routes/auth.ts` and `packages/api/src/routes/admin-auth.ts` — existing auth patterns (JWT, tokenFamily, refresh token flow)
- `packages/api/src/middleware/auth.ts` — existing `authenticate` middleware (social user) and `authenticateAdmin` (platform admin); you will create `authenticateJobPoster` following the same pattern
- `packages/api/src/services/email.ts` — email service for welcome emails and application notifications
- Slack notification of accepted applications — use FCM if `fcm_token` exists on job_poster_accounts

---

## Goal

Design and implement the complete database schema for the jobs board feature, plus all backend API endpoints and middleware. E0 is the foundation — E1 (Flutter UI for job search/apply), E2 (hire confirmation + bidirectional ratings), and E3 (job poster portal) all depend on these endpoints, tables, and auth flows existing and working.

The jobs board is a premium feature (product tier). Job posters are businesses who register separately, go through an approval workflow, and have a probationary period after their first job posting. Social users (creative workers) can search, filter, and apply to jobs.

---

## Acceptance Criteria

- [ ] Migration file `NNN_jobs_board.sql` created and applied successfully (use next sequential migration number)
- [ ] All tables exist with correct columns, constraints, indexes, and enum types
- [ ] All enum types created: `job_status`, `job_type`, `compensation_type`, `application_status`
- [ ] Job poster auth middleware `authenticateJobPoster` exists and rejects non-job_poster tokens
- [ ] JWT cross-family token isolation: job_poster tokens rejected by `authenticate` (social) and `authenticateAdmin` (admin)
- [ ] Social job routes (`GET /jobs`, `GET /jobs/:id`, `POST /jobs/:id/apply`, `GET /jobs/my-applications`) exist and are feature-flagged
- [ ] Job poster routes (`GET`, `POST`, `PATCH` jobs; publish endpoint; application status management) exist
- [ ] Admin routes for job poster account management exist
- [ ] Probation lifecycle logic implemented: pending → probationary (admin approve) → active (auto-promote after 30 days)
- [ ] Feature flag `feature.jobs_board` checked on all endpoint entry points; returns 503 when disabled
- [ ] FCM notification sent to job poster when applicant applies (if they have fcm_token)
- [ ] Job applications: duplicate application returns 409 Conflict
- [ ] All routes validate Zod schemas
- [ ] Test suite added: `job-poster-auth.test.ts`, `jobs-social.test.ts`, `jobs-poster.test.ts`, `admin-jobs.test.ts`
- [ ] All existing tests still pass
- [ ] Manual verification: register job poster → apply to job as social user → view applications as job poster → update application status

---

## User Stories

| Actor | Story | Notes |
|-------|-------|-------|
| Hair Stylist (Social User) | As a creative worker, I browse the Jobs tab and filter by my specialty (e.g., "Balayage"), location, and job type, so I can find relevant gigs | Requires feature flag enabled |
| Salon Owner (Job Poster) | As a business owner, I register for the jobs board, await admin approval, and then post my first job listing to find stylists | Probation period starts on first job post |
| Job Poster in Probation | As a job poster in probation, I can post jobs and receive applications, but my business details are not publicly visible until approval | Probation ends after 30 days; system auto-promotes to active |
| Photographer (Social User) | As a creative worker, I apply to a photography gig with a short cover note and link to my portfolio, so the job poster can evaluate my work | Application tracked with status; unique per user per job |
| Event Venue (Job Poster) | As an event venue, I post an urgent staffing need (marked is_urgent = true), and top results show my listing first to match talent quickly | Sorting: is_urgent DESC, posted_at DESC |
| Job Poster Receiving Application | As a job poster, I receive an FCM push notification when a user applies to my job, so I can respond promptly | Notification includes applicant name + job title |
| Platform Admin | As a platform admin, I review new job poster applications, approve legitimate businesses, and can suspend bad actors | Admin can see probation status, approve, suspend with reason |

---

## Technical Spec

### 1. Database Migration: `NNN_jobs_board.sql`

**Step 1: Create enum types**

```sql
CREATE TYPE job_status AS ENUM ('draft', 'active', 'filled', 'expired', 'cancelled');
CREATE TYPE job_type AS ENUM ('full_time', 'part_time', 'freelance', 'gig', 'internship');
CREATE TYPE compensation_type AS ENUM ('hourly', 'day_rate', 'project_rate', 'salary', 'unpaid_internship', 'negotiable');
CREATE TYPE application_status AS ENUM ('submitted', 'viewed', 'shortlisted', 'declined', 'hired', 'withdrawn');
```

**Step 2: Create `job_poster_accounts` table**

```sql
CREATE TABLE job_poster_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_name VARCHAR(255) NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  contact_name VARCHAR(255),
  phone VARCHAR(20),
  website VARCHAR(500),
  logo_url VARCHAR(500),
  business_type VARCHAR(100),
  -- Enum: 'salon', 'studio', 'production_company', 'agency', 'other'
  status VARCHAR(20) DEFAULT 'pending',
  -- Enum values: pending, probationary, active, suspended
  -- pending → probationary: when admin approves
  -- probationary → active: auto-promoted when probation_ends_at passes
  -- active → suspended: admin action
  -- suspended → active: admin re-activation
  probation_started_at TIMESTAMPTZ,
  -- Set to NOW() on first job post (not on registration)
  probation_ends_at TIMESTAMPTZ,
  -- Set to probation_started_at + 30 days when first job posted
  activated_at TIMESTAMPTZ,
  -- Set to NOW() when status → active (either from approve or auto-promote)
  suspended_at TIMESTAMPTZ,
  suspension_reason TEXT,
  approved_by_admin_id UUID REFERENCES admin_users(id) ON DELETE SET NULL,
  fcm_token TEXT,
  -- Stores FCM device token for push notifications to job poster
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_jpa_email ON job_poster_accounts(email);
CREATE INDEX idx_jpa_status ON job_poster_accounts(status);
```

**Step 3: Create `jobs` table**

```sql
CREATE TABLE jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  poster_id UUID REFERENCES job_poster_accounts(id) ON DELETE CASCADE NOT NULL,
  title VARCHAR(255) NOT NULL,
  description TEXT NOT NULL,
  job_type job_type NOT NULL,
  compensation_type compensation_type NOT NULL,
  compensation_min DECIMAL(10,2),
  compensation_max DECIMAL(10,2),
  compensation_note VARCHAR(500),
  -- e.g., "Plus tips", "Negotiable based on experience"
  required_specialties UUID[] DEFAULT '{}',
  -- Array of specialty IDs (users filter by these)
  location_type VARCHAR(20) NOT NULL,
  -- 'on_site', 'remote', 'hybrid'
  location_city VARCHAR(100),
  location_state VARCHAR(50),
  is_urgent BOOLEAN DEFAULT false,
  expires_at TIMESTAMPTZ,
  -- Auto-set to 30 days from posting when status → active
  status job_status DEFAULT 'draft',
  posted_at TIMESTAMPTZ,
  -- Set to NOW() when status → active
  filled_at TIMESTAMPTZ,
  -- Set when status → filled (either manual or when hire confirmed)
  applicant_count INTEGER DEFAULT 0,
  -- Denormalized count; updated by trigger on job_applications INSERT/DELETE
  view_count INTEGER DEFAULT 0,
  -- Incremented on GET /jobs/:id (in application layer, not trigger)
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_jobs_poster ON jobs(poster_id);
CREATE INDEX idx_jobs_status ON jobs(status);
CREATE INDEX idx_jobs_posted_at ON jobs(posted_at DESC) WHERE status = 'active';
CREATE INDEX idx_jobs_expires ON jobs(expires_at) WHERE status = 'active';
```

**Step 4: Create `job_applications` table**

```sql
CREATE TABLE job_applications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id UUID REFERENCES jobs(id) ON DELETE CASCADE NOT NULL,
  applicant_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  cover_note TEXT,
  -- Short note from applicant (max 500 chars)
  portfolio_url VARCHAR(500),
  -- Optional external portfolio link
  status application_status DEFAULT 'submitted',
  viewed_at TIMESTAMPTZ,
  shortlisted_at TIMESTAMPTZ,
  declined_at TIMESTAMPTZ,
  hired_at TIMESTAMPTZ,
  -- Set when job poster selects "Hire" (before confirmation)
  hired_confirmed_at TIMESTAMPTZ,
  -- E2 (hire confirmation): set when both parties confirm the hire
  rating INTEGER CHECK (rating BETWEEN 1 AND 5),
  -- E2: applicant rates job poster (1-5 stars)
  rating_comment TEXT,
  -- E2: applicant's optional review of job poster
  poster_rating INTEGER CHECK (poster_rating BETWEEN 1 AND 5),
  -- E2: job poster rates applicant (1-5 stars)
  poster_rating_comment TEXT,
  -- E2: job poster's optional feedback on applicant
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(job_id, applicant_id)
  -- One application per user per job; duplicate apply returns 409
);

CREATE INDEX idx_job_apps_job ON job_applications(job_id);
CREATE INDEX idx_job_apps_applicant ON job_applications(applicant_id);
CREATE INDEX idx_job_apps_status ON job_applications(status);
```

**Step 5: Create `job_poster_sessions` table (JWT refresh tokens)**

```sql
CREATE TABLE job_poster_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  poster_id UUID REFERENCES job_poster_accounts(id) ON DELETE CASCADE,
  refresh_token_hash VARCHAR(255) NOT NULL,
  token_family VARCHAR(50) DEFAULT 'job_poster',
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_jps_poster ON job_poster_sessions(poster_id);
```

**Step 6: Create trigger to update `jobs.applicant_count`**

```sql
CREATE OR REPLACE FUNCTION update_applicant_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE jobs SET applicant_count = applicant_count + 1 WHERE id = NEW.job_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE jobs SET applicant_count = applicant_count - 1 WHERE id = OLD.job_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER job_applications_count_trigger
AFTER INSERT OR DELETE ON job_applications
FOR EACH ROW
EXECUTE FUNCTION update_applicant_count();
```

**Step 7: Add `fcm_token` to `job_poster_accounts` (if not already in C0)**

If C0 added `fcm_token` only to `users`, add it to `job_poster_accounts`:

```sql
ALTER TABLE job_poster_accounts ADD COLUMN IF NOT EXISTS fcm_token TEXT;
```

---

### 2. Job Poster Auth Middleware & Routes

**File:** `packages/api/src/middleware/job-poster-auth.ts`

```typescript
import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';

declare global {
  namespace Express {
    interface Request {
      jobPoster?: { posterId: string; email: string; tokenFamily: string };
    }
  }
}

export async function authenticateJobPoster(
  req: Request,
  res: Response,
  next: NextFunction
) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing or invalid authorization header' });
  }

  const token = authHeader.slice(7);
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET!) as any;

    // Enforce tokenFamily = 'job_poster'; reject social or admin tokens
    if (decoded.tokenFamily !== 'job_poster') {
      return res.status(403).json({ error: 'Invalid token type for this endpoint' });
    }

    req.jobPoster = {
      posterId: decoded.posterId,
      email: decoded.email,
      tokenFamily: decoded.tokenFamily,
    };
    next();
  } catch (err) {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}
```

**File:** `packages/api/src/routes/job-poster-auth.ts`

```typescript
import express, { Request, Response } from 'express';
import { db } from '../db';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { z } from 'zod';
import { validate } from '../middleware/validation';
import { authenticateJobPoster } from '../middleware/job-poster-auth';
import { sendEmail } from '../services/email';

const router = express.Router();

const RegisterSchema = z.object({
  businessName: z.string().min(1),
  email: z.string().email(),
  password: z.string().min(8),
  contactName: z.string().optional(),
  phone: z.string().optional(),
  website: z.string().optional(),
  businessType: z.enum(['salon', 'studio', 'production_company', 'agency', 'other']).optional(),
});

const LoginSchema = z.object({
  email: z.string().email(),
  password: z.string(),
});

// POST /job-posters/auth/register
router.post('/register', validate(RegisterSchema), async (req: Request, res: Response) => {
  const { businessName, email, password, contactName, phone, website, businessType } = req.body;

  try {
    const existingPoster = await db.query(
      'SELECT id FROM job_poster_accounts WHERE email = $1',
      [email]
    );
    if (existingPoster.rows.length > 0) {
      return res.status(409).json({ error: 'Email already registered' });
    }

    const passwordHash = await bcrypt.hash(password, 10);
    const result = await db.query(
      `INSERT INTO job_poster_accounts
       (business_name, email, password_hash, contact_name, phone, website, business_type, status)
       VALUES ($1, $2, $3, $4, $5, $6, $7, 'pending')
       RETURNING id, business_name, email, status`,
      [businessName, email, passwordHash, contactName || null, phone || null, website || null, businessType || 'other']
    );

    const poster = result.rows[0];

    // Send welcome email
    await sendEmail({
      to: email,
      subject: 'Welcome to Industry Night Jobs Board',
      html: `<p>Welcome, ${businessName}! Your account is pending approval from our platform team. We'll review your application and get back to you soon.</p>`,
    });

    res.status(201).json({
      message: 'Registration successful. Pending admin approval.',
      posterId: poster.id,
      status: poster.status,
    });
  } catch (error) {
    console.error('Register error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /job-posters/auth/login
router.post('/login', validate(LoginSchema), async (req: Request, res: Response) => {
  const { email, password } = req.body;

  try {
    const result = await db.query(
      'SELECT id, password_hash, status FROM job_poster_accounts WHERE email = $1',
      [email]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    const poster = result.rows[0];
    const passwordMatch = await bcrypt.compare(password, poster.password_hash);

    if (!passwordMatch) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    // Issue JWT
    const accessToken = jwt.sign(
      { posterId: poster.id, email, tokenFamily: 'job_poster' },
      process.env.JWT_SECRET!,
      { expiresIn: '15m' }
    );

    const refreshToken = jwt.sign(
      { posterId: poster.id, email, tokenFamily: 'job_poster' },
      process.env.JWT_SECRET!,
      { expiresIn: '7d' }
    );

    const refreshTokenHash = await bcrypt.hash(refreshToken, 10);
    await db.query(
      `INSERT INTO job_poster_sessions (poster_id, refresh_token_hash, expires_at)
       VALUES ($1, $2, NOW() + INTERVAL '7 days')`,
      [poster.id, refreshTokenHash]
    );

    res.json({
      accessToken,
      refreshToken,
      status: poster.status,
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /job-posters/auth/refresh
router.post('/refresh', async (req: Request, res: Response) => {
  const { refreshToken } = req.body;

  try {
    const decoded = jwt.verify(refreshToken, process.env.JWT_SECRET!) as any;

    if (decoded.tokenFamily !== 'job_poster') {
      return res.status(403).json({ error: 'Invalid token type' });
    }

    // Verify refresh token exists and is valid
    const sessionResult = await db.query(
      `SELECT * FROM job_poster_sessions
       WHERE poster_id = $1 AND expires_at > NOW()
       LIMIT 1`,
      [decoded.posterId]
    );

    if (sessionResult.rows.length === 0) {
      return res.status(401).json({ error: 'Refresh token expired or not found' });
    }

    const session = sessionResult.rows[0];
    const tokenMatch = await bcrypt.compare(refreshToken, session.refresh_token_hash);

    if (!tokenMatch) {
      return res.status(401).json({ error: 'Invalid refresh token' });
    }

    const newAccessToken = jwt.sign(
      { posterId: decoded.posterId, email: decoded.email, tokenFamily: 'job_poster' },
      process.env.JWT_SECRET!,
      { expiresIn: '15m' }
    );

    res.json({ accessToken: newAccessToken });
  } catch (error) {
    console.error('Refresh error:', error);
    res.status(401).json({ error: 'Invalid refresh token' });
  }
});

// POST /job-posters/auth/logout
router.post('/logout', authenticateJobPoster, async (req: Request, res: Response) => {
  try {
    await db.query(
      'DELETE FROM job_poster_sessions WHERE poster_id = $1',
      [req.jobPoster!.posterId]
    );
    res.json({ message: 'Logged out' });
  } catch (error) {
    console.error('Logout error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /job-posters/auth/me
router.get('/me', authenticateJobPoster, async (req: Request, res: Response) => {
  try {
    const result = await db.query(
      `SELECT id, business_name, email, contact_name, phone, website, logo_url, business_type,
              status, probation_started_at, probation_ends_at, activated_at
       FROM job_poster_accounts WHERE id = $1`,
      [req.jobPoster!.posterId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Job poster not found' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Get me error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;
```

Mount in `packages/api/src/index.ts`:

```typescript
app.use('/job-posters/auth', jobPosterAuthRouter);
```

---

### 3. Social App Job Routes

**File:** `packages/api/src/routes/jobs-social.ts`

Feature-flag check at endpoint entry point. All routes check `platform_config.feature.jobs_board` and return 503 if disabled.

```typescript
import express, { Request, Response } from 'express';
import { db } from '../db';
import { authenticate, AuthenticatedRequest } from '../middleware/auth';
import { z } from 'zod';
import { validate } from '../middleware/validation';
import { getConfig } from '../services/config';
import { sendFCMNotification } from '../services/fcm';

const router = express.Router();

// Middleware: Check feature flag
async function checkJobsFeature(req: Request, res: Response, next: Function) {
  const enabled = await getConfig('feature.jobs_board');
  if (enabled !== 'true') {
    return res.status(503).json({
      error: 'Jobs board feature is not available',
      featureFlag: 'feature.jobs_board',
    });
  }
  next();
}

router.use(checkJobsFeature);

// GET /jobs — list active jobs
const ListJobsSchema = z.object({
  specialty: z.string().optional(),
  type: z.enum(['full_time', 'part_time', 'freelance', 'gig', 'internship']).optional(),
  location: z.string().optional(),
  q: z.string().optional(), // Search in title + description
});

router.get('/', validate(ListJobsSchema), async (req: Request, res: Response) => {
  const { specialty, type, location, q } = req.query;

  try {
    let query = `
      SELECT j.id, j.title, j.description, j.job_type, j.compensation_type,
             j.compensation_min, j.compensation_max, j.compensation_note,
             j.location_type, j.location_city, j.location_state,
             j.is_urgent, j.posted_at, j.applicant_count, j.view_count,
             jpa.id as poster_id, jpa.business_name, jpa.logo_url
      FROM jobs j
      JOIN job_poster_accounts jpa ON j.poster_id = jpa.id
      WHERE j.status = 'active'
        AND j.expires_at > NOW()
    `;
    const params: any[] = [];

    if (specialty) {
      query += ` AND $${params.length + 1} = ANY(j.required_specialties)`;
      params.push(specialty);
    }

    if (type) {
      query += ` AND j.job_type = $${params.length + 1}`;
      params.push(type);
    }

    if (location) {
      query += ` AND LOWER(j.location_city) LIKE LOWER($${params.length + 1})`;
      params.push(`%${location}%`);
    }

    if (q) {
      query += ` AND (LOWER(j.title) LIKE LOWER($${params.length + 1}) OR LOWER(j.description) LIKE LOWER($${params.length + 2}))`;
      params.push(`%${q}%`);
      params.push(`%${q}%`);
    }

    query += ` ORDER BY j.is_urgent DESC, j.posted_at DESC LIMIT 100`;

    const result = await db.query(query, params);
    res.json(result.rows);
  } catch (error) {
    console.error('List jobs error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /jobs/:id — job detail
router.get('/:id', authenticate, async (req: AuthenticatedRequest, res: Response) => {
  const { id } = req.params;

  try {
    const jobResult = await db.query(
      `SELECT j.id, j.title, j.description, j.job_type, j.compensation_type,
              j.compensation_min, j.compensation_max, j.compensation_note,
              j.location_type, j.location_city, j.location_state,
              j.is_urgent, j.posted_at, j.expires_at, j.applicant_count, j.view_count,
              jpa.id as poster_id, jpa.business_name, jpa.logo_url
       FROM jobs j
       JOIN job_poster_accounts jpa ON j.poster_id = jpa.id
       WHERE j.id = $1 AND j.status = 'active' AND j.expires_at > NOW()`,
      [id]
    );

    if (jobResult.rows.length === 0) {
      return res.status(404).json({ error: 'Job not found' });
    }

    // Increment view count
    await db.query('UPDATE jobs SET view_count = view_count + 1 WHERE id = $1', [id]);

    const job = jobResult.rows[0];

    // Check if user already applied
    const appResult = await db.query(
      'SELECT id FROM job_applications WHERE job_id = $1 AND applicant_id = $2',
      [id, req.user?.userId]
    );

    res.json({
      ...job,
      has_applied: appResult.rows.length > 0,
    });
  } catch (error) {
    console.error('Get job detail error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /jobs/:id/apply — apply to a job
const ApplySchema = z.object({
  coverNote: z.string().max(500).optional(),
  portfolioUrl: z.string().url().optional(),
});

router.post('/:id/apply', authenticate, validate(ApplySchema), async (req: AuthenticatedRequest, res: Response) => {
  const { id } = req.params;
  const { coverNote, portfolioUrl } = req.body;
  const userId = req.user?.userId;

  try {
    // Check if already applied
    const existing = await db.query(
      'SELECT id FROM job_applications WHERE job_id = $1 AND applicant_id = $2',
      [id, userId]
    );

    if (existing.rows.length > 0) {
      return res.status(409).json({ error: 'You have already applied to this job' });
    }

    // Create application
    const appResult = await db.query(
      `INSERT INTO job_applications (job_id, applicant_id, cover_note, portfolio_url)
       VALUES ($1, $2, $3, $4)
       RETURNING id, created_at`,
      [id, userId, coverNote || null, portfolioUrl || null]
    );

    const app = appResult.rows[0];

    // Get job and poster info for notification
    const jobResult = await db.query(
      `SELECT j.id, j.title, j.poster_id, jpa.fcm_token
       FROM jobs j
       JOIN job_poster_accounts jpa ON j.poster_id = jpa.id
       WHERE j.id = $1`,
      [id]
    );

    if (jobResult.rows.length > 0) {
      const job = jobResult.rows[0];
      const userResult = await db.query('SELECT name FROM users WHERE id = $1', [userId]);
      const applicantName = userResult.rows[0]?.name || 'A candidate';

      // Send FCM notification if poster has token
      if (job.fcm_token) {
        await sendFCMNotification(job.fcm_token, {
          title: 'New Application',
          body: `${applicantName} applied to: ${job.title}`,
          data: { jobId: job.id },
        }).catch((err) => console.error('FCM send error:', err));
      }
    }

    res.status(201).json({
      message: 'Application submitted',
      applicationId: app.id,
      appliedAt: app.created_at,
    });
  } catch (error) {
    console.error('Apply error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /jobs/my-applications — current user's applications
router.get('/my-applications', authenticate, async (req: AuthenticatedRequest, res: Response) => {
  const userId = req.user?.userId;

  try {
    const result = await db.query(
      `SELECT ja.id, ja.job_id, ja.status, ja.cover_note, ja.portfolio_url,
              ja.viewed_at, ja.shortlisted_at, ja.declined_at, ja.hired_at, ja.created_at,
              j.title as job_title, j.compensation_type, j.compensation_min, j.compensation_max,
              jpa.business_name as poster_name, jpa.logo_url as poster_logo
       FROM job_applications ja
       JOIN jobs j ON ja.job_id = j.id
       JOIN job_poster_accounts jpa ON j.poster_id = jpa.id
       WHERE ja.applicant_id = $1
       ORDER BY ja.created_at DESC`,
      [userId]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Get my applications error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;
```

Mount in `packages/api/src/index.ts`:

```typescript
app.use('/jobs', jobsSocialRouter);
```

---

### 4. Job Poster Routes

**File:** `packages/api/src/routes/jobs-poster.ts`

```typescript
import express, { Request, Response } from 'express';
import { db } from '../db';
import { authenticateJobPoster } from '../middleware/job-poster-auth';
import { z } from 'zod';
import { validate } from '../middleware/validation';
import { getConfig } from '../services/config';

const router = express.Router();

// Middleware: Check feature flag
async function checkJobsFeature(req: Request, res: Response, next: Function) {
  const enabled = await getConfig('feature.jobs_board');
  if (enabled !== 'true') {
    return res.status(503).json({ error: 'Jobs board feature is not available' });
  }
  next();
}

router.use(checkJobsFeature);
router.use(authenticateJobPoster);

// GET /job-posters/jobs — my posted jobs
router.get('/', async (req: Request, res: Response) => {
  try {
    const result = await db.query(
      `SELECT id, title, status, job_type, posted_at, expires_at, applicant_count
       FROM jobs
       WHERE poster_id = $1
       ORDER BY created_at DESC`,
      [req.jobPoster!.posterId]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Get my jobs error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /job-posters/jobs — create job (draft)
const CreateJobSchema = z.object({
  title: z.string().min(1),
  description: z.string().min(1),
  jobType: z.enum(['full_time', 'part_time', 'freelance', 'gig', 'internship']),
  compensationType: z.enum(['hourly', 'day_rate', 'project_rate', 'salary', 'unpaid_internship', 'negotiable']),
  compensationMin: z.number().positive().optional(),
  compensationMax: z.number().positive().optional(),
  compensationNote: z.string().optional(),
  requiredSpecialties: z.array(z.string().uuid()).optional(),
  locationType: z.enum(['on_site', 'remote', 'hybrid']),
  locationCity: z.string().optional(),
  locationState: z.string().optional(),
  isUrgent: z.boolean().optional(),
});

router.post('/', validate(CreateJobSchema), async (req: Request, res: Response) => {
  const {
    title,
    description,
    jobType,
    compensationType,
    compensationMin,
    compensationMax,
    compensationNote,
    requiredSpecialties,
    locationType,
    locationCity,
    locationState,
    isUrgent,
  } = req.body;

  try {
    const result = await db.query(
      `INSERT INTO jobs
       (poster_id, title, description, job_type, compensation_type,
        compensation_min, compensation_max, compensation_note,
        required_specialties, location_type, location_city, location_state, is_urgent)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
       RETURNING id, status, created_at`,
      [
        req.jobPoster!.posterId,
        title,
        description,
        jobType,
        compensationType,
        compensationMin || null,
        compensationMax || null,
        compensationNote || null,
        requiredSpecialties || [],
        locationType,
        locationCity || null,
        locationState || null,
        isUrgent || false,
      ]
    );

    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Create job error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// PATCH /job-posters/jobs/:id — update job
const UpdateJobSchema = z.object({
  title: z.string().optional(),
  description: z.string().optional(),
  jobType: z.enum(['full_time', 'part_time', 'freelance', 'gig', 'internship']).optional(),
  compensationType: z.enum(['hourly', 'day_rate', 'project_rate', 'salary', 'unpaid_internship', 'negotiable']).optional(),
  compensationMin: z.number().positive().optional(),
  compensationMax: z.number().positive().optional(),
  compensationNote: z.string().optional(),
  requiredSpecialties: z.array(z.string().uuid()).optional(),
  locationType: z.enum(['on_site', 'remote', 'hybrid']).optional(),
  locationCity: z.string().optional(),
  locationState: z.string().optional(),
  isUrgent: z.boolean().optional(),
});

router.patch('/:id', validate(UpdateJobSchema), async (req: Request, res: Response) => {
  const { id } = req.params;
  const updates = req.body;

  try {
    // Verify ownership
    const job = await db.query('SELECT poster_id FROM jobs WHERE id = $1', [id]);
    if (job.rows.length === 0 || job.rows[0].poster_id !== req.jobPoster!.posterId) {
      return res.status(403).json({ error: 'Not authorized to update this job' });
    }

    const fields: string[] = [];
    const values: any[] = [id];
    let paramIndex = 2;

    Object.entries(updates).forEach(([key, value]) => {
      const snakeKey = key.replace(/([A-Z])/g, '_$1').toLowerCase();
      fields.push(`${snakeKey} = $${paramIndex}`);
      values.push(value);
      paramIndex++;
    });

    const query = `UPDATE jobs SET ${fields.join(', ')} WHERE id = $1 RETURNING *`;
    const result = await db.query(query, values);

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Update job error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /job-posters/jobs/:id/publish — publish job
router.post('/:id/publish', async (req: Request, res: Response) => {
  const { id } = req.params;

  try {
    // Verify ownership
    const jobResult = await db.query('SELECT status, poster_id FROM jobs WHERE id = $1', [id]);
    if (jobResult.rows.length === 0 || jobResult.rows[0].poster_id !== req.jobPoster!.posterId) {
      return res.status(403).json({ error: 'Not authorized' });
    }

    // Check poster status
    const posterResult = await db.query('SELECT status FROM job_poster_accounts WHERE id = $1', [
      req.jobPoster!.posterId,
    ]);
    const poster = posterResult.rows[0];

    if (poster.status === 'pending') {
      return res.status(403).json({ error: 'Your account is pending admin approval' });
    }

    if (poster.status === 'suspended') {
      return res.status(403).json({ error: 'Your account has been suspended' });
    }

    // If first job from this poster in probation, set probation dates
    const posterJobCount = await db.query(
      'SELECT COUNT(*) as cnt FROM jobs WHERE poster_id = $1 AND posted_at IS NOT NULL',
      [req.jobPoster!.posterId]
    );

    let probationQuery = '';
    const probationValues = [];

    if (parseInt(posterJobCount.rows[0].cnt) === 0 && poster.status !== 'active') {
      // First job: start probation
      probationQuery = `, probation_started_at = NOW(), probation_ends_at = NOW() + INTERVAL '30 days'`;
    }

    // Publish job
    const updateResult = await db.query(
      `UPDATE jobs
       SET status = 'active', posted_at = NOW(), expires_at = NOW() + INTERVAL '30 days'
       WHERE id = $1
       RETURNING *`,
      [id]
    );

    // Update poster probation dates if needed
    if (probationQuery) {
      await db.query(
        `UPDATE job_poster_accounts
         SET ${probationQuery}
         WHERE id = $1`,
        [req.jobPoster!.posterId]
      );
    }

    res.json({
      message: 'Job published',
      job: updateResult.rows[0],
    });
  } catch (error) {
    console.error('Publish job error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /job-posters/jobs/:id/applications — list applications for a job
router.get('/:id/applications', async (req: Request, res: Response) => {
  const { id } = req.params;

  try {
    // Verify ownership
    const job = await db.query('SELECT poster_id FROM jobs WHERE id = $1', [id]);
    if (job.rows.length === 0 || job.rows[0].poster_id !== req.jobPoster!.posterId) {
      return res.status(403).json({ error: 'Not authorized' });
    }

    const result = await db.query(
      `SELECT ja.id, ja.applicant_id, ja.status, ja.cover_note, ja.portfolio_url,
              ja.viewed_at, ja.shortlisted_at, ja.declined_at, ja.hired_at, ja.created_at,
              u.name, u.avatar_url, u.bio
       FROM job_applications ja
       JOIN users u ON ja.applicant_id = u.id
       WHERE ja.job_id = $1
       ORDER BY ja.created_at DESC`,
      [id]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Get applications error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// PATCH /job-posters/jobs/:id/applications/:appId — update application status
const UpdateAppStatusSchema = z.object({
  status: z.enum(['viewed', 'shortlisted', 'declined', 'hired', 'withdrawn']),
});

router.patch('/:id/applications/:appId', validate(UpdateAppStatusSchema), async (req: Request, res: Response) => {
  const { id, appId } = req.params;
  const { status } = req.body;

  try {
    // Verify ownership
    const job = await db.query('SELECT poster_id FROM jobs WHERE id = $1', [id]);
    if (job.rows.length === 0 || job.rows[0].poster_id !== req.jobPoster!.posterId) {
      return res.status(403).json({ error: 'Not authorized' });
    }

    const statusField = (() => {
      switch (status) {
        case 'viewed':
          return 'viewed_at = NOW()';
        case 'shortlisted':
          return 'shortlisted_at = NOW()';
        case 'declined':
          return 'declined_at = NOW()';
        case 'hired':
          return 'hired_at = NOW()';
        case 'withdrawn':
          return null;
        default:
          return null;
      }
    })();

    if (!statusField) {
      return res.status(400).json({ error: 'Invalid status transition' });
    }

    const result = await db.query(
      `UPDATE job_applications
       SET status = $1, ${statusField}
       WHERE id = $2 AND job_id = $3
       RETURNING *`,
      [status, appId, id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Application not found' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Update application status error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;
```

Mount in `packages/api/src/index.ts`:

```typescript
app.use('/job-posters/jobs', jobsPosterRouter);
```

---

### 5. Admin Job Routes (add to routes/admin.ts)

```typescript
// GET /admin/job-posters — list job poster accounts
const ListPostersSchema = z.object({
  status: z.enum(['pending', 'probationary', 'active', 'suspended']).optional(),
  q: z.string().optional(),
});

adminRouter.get('/job-posters', validate(ListPostersSchema), requirePlatformAdmin, async (req: Request, res: Response) => {
  const { status, q } = req.query;

  try {
    let query = 'SELECT * FROM job_poster_accounts WHERE 1=1';
    const params: any[] = [];

    if (status) {
      query += ` AND status = $${params.length + 1}`;
      params.push(status);
    }

    if (q) {
      query += ` AND (LOWER(business_name) LIKE LOWER($${params.length + 1}) OR LOWER(email) LIKE LOWER($${params.length + 2}))`;
      params.push(`%${q}%`);
      params.push(`%${q}%`);
    }

    query += ' ORDER BY created_at DESC LIMIT 100';

    const result = await db.query(query, params);
    res.json(result.rows);
  } catch (error) {
    console.error('List job posters error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /admin/job-posters/:id — job poster detail
adminRouter.get('/job-posters/:id', requirePlatformAdmin, async (req: Request, res: Response) => {
  const { id } = req.params;

  try {
    const posterResult = await db.query('SELECT * FROM job_poster_accounts WHERE id = $1', [id]);

    if (posterResult.rows.length === 0) {
      return res.status(404).json({ error: 'Job poster not found' });
    }

    const poster = posterResult.rows[0];

    const jobsResult = await db.query(
      'SELECT id, title, status, posted_at, applicant_count FROM jobs WHERE poster_id = $1 ORDER BY created_at DESC',
      [id]
    );

    res.json({
      ...poster,
      jobs: jobsResult.rows,
    });
  } catch (error) {
    console.error('Get job poster detail error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /admin/job-posters/:id/approve — approve job poster (pending → probationary or active)
adminRouter.post('/job-posters/:id/approve', requirePlatformAdmin, async (req: Request, res: Response) => {
  const { id } = req.params;
  const adminId = (req as any).admin?.userId;

  try {
    const result = await db.query(
      `UPDATE job_poster_accounts
       SET status = 'probationary', approved_by_admin_id = $1, updated_at = NOW()
       WHERE id = $2
       RETURNING *`,
      [adminId, id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Job poster not found' });
    }

    res.json({
      message: 'Job poster approved',
      poster: result.rows[0],
    });
  } catch (error) {
    console.error('Approve job poster error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /admin/job-posters/:id/suspend — suspend job poster
const SuspendSchema = z.object({
  reason: z.string().min(1),
});

adminRouter.post('/job-posters/:id/suspend', validate(SuspendSchema), requirePlatformAdmin, async (req: Request, res: Response) => {
  const { id } = req.params;
  const { reason } = req.body;

  try {
    const result = await db.query(
      `UPDATE job_poster_accounts
       SET status = 'suspended', suspension_reason = $1, suspended_at = NOW(), updated_at = NOW()
       WHERE id = $2
       RETURNING *`,
      [reason, id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Job poster not found' });
    }

    res.json({
      message: 'Job poster suspended',
      poster: result.rows[0],
    });
  } catch (error) {
    console.error('Suspend job poster error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /admin/jobs — all jobs (for moderation)
adminRouter.get('/jobs', requirePlatformAdmin, async (req: Request, res: Response) => {
  try {
    const result = await db.query(
      `SELECT j.id, j.title, j.status, j.posted_at, j.applicant_count,
              jpa.business_name, jpa.status as poster_status
       FROM jobs j
       JOIN job_poster_accounts jpa ON j.poster_id = jpa.id
       ORDER BY j.created_at DESC
       LIMIT 100`
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Get all jobs error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// DELETE /admin/jobs/:id — admin delete any job
adminRouter.delete('/jobs/:id', requirePlatformAdmin, async (req: Request, res: Response) => {
  const { id } = req.params;

  try {
    await db.query('DELETE FROM jobs WHERE id = $1', [id]);
    res.json({ message: 'Job deleted' });
  } catch (error) {
    console.error('Delete job error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});
```

---

### 6. Config Service Helper

**File:** `packages/api/src/services/config.ts` (update if exists)

```typescript
import { db } from '../db';

const cache = new Map<string, any>();
const cacheExpiry = new Map<string, number>();
const CACHE_TTL = 60 * 1000; // 1 minute

export async function getConfig(key: string): Promise<any> {
  const now = Date.now();

  if (cache.has(key) && (cacheExpiry.get(key) || 0) > now) {
    return cache.get(key);
  }

  try {
    const result = await db.query('SELECT value FROM platform_config WHERE key = $1', [key]);

    if (result.rows.length === 0) {
      return null;
    }

    const value = result.rows[0].value;
    cache.set(key, value);
    cacheExpiry.set(key, now + CACHE_TTL);

    return value;
  } catch (error) {
    console.error('Get config error:', error);
    return null;
  }
}
```

---

### 7. FCM Service Helper (if not exists)

**File:** `packages/api/src/services/fcm.ts`

```typescript
import admin from 'firebase-admin';

export async function sendFCMNotification(
  token: string,
  payload: { title: string; body: string; data?: Record<string, string> }
) {
  if (!token) {
    return; // No token, skip
  }

  try {
    await admin.messaging().send({
      token,
      notification: {
        title: payload.title,
        body: payload.body,
      },
      data: payload.data || {},
    });
  } catch (error) {
    console.error('FCM send error:', error);
    // Don't throw — graceful degradation
  }
}
```

---

## Test Suite

### 4 new test files to create:

**1. `packages/api/src/__tests__/job-poster-auth.test.ts`**

```typescript
import { db, pool } from '../db';
import request from 'supertest';
import app from '../index';
import bcrypt from 'bcrypt';

describe('Job Poster Auth', () => {
  afterAll(async () => {
    await pool.end();
  });

  it('registers a new job poster (pending status)', async () => {
    const res = await request(app).post('/job-posters/auth/register').send({
      businessName: 'Test Salon',
      email: 'salon@test.com',
      password: 'SecurePassword123',
      contactName: 'John Doe',
      businessType: 'salon',
    });

    expect(res.status).toBe(201);
    expect(res.body.status).toBe('pending');
    expect(res.body.posterId).toBeDefined();
  });

  it('rejects duplicate email on register', async () => {
    await request(app).post('/job-posters/auth/register').send({
      businessName: 'Test Salon 1',
      email: 'duplicate@test.com',
      password: 'SecurePassword123',
    });

    const res = await request(app).post('/job-posters/auth/register').send({
      businessName: 'Test Salon 2',
      email: 'duplicate@test.com',
      password: 'SecurePassword123',
    });

    expect(res.status).toBe(409);
  });

  it('logs in job poster and returns JWT with tokenFamily=job_poster', async () => {
    await request(app).post('/job-posters/auth/register').send({
      businessName: 'Login Test',
      email: 'login@test.com',
      password: 'SecurePassword123',
    });

    const res = await request(app).post('/job-posters/auth/login').send({
      email: 'login@test.com',
      password: 'SecurePassword123',
    });

    expect(res.status).toBe(200);
    expect(res.body.accessToken).toBeDefined();
    expect(res.body.refreshToken).toBeDefined();

    // Decode and verify tokenFamily
    const jwt = require('jsonwebtoken');
    const decoded = jwt.decode(res.body.accessToken);
    expect(decoded.tokenFamily).toBe('job_poster');
  });

  it('rejects wrong password on login', async () => {
    await request(app).post('/job-posters/auth/register').send({
      businessName: 'Test',
      email: 'wrongpwd@test.com',
      password: 'CorrectPassword123',
    });

    const res = await request(app).post('/job-posters/auth/login').send({
      email: 'wrongpwd@test.com',
      password: 'WrongPassword123',
    });

    expect(res.status).toBe(401);
  });

  it('verifies JWT with job_poster tokenFamily is required for authenticateJobPoster', async () => {
    const registerRes = await request(app).post('/job-posters/auth/register').send({
      businessName: 'Token Test',
      email: 'token@test.com',
      password: 'SecurePassword123',
    });

    const loginRes = await request(app).post('/job-posters/auth/login').send({
      email: 'token@test.com',
      password: 'SecurePassword123',
    });

    const accessToken = loginRes.body.accessToken;

    const meRes = await request(app)
      .get('/job-posters/auth/me')
      .set('Authorization', `Bearer ${accessToken}`);

    expect(meRes.status).toBe(200);
    expect(meRes.body.email).toBe('token@test.com');
  });

  it('rejects social user token on job poster endpoint', async () => {
    // Create social user and get token (requires social auth setup)
    // Then attempt to call /job-posters/auth/me with that token
    // Expect 403 "Invalid token type"
    // (Assumes social auth endpoints exist; adjust if needed)
  });
});
```

**2. `packages/api/src/__tests__/jobs-social.test.ts`**

```typescript
describe('Jobs Social API', () => {
  it('lists active jobs with feature flag enabled', async () => {
    // Enable feature flag
    // Create job poster account and post a job
    // Call GET /jobs
    // Expect 200 with jobs array
  });

  it('returns 503 when feature.jobs_board is disabled', async () => {
    // Disable feature flag
    // Call GET /jobs
    // Expect 503 "Feature not available"
  });

  it('applies to a job as social user', async () => {
    // Create social user, authenticate
    // Create job poster and post active job
    // POST /jobs/:id/apply with coverNote
    // Expect 201, application created
  });

  it('returns 409 when applying twice to same job', async () => {
    // Apply once, expect 201
    // Apply again, expect 409 Conflict
  });

  it('increments view_count on GET /jobs/:id', async () => {
    // Create job
    // GET /jobs/:id
    // Check view_count increased
  });

  it('includes has_applied flag in job detail', async () => {
    // Create social user, apply to job
    // GET /jobs/:id (with auth)
    // Expect has_applied: true
    // GET /jobs/:id (different user)
    // Expect has_applied: false
  });

  it('returns my applications list for social user', async () => {
    // Create social user, apply to 2 jobs
    // GET /jobs/my-applications
    // Expect array with 2 applications
  });
});
```

**3. `packages/api/src/__tests__/jobs-poster.test.ts`**

```typescript
describe('Jobs Poster API', () => {
  it('creates a draft job', async () => {
    // Authenticate job poster
    // POST /job-posters/jobs with job details
    // Expect 201, status=draft
  });

  it('publishes a job (starts probation if first)', async () => {
    // Create pending job poster (waiting for admin approval)
    // Attempt to publish job → expect 403
    // (Requires admin approval first)
  });

  it('sets probation dates on first publish', async () => {
    // Admin approves job poster (pending → probationary)
    // Job poster publishes first job
    // Check job_poster_accounts.probation_started_at and probation_ends_at are set
  });

  it('lists applications for a job', async () => {
    // Create job and 2 applications
    // GET /job-posters/jobs/:id/applications
    // Expect array with 2 applications, includes applicant profile data
  });

  it('updates application status', async () => {
    // Create application
    // PATCH /job-posters/jobs/:id/applications/:appId with status=shortlisted
    // Expect shortlisted_at is set
  });
});
```

**4. `packages/api/src/__tests__/admin-jobs.test.ts`**

```typescript
describe('Admin Jobs API', () => {
  it('lists job poster accounts with status filter', async () => {
    // Authenticate as platformAdmin
    // Create pending, probationary, active posters
    // GET /admin/job-posters?status=pending
    // Expect only pending posters
  });

  it('approves a job poster (pending → probationary)', async () => {
    // Create pending job poster
    // POST /admin/job-posters/:id/approve
    // Check status changed to probationary, approved_by_admin_id set
  });

  it('suspends a job poster with reason', async () => {
    // Create active job poster
    // POST /admin/job-posters/:id/suspend with reason
    // Check status=suspended, suspension_reason set, suspended_at set
  });

  it('lists all jobs across all posters', async () => {
    // Create 2 job posters with 3 jobs total
    // GET /admin/jobs
    // Expect array with 3 jobs, includes poster_name and poster_status
  });

  it('admin can delete any job', async () => {
    // Create job
    // DELETE /admin/jobs/:id
    // Expect 200, job deleted
  });
});
```

---

## Probation Lifecycle Implementation

Document the logic (implement as code in routes where job is published or auto-promotion trigger):

**Status transitions:**

1. **pending → probationary:** Admin calls `POST /admin/job-posters/:id/approve`
2. **probationary → active:** Auto-promoted by cron job when `probation_ends_at < NOW()`
3. **active → suspended:** Admin calls `POST /admin/job-posters/:id/suspend`
4. **suspended → active:** Admin calls `POST /admin/job-posters/:id/unsuspend` (add endpoint)

**Cron job (daily):** Add to infrastructure (E2 or ops docs)

```sql
-- Run nightly
UPDATE job_poster_accounts
SET status = 'active', activated_at = NOW(), updated_at = NOW()
WHERE status = 'probationary' AND probation_ends_at < NOW();
```

**During probation:**
- Poster can post and edit jobs
- Applicants can apply
- Poster can manage applications
- Business info (logo, website) is hidden from job listings until activated

---

## Definition of Done

- [ ] Migration `NNN_jobs_board.sql` created and applied (with correct sequential number)
- [ ] All tables exist with correct schema
- [ ] Job poster auth routes work (register, login, refresh, logout, me)
- [ ] JWT tokenFamily isolation enforced (job_poster tokens rejected by social/admin middleware)
- [ ] Social job routes work (list, detail, apply, my-applications) with feature flag
- [ ] Job poster routes work (CRUD jobs, publish, view/update applications)
- [ ] Admin routes work (list/approve/suspend posters, list/delete jobs)
- [ ] Feature flag integration on all endpoint entry points
- [ ] FCM notifications sent on apply
- [ ] Probation logic implemented
- [ ] Duplicate application returns 409
- [ ] All 4 test suites added and passing
- [ ] Manual E2E test passed: register poster → admin approve → post job → apply → view apps
- [ ] Completion Report filled in
- [ ] Interrogative Session with Jeff completed

---

## Completion Report

> To be filled in by the executing agent after implementation is complete.

**Branch:** `feature/E0-jobs-schema-backend-[claude|gpt]`
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

### What the next prompt in this track (E1) should know

-

---

## Interrogative Session

**Q1: Are all the routes wired up in index.ts and do they mount without errors? Do the test suites run without environment setup issues?**

> Jeff:

**Q2: Does the probation lifecycle work end-to-end (pending poster approved → posts first job → probation dates set → auto-promotion after 30 days)?**

> Jeff:

**Q3: Are the JWT token family constraints actually preventing cross-family token reuse (social token rejected on /job-posters/*, admin token rejected on /jobs, etc.)?**

> Jeff:

**Q4: Any concerns about the enum types, table relationships, or indexes before E1 (Flutter UI) starts?**

> Jeff:

**Q5: What's the biggest unknown or risk heading into E1 and E2?**

> Jeff:

**Ready for review:** ☐ Yes
