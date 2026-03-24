# [Track-E3] Job Poster Account Portal (React Web App)

**Track:** E (Jobs Board)
**Sequence:** 3 of 3 in Track E (Final prompt in entire CODEX library)
**Model:** claude-sonnet-4-6
**Alternate Model:** gpt-5.4
**A/B Test:** No
**Estimated Effort:** Large (3-4 days)
**Dependencies:** E0 (backend API — job board endpoints), E2 (hire confirmation + ratings system)

## Execution Mode (Required)

- [ ] Stage 1 (required): execute and validate locally first (local Postgres + local API + local admin/mobile against local endpoint).
- [ ] Stage 2 (required for backend/integration-impacting tracks): run shared-dev integration smoke only after local pass.
- [ ] Stage 3 (required before PR merge): run AWS dev deploy/integration smoke for final confidence.
- [ ] Completion log must explicitly record: execution mode used, exact commands run, evidence links, and cleanup actions.


---

## Context

Read these before writing any code:

- `CLAUDE.md` — full project reference (tech stack, infrastructure, deployment patterns)
- `docs/codex/track-B/B0-scaffold-design-system.md` — style reference for Next.js structure, Tailwind design system, auth patterns
- `docs/codex/track-E/E0-job-board-api.md` — job board backend API spec; understand `/jobs`, `/applicants`, `/applications`, `/ratings` endpoints
- `docs/codex/track-E/E2-hire-confirmation-ratings.md` — understand how hire confirmations are tracked and how rating POST endpoint works
- `packages/react-admin/` — reference the existing React admin app structure; poster portal shares design system but uses separate auth
- `packages/react-admin/lib/auth/` — reference the admin auth pattern but do NOT reuse; create `lib/poster-auth/` with separate `tokenFamily: 'job_poster'`

---

## Goal

Build a standalone web portal for job poster accounts — the B2B interface for businesses (salons, studios, production companies, studios, talent management agencies) who pay to post jobs on Industry Night. Job posters log in, manage job listings, review applicants, manage hire confirmations, and view their reputation ratings.

At the end of this prompt, a job poster can:
1. Log in at `/poster/login` with email + password
2. See their dashboard with stats and recent activity
3. Create and publish job listings
4. Review applicants filtered by status
5. Hire applicants and wait for confirmation
6. Rate confirmed hires and view their reputation

**Architecture decision (document both options in the prompt; let the executing agent choose):**

**Option A: Separate Next.js app at `packages/job-poster-portal/`**
- Clean separation of concerns
- Different domain: `posters.industrynight.net` (prod) or `dev-posters.localhost` (dev)
- Reuses design system tokens but not the admin RBAC middleware
- Requires separate deployment script and K8s configuration
- Simpler to scale independently; different teams could own it

**Option B: Additional route group in `packages/react-admin/` at `app/(poster)/`**
- Shares Next.js instance, builds with admin app
- Same domain as admin but different URL path: `/poster/login` vs `/login`
- Simpler infrastructure: single deployment script, single K8s pod
- Poster routes protected by `authenticateJobPoster` middleware (separate from admin auth)
- Shared design system, shared API proxy layer

**Recommendation:** **Option B for current scale** (simpler deployment, single Next.js instance, shared infra). Option A is the right call if poster portal needs significantly different styling, its own domain for branding, or separate scaling.

The spec below assumes **Option B**. If agent chooses Option A, adapt the file paths and deployment steps accordingly.

---

## Scope (Option B: Route group in react-admin)

### 1. Route group: `app/(poster)/` in packages/react-admin

Auth: `authenticateJobPoster` middleware — separate from admin auth. Posters log in at `/poster/login`.

Routes:
- `/poster/login` — job poster login (email + password)
- `/poster/dashboard` — overview stats and recent activity
- `/poster/jobs` — my job listings (table: title, type badge, status badge, applicant count, posted date, expires date, actions)
- `/poster/jobs/create` — create new job listing
- `/poster/jobs/:id` — job detail + applicant management
- `/poster/jobs/:id/edit` — edit job listing
- `/poster/applicants` — all applicants across all jobs (unified view, filterable by status)
- `/poster/profile` — account settings + rating display + password change
- `/poster/billing` — placeholder (future Stripe integration for job posting credits)

### 2. Poster Auth Context (`lib/poster-auth/`)

Create a separate auth module from admin auth:

```typescript
// lib/poster-auth/session.ts
// Same pattern as admin auth (B1) but uses tokenFamily: 'job_poster'
```

- `usePosterAuth()` hook: `{ poster: JobPosterAccount | null, login(), logout(), isLoading }`
- Silent refresh on mount via `useEffect` in `PosterAuthProvider`
- Access token stored in httpOnly cookie (sameSite: strict)
- Refresh token stored in secure, httpOnly cookie
- Cannot use admin JWT — completely separate auth flow (tokenFamily isolation enforced at API)
- Auto-refresh on 401; if refresh fails, clear tokens and redirect to `/poster/login`

```typescript
// lib/poster-auth/index.ts
export interface JobPosterAccount {
  id: string;
  businessName: string;
  email: string;
  logo?: string;
  websiteUrl?: string;
  businessType: string;
  contactPhone: string;
  status: 'pending' | 'active' | 'probationary' | 'suspended';
  ratedAt?: Date;
}

export function usePosterAuth() {
  // hooks for login, logout, current poster, loading state
}
```

- Protected layout: `app/(poster)/layout.tsx` redirects to `/poster/login` if not authenticated
- Middleware `middleware.ts` updated to handle `/poster` routes

### 3. `/poster/login` — Login page

```
┌─────────────────────────────────────┐
│   Industry Night Job Poster Login   │
├─────────────────────────────────────┤
│                                     │
│  Email        [_________________]   │
│  Password     [_________________]   │
│                                     │
│  [  Sign In  ]                      │
│                                     │
│  New poster? [Request Access] →     │
│                                     │
│ ─ Account Status Messages ──────    │
│ "Your account is pending review.    │
│  You'll receive an email when       │
│  approved."                         │
│                                     │
│ OR                                  │
│                                     │
│ "Your account has been suspended.   │
│  Contact support@industrynight.net" │
│                                     │
└─────────────────────────────────────┘
```

**Implementation:**
- Email + password form
- On submit, call `POST /api/poster/auth/login` (proxied to `NEXT_PUBLIC_API_URL`)
- On success (200), stores `accessToken` and `refreshToken` in httpOnly cookies; redirects to `/poster/dashboard`
- On failure (401), shows inline error: `"Invalid email or password"`
- On failure (403) with `status: 'pending'`: shows warning: `"Your account is pending review. You'll receive an email when approved."`
- On failure (403) with `status: 'suspended'`: shows error: `"Your account has been suspended. Contact support@industrynight.net"`
- "Request Access" link → directs to self-serve registration form (implement at `POST /api/poster/auth/register` from E0 backend, or link to external Typeform)
- "Forgot Password?" link → placeholder (future feature)

### 4. `/poster/dashboard` — Overview

Stats section (cards):
- **Active Jobs** — count of jobs with status = 'active'
- **Total Applicants** — sum of applicant counts across all active jobs
- **Pending Applications** — count of applications with status in ['submitted', 'viewed']
- **Your Rating** — average star rating ⭐ from all confirmed hires; also show total count (e.g., "4.8★ from 12 confirmed hires"). If < 3 confirmed hires, show "Build your reputation — confirm hires and invite ratings"

Recent activity feed (last 10 items across all jobs):
- Application submitted: "Alice Johnson applied to 'Senior Photographer' (5 min ago)"
- Application shortlisted: "Bob Smith shortlisted for 'Creative Director' (2 hours ago)"
- Hire offered: "Carol Davis offered 'Makeup Artist' role (1 day ago)"
- Hire confirmed: "David Lee confirmed hire for 'Producer' + rating (3 days ago)"
- New rating received: "Eve Martinez rated you 5★ for 'Hair Stylist' hire (5 days ago)"

Quick action buttons:
- "Post a Job" → route to `/poster/jobs/create`
- "View All Applicants" → route to `/poster/applicants`

Data fetched from `GET /api/poster/dashboard` with `Authorization: Bearer {accessToken}`. Response includes:
```json
{
  "activeJobsCount": 5,
  "totalApplicantsCount": 42,
  "pendingApplicationsCount": 8,
  "averageRating": 4.8,
  "totalRatings": 12,
  "recentActivity": [
    {
      "type": "application_submitted",
      "applicantName": "Alice Johnson",
      "jobTitle": "Senior Photographer",
      "timestamp": "2026-03-22T14:30:00Z"
    },
    ...
  ]
}
```

Loading state: skeleton cards while fetching
Error state: "Failed to load dashboard" with a retry button

### 5. `/poster/jobs` — Job listings table

```
┌──────────────────────────────────────────────────────────────────────┐
│ My Job Listings                      [+ Post a New Job]              │
├──────────────────────────────────────────────────────────────────────┤
│ Title             │Type       │Status   │Applicants│Posted │Expires │
├──────────────────────────────────────────────────────────────────────┤
│ Senior Photog...  │Full-time  │Active   │    8     │Mar 15 │Apr 12  │
│ Makeup Artist     │Gig        │Active   │   12     │Mar 20 │Apr 19  │
│ Producer          │Part-time  │Filled   │   —      │Feb 28 │Mar 28  │
│ Camera Op (draft) │Freelance  │Draft    │    0     │(unpub)│—       │
└──────────────────────────────────────────────────────────────────────┘
```

Table columns:
- **Title** — job title, truncated with ellipsis if long
- **Type** — badge: Full-time, Part-time, Freelance, Gig, Internship
- **Status** — badge (styled):
  - Draft (grey)
  - Active (green)
  - Filled (blue)
  - Expired (orange)
  - Cancelled (red)
- **Applicants** — count of applicants (linked to `/poster/jobs/:id`)
- **Posted** — date posted (relative, e.g., "2 days ago" or formatted date)
- **Expires** — expiration date or relative time until expiry

Row actions (right-click menu or inline buttons):
- View → navigate to `/poster/jobs/:id`
- Edit → navigate to `/poster/jobs/:id/edit` (draft or active only)
- Mark Filled → PATCH `/api/poster/jobs/:id` with `status: 'filled'` (active only)
- Extend Expiry → modal with date picker (active only)
- Cancel → confirmation modal, then PATCH `status: 'cancelled'` (active only; cancels remaining applications)
- Delete → PATCH `status: 'deleted'` (draft only)

Create Job button at top-right → `/poster/jobs/create`

Loading state: skeleton table rows
Empty state: "No jobs yet. [Post your first job] →"

Data fetched from `GET /api/poster/jobs` with pagination (default 20 per page).

### 6. `/poster/jobs/create` and `/poster/jobs/:id/edit` — Job form

Form fields:
- **Title** (text input, required, max 100 chars)
- **Job Type** (segmented control or dropdown, required): Full-time, Part-time, Freelance, Gig, Internship
- **Description** (rich text or textarea, required, min 100 chars, max 5000)
- **Required Specialties** (multi-select from `/specialties` endpoint, required, up to 5)
- **Location Type** (segmented control, required): On-site, Remote, Hybrid
- **Location (City, State)** (text inputs, shown only if not remote)
- **Compensation Type** (select, required): Hourly, Annual, Project, Negotiable
- **Compensation Amount** (number inputs for min/max, or text note for Negotiable)
  - If Hourly: min/max hourly rate
  - If Annual: min/max salary
  - If Project: total project fee
  - If Negotiable: free-form note, e.g., "Market rate based on experience"
- **Is Urgent** (toggle) — flag for priority display in social app
- **Job Duration** (select, if freelance/gig): 1 week, 2 weeks, 1 month, 3 months, ongoing

Save and publish buttons:
- "Save as Draft" → PATCH with `status: 'draft'` (shows confirmation: "Saved. Publish when ready.")
- "Publish" → POST with `status: 'active'` if create, or PATCH if edit (shows confirmation: "Job published! Applicants will see it in the app.")

**Publish validation gate:**
Must have:
1. Title
2. Description (min 100 chars)
3. Job type
4. At least 1 specialty
5. Location type
6. Compensation type

If any missing, show error banner above form with list of required fields.

**Account status gate:**
If poster `status: 'pending'`, show warning banner:
> "Your account is awaiting approval. You can draft jobs but cannot publish until approved. We'll email you when you're ready to go live."

Disable the "Publish" button; allow "Save as Draft" only.

If poster `status: 'suspended'`, show error banner and disable form:
> "Your account has been suspended. You cannot create or edit jobs. Contact support."

Data:
- On create: POST `/api/poster/jobs` with form data
- On edit: load job from `GET /api/poster/jobs/:id`, populate form, then PATCH on submit
- On success: navigate to `/poster/jobs/:id` for created, or back to `/poster/jobs` for edited

### 7. `/poster/jobs/:id` — Job detail + Applicant management

```
┌──────────────────────────────────────────────────────────────────┐
│ Senior Photographer                    [Edit] [Mark Filled] [x]   │
├──────────────────────────────────────────────────────────────────┤
│ Status: Active (3 days remaining)                                 │
│ Views: 124 | Applicants: 8 | Posted: Mar 20, 2026                │
├──────────────────────────────────────────────────────────────────┤
│ Job Description, specialties, location, compensation             │
├──────────────────────────────────────────────────────────────────┤
│ Filter: [All] [New] [Shortlisted] [Hired] [Declined]             │
├──────────────────────────────────────────────────────────────────┤
│ Applicants:                                                       │
│ ┌────────────────────────────────────────────────────────────┐   │
│ │ Alice Johnson       | Photography | ⭐ 4.9 (8 hires)       │   │
│ │ Applied: 3h ago     | Portfolio: [link]                     │   │
│ │ "Great work. Looking forward to this project!"              │   │
│ │                                                             │   │
│ │ [View Profile] [Shortlist] [Hire] [Decline]               │   │
│ └────────────────────────────────────────────────────────────┘   │
│ ... more applicant cards ...                                      │
└──────────────────────────────────────────────────────────────────┘
```

**Header:**
- Job title (h1)
- Status badge (Active, Filled, Expired, Cancelled) with time remaining if active
- Stats row: views count, applicants count, posted date
- Action buttons (Edit, Mark Filled, Cancel, Delete — filtered by status)

**Applicant section:**

Filter pills (horizontal): All, New (submitted), Shortlisted, Hired, Declined
- Clicking a filter refetches applicants with `?status=<filter>` query param
- Active filter highlighted/underlined
- Refresh button to re-fetch

Applicant card (per applicant):
```
┌─────────────────────────────────────────┐
│ [Avatar] Name | Primary Specialty       │
│ Applied: X ago | Status badge           │
│ Cover note preview (2-3 lines, click    │
│ to expand inline or open modal)         │
│ [Portfolio link] (if provided)          │
│ [Rating: 4.8★] (if they have rating)    │
│ [Hire Confirmed ✓ | Pending] (if hired) │
│                                         │
│ [View Profile] [Shortlist] [Hire]      │
│ [Decline]                               │
│                                         │
│ OR (if hired):                          │
│ [View Profile] [Rate] [Remove Hire]    │
│                                         │
│ OR (if hire confirmed + rated):         │
│ [View Profile] [Remove Hire]           │
└─────────────────────────────────────────┘
```

**Actions:**

- **View Profile** → opens a right-side drawer/modal with:
  - Full applicant profile from social app: name, specialties, bio, social links, hire history (if any), ratings received
  - Recent posts or portfolio (if available)
  - Close button (X) at top-right
  - Uses `GET /api/applicants/:id` (from E0 backend)

- **Shortlist** → PATCH `/api/poster/jobs/:id/applications/:appId` with `status: 'shortlisted'`
  - Shows confirmation toast: "Applicant shortlisted!"
  - Sends FCM to applicant: "Good news! [Poster name] shortlisted your application for [Job title]."
  - Card status updates to Shortlisted

- **Hire** → PATCH with `status: 'hired'`
  - Shows confirmation toast: "Job offer sent!"
  - Sends FCM to applicant: "You've been offered [Job title] by [Poster name]. Confirm to start the engagement."
  - Applicant must confirm via E2 hire confirmation flow
  - Card now shows [Hire Confirmed ✓ | Pending Confirmation]

- **Decline** → PATCH with `status: 'declined'`
  - Shows confirmation modal: "Decline this applicant?"
  - On confirm, sends FCM: "Thank you for applying. We've decided to move forward with other candidates."
  - Card status updates

- **Rate** → opens rating modal (only visible after hire confirmed):
  - Star rating (1-5) with hover highlight
  - Text field for optional comment (max 500 chars)
  - [Submit Rating] button
  - On success, calls POST `/api/poster/jobs/:id/applications/:appId/ratings` (from E2 spec)
  - Shows confirmation: "Rating saved!"
  - On second attempt (409 Conflict), shows: "You've already rated this hire."
  - Card now shows [Hire Confirmed ✓ | Rated]

Data:
- Load job from `GET /api/poster/jobs/:id` (includes full details)
- Load applicants from `GET /api/poster/jobs/:id/applications?status=<filter>` (default: all)
- On action (shortlist/hire/decline/rate), call appropriate PATCH/POST endpoint

### 8. `/poster/applicants` — All applicants across all jobs (unified view)

```
┌──────────────────────────────────────────────────────────────────┐
│ All Applicants                                                    │
├──────────────────────────────────────────────────────────────────┤
│ Filter: [All] [New] [Shortlisted] [Hired] [Declined]  [Search]   │
│ Group by: [Job] [Status] [None]                                  │
├──────────────────────────────────────────────────────────────────┤
│ For Job: Senior Photographer                                      │
│ ├─ Alice Johnson (shortlisted)                                    │
│ ├─ Bob Smith (new)                                                │
│ └─ Carol Davis (hired, pending confirmation)                      │
│                                                                   │
│ For Job: Makeup Artist                                            │
│ ├─ David Lee (hired, confirmed, rated)                            │
│ └─ Eve Martinez (declined)                                        │
└──────────────────────────────────────────────────────────────────┘
```

**Filters & grouping:**
- Status filter: All, New (submitted), Shortlisted, Hired, Declined
- Search box: filters by applicant name
- Group by: Job (grouped view showing which job each applicant applied to), Status (grouped by status), None (flat list)

**Display:**
- If grouped by Job: show job title as section header, then list applicants
- If grouped by Status: show status as section header, then list applicants
- If no grouping: flat list with job title shown inline

Each applicant row (lightweight):
- Applicant name + primary specialty
- Applied date (relative)
- Status badge
- Job title (if not grouped by job)
- Inline action buttons or context menu (View, Shortlist, Hire, Decline, Rate)

Data: `GET /api/poster/applicants?status=<filter>&q=<search>&groupBy=<job|status|none>` (paginated)

### 9. `/poster/profile` — Account settings + rating display + password change

```
┌─────────────────────────────────────────────────────────┐
│ Account Settings                                        │
├─────────────────────────────────────────────────────────┤
│ Business Information                                    │
│ Business Name        [Acme Studios]                    │
│ Logo Upload          [Upload] [Remove]                 │
│ Website URL          [https://...]                     │
│ Business Type        [Production House ▼]              │
│ Contact Phone        [555-1234]                        │
│ [Save Changes]                                         │
│                                                        │
├─────────────────────────────────────────────────────────┤
│ Your Reputation                                        │
│ Average Rating: 4.8★ (12 confirmed hires)              │
│ ├─ 5★: 10 ratings                                     │
│ ├─ 4★: 2 ratings                                      │
│ ├─ 3★: 0 ratings                                      │
│ ├─ 2★: 0 ratings                                      │
│ └─ 1★: 0 ratings                                      │
│                                                        │
│ Recent Ratings:                                        │
│ "Alice was a fantastic collaborator! Highly           │
│  recommend." — 5★ (13 days ago)                       │
│ "Great work, will hire again." — 4★ (27 days ago)     │
│                                                        │
├─────────────────────────────────────────────────────────┤
│ Change Password                                        │
│ Current Password     [____________]                    │
│ New Password         [____________]                    │
│ Confirm New Password [____________]                    │
│ [Change Password]                                      │
│                                                        │
├─────────────────────────────────────────────────────────┤
│ [!] Danger Zone                                        │
│ [Request Account Deletion]                            │
│ (Sends email to support with account ID)              │
└─────────────────────────────────────────────────────────┘
```

**Business info section:**
- Text inputs: businessName, websiteUrl, contactPhone
- Dropdown: businessType (Production House, Salon, Studio, Talent Agency, Photography Studio, Freelancer, Other)
- Logo upload: calls `POST /api/poster/profile/logo` (multipart, max 5MB)
  - Shows preview of current logo
  - [Remove] button to delete (calls `DELETE /api/poster/profile/logo`)
  - Success feedback: "Logo updated!"
- [Save Changes] button → PATCH `/api/poster/profile` with updates
  - Shows success toast on save

**Rating display section:**
- If < 3 confirmed hires: show message:
  > "Build your reputation — confirm hires and invite ratings. Once you've hired 3 people and they've rated you, your reputation will appear here."

- If >= 3 confirmed hires:
  - Average rating (large, bold) + star count (e.g., "4.8★ from 12 confirmed hires")
  - Horizontal bar chart or breakdown: 5★ (X ratings), 4★ (Y ratings), etc.
  - List of recent rating comments (3-5 most recent)
    - Comment text (truncated if > 200 chars)
    - Star rating badge
    - Date (relative, e.g., "2 weeks ago")
    - Applicant name is anonymized (show initials or generic "A Hired Creative")

Data: fetch from `GET /api/poster/profile` and `GET /api/poster/ratings`

**Password change section:**
- Current password (required)
- New password (required, min 8 chars, strength indicator)
- Confirm password (required)
- [Change Password] button → POST `/api/poster/auth/change-password` with old + new password
  - On success: "Password updated!" + clears form
  - On failure (401): "Current password is incorrect."
  - On failure (400): "New passwords don't match."

**Danger zone:**
- [Request Account Deletion] button
  - Shows confirmation modal: "Delete your account? This action is permanent. All your jobs and data will be archived."
  - Sends email to support@industrynight.net with poster account ID
  - Shows message: "Deletion request sent. We'll follow up with you shortly."
  - Poster account is not immediately deleted (manual review by support)

### 10. `/poster/billing` — Placeholder

Simple placeholder screen:
```
┌───────────────────────────────────────┐
│ Billing & Credits (Coming Soon)       │
│                                       │
│ Track your job posting credits and    │
│ billing history. Stripe integration   │
│ coming in Q2 2026.                    │
│                                       │
│ Questions? support@industrynight.net  │
└───────────────────────────────────────┘
```

No backend implementation needed yet. Scaffold the route and page skeleton.

### 11. Shared Portal Components

**`components/poster/PosterSidebar.tsx`**
- Navigation sidebar specific to poster portal
- Links: Dashboard, My Jobs, All Applicants, Account, Billing
- Collapses to icon-only on mobile
- Shows business name and logo at top
- Logout button at bottom

**`components/poster/PosterTopbar.tsx`**
- Poster business name / email
- Account status badge (Pending, Active, Probationary, Suspended)
- Logout button
- Settings link (to `/poster/profile`)

**`components/poster/PosterStatusBanner.tsx`**
- Conditional warning/info banner shown at top of routes if:
  - Account pending: "Your account is pending review..."
  - Account probationary: "Your account is on probation. [Learn more]"
  - Account suspended: "Your account has been suspended. [Contact support]"
- Styled with appropriate color (info/warning/error)

**`components/poster/ApplicantCard.tsx`**
- Reusable card showing a single applicant (used in `/jobs/:id` and `/applicants`)
- Props: applicant (name, specialty, rating, hireStatus), job (title), actions (shortlist/hire/decline/rate)
- Shows avatar, name, specialty, applied date, cover note preview, actions
- Dynamically shows different action buttons based on application status
- Handles action callbacks via props

**`components/poster/ApplicantProfileDrawer.tsx`**
- Right-side slide-in panel showing full applicant profile
- Fetched from `GET /api/applicants/:id`
- Shows: full name, specialties, bio, social links, hire history (if any), verified badge
- Recent posts or portfolio (if available)
- Close button (X) at top-right

**`components/poster/RatingDisplay.tsx`**
- Star rating component (1-5, with hover)
- Optional comment text
- Used in rating modals and profile page
- Props: rating (number), comment (string), applicantName (optional)

**`components/poster/JobStatusBadge.tsx`**
- Colored badge for job statuses: Draft (grey), Active (green), Filled (blue), Expired (orange), Cancelled (red)
- Props: status, compact (optional boolean for icon-only)

**`components/poster/ApplicationStatusBadge.tsx`**
- Colored badge for application statuses: Submitted (blue), Shortlisted (purple), Hired (green), Declined (grey), Rated (gold)
- Props: status, hireConfirmed (boolean), isRated (boolean)

**`components/poster/RatingModal.tsx`**
- Modal for rating a hired applicant
- Star picker (1-5)
- Comment text area
- [Submit] and [Cancel] buttons
- Props: applicantName, jobTitle, onSubmit callback

**`lib/poster-auth/usePosterAuth.ts`**
- Custom hook for poster authentication
- Returns: { poster, login(), logout(), isLoading, error }
- Handles token storage, refresh, and account status

---

## Acceptance Criteria

- [ ] Job poster can log in at `/poster/login` with email + password; cannot access `/admin` routes (JWT family isolation enforced)
- [ ] Account status gate enforced: pending → can draft, cannot publish; active/probationary → full access; suspended → cannot access
- [ ] Dashboard displays real stats from `GET /api/poster/dashboard`; recent activity feed shows all activity types
- [ ] Job listing creation: form validation passes; publish gate enforced (missing fields show error)
- [ ] Job listing editing: can edit draft or active jobs; status changes reflected in table
- [ ] Job table: status badges color-coded; applicant count clickable; actions (Edit, Mark Filled, Cancel, Delete) work correctly
- [ ] Job detail screen: applicants load from API; filter by status works; applicant cards show correct action buttons based on status
- [ ] Shortlist action: PATCH call succeeds; card status updates; FCM sent to applicant (mock verification)
- [ ] Hire action: PATCH call succeeds; card shows "Pending Confirmation"; FCM sent to applicant
- [ ] After hire confirmed (via E2): card shows "Hire Confirmed ✓"; "Rate" button appears
- [ ] Rate action: opens modal; star picker works; comment optional; POST call succeeds; card shows "Rated" badge; second attempt shows 409 error
- [ ] Applicants page: filter by status works; search by name works; grouping toggles between Job/Status/None; actions same as job detail
- [ ] Profile page: business info form saves with PATCH call; logo upload calls correct endpoint; password change validates and calls POST endpoint; password errors shown
- [ ] Rating display: hidden if < 3 confirmed hires; visible if >= 3 with average, breakdown, and recent comments
- [ ] Logout clears tokens and redirects to `/poster/login`; trying to access protected routes redirects to login
- [ ] No cross-app token reuse: admin JWT rejected at poster routes; poster JWT rejected at admin routes (tokenFamily validation)

**File structure created:**
```
packages/react-admin/
├── app/
│   ├── (poster)/
│   │   ├── layout.tsx              # Protected layout, redirects to /poster/login if not auth'd
│   │   ├── page.tsx                # Redirects to /poster/dashboard
│   │   ├── login/page.tsx          # Login form
│   │   ├── dashboard/page.tsx      # Dashboard with stats + activity feed
│   │   ├── jobs/
│   │   │   ├── page.tsx            # Jobs list table
│   │   │   ├── create/page.tsx     # Create job form
│   │   │   └── [id]/
│   │   │       ├── page.tsx        # Job detail + applicant management
│   │   │       └── edit/page.tsx   # Edit job form
│   │   ├── applicants/page.tsx     # All applicants with filters + grouping
│   │   ├── profile/page.tsx        # Account settings + ratings
│   │   └── billing/page.tsx        # Placeholder
│   └── api/
│       └── [...path]/route.ts      # Updated to handle poster auth routes
├── components/poster/
│   ├── PosterSidebar.tsx
│   ├── PosterTopbar.tsx
│   ├── PosterStatusBanner.tsx
│   ├── ApplicantCard.tsx
│   ├── ApplicantProfileDrawer.tsx
│   ├── RatingDisplay.tsx
│   ├── JobStatusBadge.tsx
│   ├── ApplicationStatusBadge.tsx
│   └── RatingModal.tsx
├── lib/poster-auth/
│   ├── index.ts                    # Context + provider
│   ├── session.ts                  # Token storage
│   └── usePosterAuth.ts            # Hook
├── middleware.ts                   # Updated to protect /poster routes
└── ... (other existing files)
```

---

## User Stories

| Actor | Story | Notes |
|-------|-------|-------|
| Job Poster | As a salon owner, I log into the poster portal and see my active listings and new applicants at a glance on the dashboard | Dashboard shows real stats |
| Job Poster | As a studio manager, I create a new job listing, fill in all required fields, and publish it — it appears in my jobs table as Active | Job form validation + publish gate |
| Job Poster | As a job poster, I review applicants for one of my jobs, shortlist the promising ones, and hire the best fit — all within the job detail screen | Applicant management |
| Job Poster (Hiring) | As a job poster who offered a job, I wait for the applicant's confirmation. Once they confirm, I see a "Hire Confirmed ✓" badge and a "Rate" button appears | E2 hire confirmation flow integration |
| Job Poster (Rating) | As a job poster who confirmed a hire, I rate the creative I hired (1-5 stars + optional comment) and see my own rating average grow on my profile | Rating system from E2 |
| Job Poster (Probation) | As a new job poster in probation, I see a banner explaining that my account will be fully activated after 30 days of good hiring/rating behavior | Account status messaging |
| Job Poster (Suspended) | As a suspended job poster, my login shows a message and I cannot access the portal; only support can reactivate my account | Account suspension gate |

---

## Test Suite

### Vitest Unit Tests

**`__tests__/poster-auth.test.ts`**
```typescript
describe('usePosterAuth', () => {
  it('logs in with valid email/password', async () => {
    // Mock POST /api/poster/auth/login
    // Verify tokens stored in cookies
    // Verify redirect to /dashboard
  });

  it('shows error on invalid credentials', async () => {
    // Mock 401 response
    // Verify error message displayed
  });

  it('rejects admin JWT (tokenFamily mismatch)', async () => {
    // Simulate admin token; verify it's rejected at poster routes
  });

  it('silently refreshes on mount', async () => {
    // Verify useEffect calls refresh endpoint on mount
  });

  it('auto-redirects to login on refresh failure', async () => {
    // Simulate 401 on refresh
    // Verify tokens cleared, redirect to /poster/login
  });

  it('logs out and clears tokens', async () => {
    // Call logout()
    // Verify tokens cleared
    // Verify redirect to /poster/login
  });
});
```

**`__tests__/applicant-card.test.tsx`**
```typescript
describe('ApplicantCard', () => {
  it('renders applicant info: name, specialty, applied date', () => {
    // Verify name, specialty, applied date shown
  });

  it('shows correct action buttons based on application status', () => {
    // status: 'submitted' → [View Profile] [Shortlist] [Hire] [Decline]
    // status: 'shortlisted' → [View Profile] [Hire] [Decline]
    // status: 'hired' (not confirmed) → [View Profile] [View] [Remove Hire]
    // status: 'hired' (confirmed) → [View Profile] [Rate] [Remove Hire]
    // status: 'hired' (confirmed + rated) → [View Profile] [Remove Hire]
    // status: 'declined' → [View Profile]
  });

  it('calls shortlist callback on [Shortlist] click', () => {
    // Verify onShortlist() called
  });

  it('calls hire callback on [Hire] click', () => {
    // Verify onHire() called
  });

  it('calls decline callback on [Decline] click', () => {
    // Verify onDecline() called
  });

  it('calls rate callback on [Rate] click', () => {
    // Verify onRate() called; opens modal
  });

  it('shows hire confirmation status badge if hired', () => {
    // hireConfirmed: true → shows "✓ Confirmed"
    // hireConfirmed: false → shows "⏳ Pending"
  });

  it('shows rating badge if applicant has been rated', () => {
    // Verify "⭐ 4.8" badge shown
  });
});
```

**`__tests__/job-status-badge.test.tsx`**
```typescript
describe('JobStatusBadge', () => {
  it('renders correct color for each status', () => {
    // 'draft' → grey
    // 'active' → green
    // 'filled' → blue
    // 'expired' → orange
    // 'cancelled' → red
  });
});
```

### Playwright E2E Tests

**`e2e/poster-login.spec.ts`**
```typescript
test('login with valid credentials redirects to dashboard', async ({ page }) => {
  // Navigate to /poster/login
  // Fill email + password
  // Click Sign In
  // Verify redirect to /poster/dashboard
  // Verify dashboard stats visible
});

test('login with invalid credentials shows error', async ({ page }) => {
  // Fill invalid email + password
  // Click Sign In
  // Verify error message "Invalid email or password"
  // Verify still on /poster/login
});

test('pending account shows status warning', async ({ page }) => {
  // Mock API response with status: 'pending'
  // Attempt login
  // Verify error message: "Your account is pending review..."
  // Verify still on /poster/login
});

test('suspended account shows suspension message', async ({ page }) => {
  // Mock API response with status: 'suspended'
  // Attempt login
  // Verify error message: "Your account has been suspended..."
  // Verify still on /poster/login
});

test('unauthenticated access to /poster/dashboard redirects to login', async ({ page }) => {
  // Clear cookies
  // Navigate to /poster/dashboard
  // Verify redirect to /poster/login
});

test('logout clears session and redirects to login', async ({ page }) => {
  // Log in first
  // Click logout button
  // Verify redirect to /poster/login
  // Try to access /poster/dashboard → redirect to /poster/login
});
```

**`e2e/poster-jobs.spec.ts`**
```typescript
test('create draft job, then publish', async ({ page }) => {
  // Log in
  // Click "Post a New Job"
  // Fill form: title, type, description, specialties, location, compensation
  // Click "Save as Draft"
  // Verify job appears in table with status "Draft"
  // Click Edit
  // Click "Publish"
  // Verify job now shows status "Active" in table
  // Verify toast: "Job published!"
});

test('publish validation: missing required fields shows error', async ({ page }) => {
  // Click "Post a New Job"
  // Leave fields empty
  // Click "Publish"
  // Verify error banner listing missing fields
  // Verify form not submitted
});

test('account pending: cannot publish, can save as draft', async ({ page }) => {
  // Mock account status: 'pending'
  // Navigate to job create
  // Verify banner: "Your account is awaiting approval..."
  // Verify "Publish" button disabled
  // Verify "Save as Draft" enabled
});

test('edit job and see changes', async ({ page }) => {
  // Log in
  // Navigate to /poster/jobs
  // Click Edit on an active job
  // Change title
  // Click save
  // Verify title changed in table
});

test('mark job as filled', async ({ page }) => {
  // Click on an active job in table
  // Click "Mark Filled"
  // Verify status badge changes to "Filled"
  // Verify applicants can no longer apply
});
```

**`e2e/poster-applicants.spec.ts`**
```typescript
test('view job detail and shortlist applicant', async ({ page }) => {
  // Navigate to job detail
  // Find applicant card
  // Click "Shortlist"
  // Verify card status updates
  // Verify toast: "Applicant shortlisted!"
});

test('hire applicant and wait for confirmation', async ({ page }) => {
  // Click "Hire" on applicant
  // Verify card shows "⏳ Pending Confirmation"
  // Verify toast: "Job offer sent!"
  // (In real flow, applicant confirms via E2; mock this)
  // Verify card updates to "✓ Confirmed" after confirmation
});

test('rate applicant after hire confirmed', async ({ page }) => {
  // Find hired+confirmed applicant
  // Click "Rate"
  // Select 5 stars
  // Fill comment: "Great work!"
  // Click Submit
  // Verify card shows "⭐ Rated" badge
  // Verify toast: "Rating saved!"
  // Click Rate again
  // Verify error: "You've already rated this hire."
});

test('decline applicant', async ({ page }) => {
  // Click "Decline" on applicant
  // Confirm in modal
  // Verify card status updates to "Declined"
  // Verify card only shows [View Profile]
});

test('view applicant profile drawer', async ({ page }) => {
  // Click "View Profile" on applicant
  // Verify drawer opens on right side
  // Verify profile data: name, specialties, bio, social links, hire history
  // Click X to close drawer
  // Verify drawer closes
});

test('all applicants page: filter by status', async ({ page }) => {
  // Navigate to /poster/applicants
  // Verify all applicants shown by default
  // Click "Shortlisted" filter
  // Verify only shortlisted applicants shown
  // Click "Hired" filter
  // Verify only hired applicants shown
});

test('all applicants page: search by name', async ({ page }) => {
  // Navigate to /poster/applicants
  // Type "Alice" in search box
  // Verify applicants list filters to show only "Alice"
});

test('all applicants page: group by job', async ({ page }) => {
  // Navigate to /poster/applicants
  // Select "Group by: Job"
  // Verify applicants are grouped under their respective job titles
});
```

**`e2e/poster-profile.spec.ts`**
```typescript
test('update business info', async ({ page }) => {
  // Navigate to /poster/profile
  // Change businessName, websiteUrl, contactPhone
  // Click "Save Changes"
  // Verify changes persisted (reload page)
});

test('upload and remove logo', async ({ page }) => {
  // Click "Upload" logo button
  // Select image file
  // Verify logo preview shown
  // Click "Remove"
  // Verify logo cleared
});

test('change password', async ({ page }) => {
  // Fill current password (correct)
  // Fill new password + confirm
  // Click "Change Password"
  // Verify toast: "Password updated!"
  // Log out and log back in with new password
  // Verify successful login
});

test('change password with wrong current password', async ({ page }) => {
  // Fill current password (wrong)
  // Fill new password + confirm
  // Click "Change Password"
  // Verify error: "Current password is incorrect."
});

test('rating display: hidden if < 3 confirmed hires', async ({ page }) => {
  // Mock poster with 2 confirmed hires
  // Navigate to /poster/profile
  // Verify message: "Build your reputation..."
  // Verify no star rating shown
});

test('rating display: visible if >= 3 confirmed hires', async ({ page }) => {
  // Mock poster with 5 confirmed hires, avg 4.8 rating
  // Navigate to /poster/profile
  // Verify star rating: "4.8★ from 5 confirmed hires"
  // Verify breakdown chart (5★, 4★, etc.)
  // Verify recent rating comments shown
});
```

---

## Completion Report

> To be filled in by the executing agent after implementation is complete.

**Branch:** `feature/E3-job-poster-portal`
**Option chosen:** A (separate app) or B (route group in react-admin)
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

### Integration notes for E0 + E2 backend handoff
- List any API changes or missing endpoints discovered
- Any assumptions about backend response formats
- Notes for scaling (job limits, applicant pagination, image upload size limits)

### Option A vs Option B Trade-offs (if choosing A)
- If separate app: infrastructure complexity added, but clearer separation
- If route group (B): simpler ops, but increases react-admin package size and risk

---

## Interrogative Session

**Agent Q1: Architecture choice — did you choose A or B? What would tip it toward the other?**
> Jeff:

**Agent Q2: Does the job poster UI/UX feel intuitive for business users (not as technical as platform admins)? Any friction points?**
> Jeff:

**Agent Q3: How does this integrate with the social app's job discovery flow? Are we confident applicants see these jobs?**
> Jeff:

**Jeff Q1: The reputation/rating system — should job posters be able to dispute or delete ratings? How do we handle bad actors?**
> Agent:

**Jeff Q2: Job posting costs — I assume posters buy credits upfront. Should we gate publishing by credit balance?**
> Agent:

**Jeff Q3: Data privacy — applicant profile info is sensitive. Are we confident we're not leaking data across accounts (other posters seeing each other's applicants)?**
> Agent:

---

## Notes

**🎉 CODEX Library Complete:** E3 is the final prompt in the Industry Night CODEX execution library.

After E3 merges to `integration` and all tests pass:
1. The full platform is operational — **social app (A track)**, **React admin (B track)**, **jobs board (E track)**, **LLM pipeline (C/D tracks)**, and **analytics (F track)**
2. Update `CODEX_TRACKER.xlsx` (if tracking) to mark all tracks complete ✓
3. Schedule a platform retrospective with Jeff:
   - What worked well in the CODEX system?
   - What slowed us down?
   - Lessons for the next product cycle
   - Celebrate 🎊

**Branching strategy:** Feature branch → `integration` PR → code review → adversarial review (if applicable) → merge → wait for all CI checks → manual smoke test on dev → PR to `master` → production deploy.

**Known gaps in this spec (future work):**
- Poster account creation / self-serve registration (E0 backend handles it; link in login → external form or email)
- Stripe integration for job posting credits (placeholder at `/poster/billing`)
- Job posting limits per credit tier (backend enforcement in E0)
- Dispute/appeal system for ratings (post-MVP)
- Bulk actions on applicants (multi-select, batch status change) (post-MVP)
- Email notifications (integration with SES in backend) (post-MVP)
- Analytics dashboard for posters (job performance, applicant funnel) (post-MVP)
