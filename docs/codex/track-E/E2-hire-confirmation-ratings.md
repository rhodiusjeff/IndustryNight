# [Track-E2] Hire Confirmation + Professional Ratings

**Track:** E (Jobs Board)
**Sequence:** 2 of 4 in Track E
**Model:** claude-sonnet-4-6
**Alternate Model:** gpt-5.4
**A/B Test:** No
**Estimated Effort:** Medium (8-12 hours)
**Dependencies:** E0 (schema with job_applications table), E1 (social app job browsing UI), D0 (moderation pipeline for rating reviews)

## Execution Mode (Required)

- [ ] Stage 1 (required): execute and validate locally first (local Postgres + local API + local admin/mobile against local endpoint).
- [ ] Stage 2 (required for backend/integration-impacting tracks): run shared-dev integration smoke only after local pass.
- [ ] Stage 3 (required before PR merge): run AWS dev deploy/integration smoke for final confidence.
- [ ] Completion log must explicitly record: execution mode used, exact commands run, evidence links, and cleanup actions.


---

## Context

Read these before writing any code:

- `CLAUDE.md` — full project reference, especially gotchas #6 (build_runner), #12 (dialog context), #13 (GoRouter refreshListenable), #14 (JWT auto-refresh)
- `docs/product/requirements.md` — product overview of Jobs Board track
- `packages/database/migrations/001_baseline_schema.sql` — job_applications table schema (created in E0)
- `packages/api/src/routes/jobs/index.ts` — existing job endpoints (E0, E1)
- `packages/shared/lib/models/job_application.dart` — JobApplication model with hired_at, hired_confirmed_at, rating, poster_rating fields
- `packages/social-app/lib/features/jobs/screens/my_applications_screen.dart` — list of user's applications (E1)
- `packages/shared/lib/api/jobs_api.dart` — JobsApi client
- `docs/codex/track-D/D0-moderation-pipeline.md` — moderation endpoint for screening short text (rating comments)

---

## Goal

Implement a two-way professional ratings system triggered after job confirmation. When a job poster marks an applicant as "hired", the applicant receives a push notification and confirms the hire. 24 hours after confirmation, both parties are prompted to rate their experience (1–5 stars, optional comment). Ratings are visible on profiles as aggregated trust signals (min. 3 confirmed hires to show publicly). This creates Tier 2 revenue data: verified hire records with participant satisfaction metrics.

---

## User Stories

| Actor | Story | Notes |
|-------|-------|-------|
| Applicant | As a creative worker offered a job, I receive a push notification so I know I've been selected. | Real-time notification via FCM |
| Applicant | As an applicant, I can confirm the hire in-app with one tap and see my rating prompt appear 24 hours later. | One-tap confirm, no friction |
| Job poster | As a salon owner, when I mark someone hired, I see confirmation they accepted the job before I can rate them. | Job poster rating gate: hired_confirmed_at IS NOT NULL |
| Applicant | As a photographer, I rate a client 5 stars and leave a brief comment about the experience. | 1–5 star UI, optional text (max 300 chars) |
| Job seeker | As someone browsing creative workers on the platform, I see a "⭐ 4.8 (12 hires)" badge on profiles of trusted professionals. | Trust signal on profile cards |
| Admin | As a platform moderator, I review flagged rating comments through the moderation pipeline. | Comments flagged if they contain inappropriate language; moderated via screenPost equivalent |

---

## Technical Spec

### 1. Database Schema (via E0 baseline)

The `job_applications` table (created in E0) includes:
```sql
-- Existing columns (E0)
id UUID PRIMARY KEY,
job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
applicant_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
status job_application_status, -- 'applied', 'hired', 'declined', 'rejected', 'completed'
created_at TIMESTAMP NOT NULL DEFAULT NOW(),

-- Hire confirmation (E2)
hired_at TIMESTAMP,                    -- When job poster marks "hire"
hired_confirmed_at TIMESTAMP,          -- When applicant confirms hire (gates rating prompts)

-- Ratings (E2)
rating SMALLINT,                       -- 1–5 stars (applicant rates job poster)
rating_comment VARCHAR(300),           -- Optional comment (screened for moderation)
rating_submitted_at TIMESTAMP,         -- When rating was submitted (for auditing)
poster_rating SMALLINT,                -- 1–5 stars (job poster rates applicant)
poster_rating_comment VARCHAR(300),    -- Optional comment from poster
poster_rating_submitted_at TIMESTAMP,  -- When poster rating submitted
```

**Unique constraints (to prevent duplicate ratings):**
```sql
-- Only one rating per application (applicant can rate only once)
-- Only one poster rating per application (poster can rate only once)
-- Enforced in application logic: IF rating IS NOT NULL, RETURN 409
```

### 2. Backend — new/extended endpoints

#### `PATCH /jobs/:jobId/applications/:appId` (extend from E0)

**Action: mark as hired**
```
PATCH /jobs/:jobId/applications/:appId
Content-Type: application/json
Authorization: Bearer <job_poster_token>

{
  "status": "hired"
}

Response 200:
{
  "id": "app-123",
  "status": "hired",
  "hired_at": "2026-03-22T14:23:00Z",
  "hired_confirmed_at": null
}
```

**Behavior:**
- Auth: `authenticateJobPoster` (poster must own the job)
- Validates: application exists, belongs to this job, current status allows transition to hired
- Sets: `hired_at = NOW()`
- **Triggers:** Send FCM notification to applicant: "You've been offered the job at {Business Name}! Tap to confirm."
- Response: return updated application with hired_at and null hired_confirmed_at

#### `POST /jobs/applications/:appId/confirm-hire`

**New endpoint: applicant confirms hire**
```
POST /jobs/applications/:appId/confirm-hire
Content-Type: application/json
Authorization: Bearer <applicant_token>

{}

Response 200:
{
  "id": "app-123",
  "status": "hired",
  "hired_at": "2026-03-22T14:23:00Z",
  "hired_confirmed_at": "2026-03-22T15:45:00Z",
  "ratingPromptAt": "2026-03-23T15:45:00Z"
}
```

**Behavior:**
- Auth: `authenticate` (social user, must be the applicant)
- Validates: application exists, status = 'hired', applicant_id = req.user.userId
- Sets: `hired_confirmed_at = NOW()`
- **Triggers:** Schedule rating prompt for 24 hours later (fire-and-forget; no database table needed — use a query-based cron job)
- Notifies: Send FCM to job poster: "{Applicant Name} confirmed the hire!"
- Response: return updated application with hired_confirmed_at and ratingPromptAt (ISO string of NOW() + 24 hours)

#### `POST /jobs/applications/:appId/decline-hire`

**New endpoint: applicant declines hire**
```
POST /jobs/applications/:appId/decline-hire
Content-Type: application/json
Authorization: Bearer <applicant_token>

{}

Response 200:
{
  "id": "app-123",
  "status": "declined",
  "hired_at": "2026-03-22T14:23:00Z",
  "hired_confirmed_at": null
}
```

**Behavior:**
- Auth: `authenticate`
- Validates: application exists, status = 'hired', applicant_id = req.user.userId
- Sets: `status = 'declined'`, `hired_confirmed_at = NULL` (revert confirmation)
- Notifies: Send FCM to job poster: "{Applicant Name} declined the offer."
- Response: return updated application

#### `POST /jobs/applications/:appId/rate-poster`

**New endpoint: applicant rates job poster**
```
POST /jobs/applications/:appId/rate-poster
Content-Type: application/json
Authorization: Bearer <applicant_token>

{
  "rating": 5,
  "comment": "Great experience, very professional!"
}

Response 200:
{
  "id": "app-123",
  "rating": 5,
  "rating_comment": "Great experience, very professional!",
  "rating_submitted_at": "2026-03-23T20:00:00Z"
}
```

**Behavior:**
- Auth: `authenticate`
- Validates:
  - application belongs to applicant (applicant_id = req.user.userId)
  - hired_confirmed_at IS NOT NULL (only confirmed hires can rate)
  - rating IS NULL (prevent duplicate submissions; return 409 Conflict if already rated)
  - rating is 1–5 (integer)
  - comment (if present) is max 300 chars
- Sets: `rating`, `rating_comment`, `rating_submitted_at = NOW()`
- **Triggers:** If comment is present, fire-and-forget: POST to `/admin/moderation/screen-text` (D0 moderation endpoint) with the comment. This flags it for human review if it contains inappropriate language. Do NOT wait for response; do NOT block the rating submission on moderation result.
- Response: return updated application
- Error: 409 Conflict if rating IS NOT NULL with message "You have already rated this job poster."

#### `PATCH /jobs/:jobId/applications/:appId/rate-applicant`

**New endpoint: job poster rates applicant**
```
PATCH /jobs/:jobId/applications/:appId/rate-applicant
Content-Type: application/json
Authorization: Bearer <job_poster_token>

{
  "rating": 4,
  "comment": "Reliable, showed up on time."
}

Response 200:
{
  "id": "app-123",
  "poster_rating": 4,
  "poster_rating_comment": "Reliable, showed up on time.",
  "poster_rating_submitted_at": "2026-03-23T20:15:00Z"
}
```

**Behavior:**
- Auth: `authenticateJobPoster` (must own the job)
- Validates:
  - application exists, belongs to this job
  - hired_confirmed_at IS NOT NULL (applicant must have confirmed)
  - poster_rating IS NULL (prevent duplicates; return 409)
  - rating is 1–5
  - comment (if present) is max 300 chars
- Sets: `poster_rating`, `poster_rating_comment`, `poster_rating_submitted_at = NOW()`
- Triggers: Fire-and-forget moderation of comment (same as applicant rating)
- Response: return updated application
- Error: 409 Conflict if poster_rating IS NOT NULL

#### `GET /users/:userId/ratings`

**New endpoint: get user's aggregate ratings (social-facing, for profile display)**
```
GET /users/550e8400-e29b-41d4-a716-446655440000/ratings

Response 200:
{
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "averageRating": 4.6,
  "totalHires": 12,
  "totalReviews": 11,
  "ratingBreakdown": {
    "5": 8,
    "4": 3,
    "1": 0,
    "2": 0,
    "3": 0
  },
  "displayable": true
}
```

**Behavior:**
- Auth: public (no auth required)
- Query: count confirmed hires (hired_confirmed_at IS NOT NULL) where rating IS NOT NULL (ratings from applicants on this user's jobs)
- Filter: only include ratings from confirmed hires
- Minimum threshold: only return ratings if totalReviews >= 3 (privacy gate; if < 3, return `displayable: false, averageRating: null`)
- Calc: averageRating = SUM(rating) / COUNT(rating); ratingBreakdown = COUNT per star level
- Response: return aggregate object; display: false if too few ratings
- Error: 404 if user not found

#### `GET /job-posters/:jobPosterId/ratings`

**New endpoint: get job poster's aggregate ratings (received from applicants)**
```
GET /job-posters/550e8400-e29b-41d4-a716-446655440000/ratings

Response 200:
{
  "jobPosterId": "550e8400-e29b-41d4-a716-446655440000",
  "averageRating": 4.3,
  "totalHires": 18,
  "totalReviews": 14,
  "ratingBreakdown": {
    "5": 10,
    "4": 3,
    "3": 1,
    "2": 0,
    "1": 0
  },
  "displayable": true
}
```

**Behavior:**
- Auth: public
- Query: for all jobs created by this job poster, count applications where hired_confirmed_at IS NOT NULL AND rating IS NOT NULL
- Minimum threshold: >= 3 reviews to display
- Calc: same as above, but aggregated across all poster's jobs
- Response: return aggregate object

### 3. Rating Prompt Scheduling (Cron Job)

**New routine: query applications needing rating prompts**

Add to `packages/api/src/jobs/index.ts` or create `packages/api/src/jobs/rating-scheduler.ts`:

```typescript
// Run every 1 hour (or daily; adjust based on load)
// Trigger: can also be called manually via admin API or script for testing

async function sendRatingPrompts() {
  const db = getDatabase();

  // Find applications confirmed 24+ hours ago, still within 7-day window, missing ratings
  const applications = await db.query(`
    SELECT
      ja.id,
      ja.applicant_id,
      ja.job_id,
      ja.rating,
      ja.poster_rating,
      u.fcm_token as applicant_fcm,
      j.title as job_title,
      j.created_by as poster_id,
      ju.fcm_token as poster_fcm
    FROM job_applications ja
    JOIN users u ON ja.applicant_id = u.id
    JOIN jobs j ON ja.job_id = j.id
    LEFT JOIN users ju ON j.created_by = ju.id
    WHERE
      ja.hired_confirmed_at IS NOT NULL
      AND ja.hired_confirmed_at < NOW() - INTERVAL '24 hours'
      AND ja.hired_confirmed_at > NOW() - INTERVAL '7 days'
      AND (ja.rating IS NULL OR ja.poster_rating IS NULL)
  `);

  for (const app of applications.rows) {
    // Send to applicant if they haven't rated
    if (app.rating === null && app.applicant_fcm) {
      await sendFcmNotification(app.applicant_fcm, {
        title: 'Rate Your Experience',
        body: `How was working with ${j.title}? Leave a rating to help other creative workers.`,
        data: { screen: 'rate_poster', appId: app.id }
      });
    }

    // Send to poster if they haven't rated
    if (app.poster_rating === null && app.poster_fcm) {
      await sendFcmNotification(app.poster_fcm, {
        title: 'Rate Your Hire',
        body: `How was your experience with this applicant? Your feedback helps us match better talent.`,
        data: { screen: 'rate_applicant', appId: app.id }
      });
    }
  }
}

// Schedule: run daily at 08:00 UTC (or hourly; adjust based on notification volume)
// In production, wire into AWS Lambda + EventBridge or use node-cron
// For now, can be invoked manually via admin endpoint for testing
```

**Manual trigger (for testing):**
```
POST /admin/jobs/send-rating-prompts
Authorization: Bearer <admin_token>

Response 200:
{
  "prompted": 23,
  "applicantPrompts": 15,
  "posterPrompts": 18
}
```

### 4. Social App — Hire Confirmation UI

**File: `packages/social-app/lib/features/jobs/screens/my_applications_screen.dart`**

Add to the applications list:

```dart
// Render "Confirm Hire" banner for hired applications not yet confirmed
if (application.status == JobApplicationStatus.hired &&
    application.hiredConfirmedAt == null) {
  ListTile(
    title: const Text('Job Accepted'),
    subtitle: Text('Confirm your hire at ${application.jobTitle}'),
    trailing: ElevatedButton(
      onPressed: () => _showConfirmHireDialog(application),
      child: const Text('Confirm'),
    ),
  );
}

// Render "Rate {Business Name}" prompt card for applications pending rating
if (application.hiredConfirmedAt != null && application.rating == null) {
  Card(
    margin: const EdgeInsets.all(12),
    child: ListTile(
      title: const Text('Rate Your Experience'),
      subtitle: Text('How was working with ${application.jobTitle}?'),
      trailing: const Icon(Icons.arrow_forward),
      onTap: () => _showRateEmployerSheet(application),
    ),
  );
}
```

**Confirmation dialog:**
```dart
void _showConfirmHireDialog(JobApplication app) {
  showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Confirm Hire'),
      content: Text('Did you accept this position at ${app.jobTitle}?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Yes, Confirm'),
        ),
      ],
    ),
  ).then((confirmed) async {
    if (confirmed == true) {
      try {
        await context.read<AppState>().jobsApi.confirmHire(app.id);
        // Refresh applications list
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hire confirmed!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  });
}
```

**Rating sheet (bottom sheet):**

Create new file `packages/social-app/lib/features/jobs/screens/rate_employer_sheet.dart`:

```dart
class RateEmployerSheet extends StatefulWidget {
  final JobApplication application;
  const RateEmployerSheet({required this.application});

  @override
  State<RateEmployerSheet> createState() => _RateEmployerSheetState();
}

class _RateEmployerSheetState extends State<RateEmployerSheet> {
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submitRating() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await context.read<AppState>().jobsApi.ratePoster(
        widget.application.id,
        _rating,
        comment: _commentController.text.isEmpty ? null : _commentController.text,
      );
      Navigator.pop(context, true); // Signal success to parent
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks for your rating!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Rate ${widget.application.jobTitle}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          // 5-star selector (large, tappable)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final star = i + 1;
              return GestureDetector(
                onTap: () => setState(() => _rating = star),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    _rating >= star ? Icons.star : Icons.star_outline,
                    size: 40,
                    color: Colors.amber,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          // Optional comment
          TextField(
            controller: _commentController,
            maxLength: 300,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Optional: share details about your experience',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitRating,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit Rating'),
            ),
          ),
        ],
      ),
    );
  }
}

// In my_applications_screen.dart, call via:
void _showRateEmployerSheet(JobApplication app) {
  showModalBottomSheet(
    context: context,
    builder: (context) => RateEmployerSheet(application: app),
  ).then((success) {
    if (success == true) {
      setState(() {}); // Refresh list
    }
  });
}
```

### 5. Social App — Profile Rating Badge

**File: `packages/social-app/lib/features/search/screens/user_profile_screen.dart`** (or equivalent A2 profile screen)

Add rating display below user name:

```dart
// Inside build, after user name/bio section
if (user.ratings != null && user.ratings!.displayable) {
  Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star, size: 16, color: Colors.amber),
        const SizedBox(width: 4),
        Text(
          '${user.ratings!.averageRating.toStringAsFixed(1)} '
          '(${user.ratings!.totalHires} hires)',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}
```

Update `User` model in `packages/shared` to include optional `ratings` field (loaded from `/users/:id/ratings` endpoint on profile load).

### 6. Shared Library — Model & API Updates

**File: `packages/shared/lib/models/job_application.dart`**

Add fields to existing JobApplication model:
```dart
@JsonSerializable(fieldRename: FieldRename.snake)
class JobApplication extends Equatable {
  final String id;
  final String jobId;
  final String applicantId;
  final JobApplicationStatus status;
  final DateTime createdAt;

  // E2: hire confirmation
  final DateTime? hiredAt;
  final DateTime? hiredConfirmedAt;

  // E2: ratings
  final int? rating;                   // 1–5 (applicant rates poster)
  final String? ratingComment;         // max 300 chars
  final DateTime? ratingSubmittedAt;
  final int? posterRating;             // 1–5 (poster rates applicant)
  final String? posterRatingComment;
  final DateTime? posterRatingSubmittedAt;

  // ... rest of model
}
```

Run `cd packages/shared && dart run build_runner build --delete-conflicting-outputs` after changes.

**File: `packages/shared/lib/models/user_ratings.dart`** (new file)

```dart
@JsonSerializable(fieldRename: FieldRename.snake)
class UserRatings extends Equatable {
  final String userId;
  final double? averageRating;         // null if not displayable
  final int totalHires;
  final int totalReviews;              // count of ratings (not hires)
  final Map<String, int> ratingBreakdown; // "5": 8, "4": 3, etc.
  final bool displayable;              // true if totalReviews >= 3

  const UserRatings({
    required this.userId,
    required this.averageRating,
    required this.totalHires,
    required this.totalReviews,
    required this.ratingBreakdown,
    required this.displayable,
  });

  // ... fromJson, toJson (via build_runner)
}
```

**File: `packages/shared/lib/models/user.dart`** (update existing)

Add optional ratings field:
```dart
@JsonSerializable(fieldRename: FieldRename.snake)
class User extends Equatable {
  // ... existing fields
  final UserRatings? ratings;  // Loaded separately via /users/:id/ratings

  // ... rest
}
```

**File: `packages/shared/lib/api/jobs_api.dart`** (extend existing)

Add methods:
```dart
Future<void> confirmHire(String applicationId) async {
  await client.post('/jobs/applications/$applicationId/confirm-hire', {});
}

Future<void> declineHire(String applicationId) async {
  await client.post('/jobs/applications/$applicationId/decline-hire', {});
}

Future<void> ratePoster(String applicationId, int rating, {String? comment}) async {
  await client.post(
    '/jobs/applications/$applicationId/rate-poster',
    {
      'rating': rating,
      if (comment != null) 'comment': comment,
    },
  );
}

Future<void> rateApplicant(String jobId, String applicationId, int rating, {String? comment}) async {
  await client.patch(
    '/jobs/$jobId/applications/$applicationId/rate-applicant',
    {
      'rating': rating,
      if (comment != null) 'comment': comment,
    },
  );
}

Future<UserRatings> getUserRatings(String userId) async {
  final response = await client.get('/users/$userId/ratings');
  return UserRatings.fromJson(response);
}

Future<UserRatings> getJobPosterRatings(String jobPosterId) async {
  final response = await client.get('/job-posters/$jobPosterId/ratings');
  return UserRatings.fromJson(response);
}
```

---

## Acceptance Criteria

- [ ] Job poster marks applicant hired → applicant receives FCM notification within 10 seconds with call-to-action "Tap to confirm"
- [ ] Applicant confirms hire via in-app dialog → hired_confirmed_at set, banner disappears, FCM sent to poster
- [ ] Applicant declines hire → status = 'declined', hired_confirmed_at = NULL, poster notified
- [ ] Rating prompt sent 24 hours after hired_confirmed_at (verified manually or via cron test)
- [ ] Applicant can rate poster only on confirmed hires (hired_confirmed_at IS NOT NULL); rating IS NULL gate enforced; 409 on second attempt
- [ ] Job poster can rate applicant only on confirmed hires; 409 on second attempt
- [ ] 1–5 star rating UI renders; 5-star tap selects rating
- [ ] Optional comment field (max 300 chars); counter shows char count
- [ ] Rating submission succeeds and returns 200; optimistic UI update (prompt card disappears)
- [ ] Rating comments submitted for moderation (fire-and-forget to D0 endpoint); do not block submission
- [ ] User profile shows "⭐ 4.8 (12 hires)" badge only after minimum 3 confirmed hires with ratings
- [ ] GET /users/:id/ratings returns correct average, breakdown, and displayable gate
- [ ] GET /job-posters/:id/ratings returns correct aggregates for poster
- [ ] Cron job queries applications needing prompts, sends FCM, stops after 7 days
- [ ] Profile display: if ratings not yet loaded, don't show badge; load via API on profile screen init
- [ ] Error handling: 403 on unauthorized rating attempt (not applicant/poster), 409 on duplicate rating
- [ ] No existing tests broken; new test suite added

---

## Test Suite

### Backend Tests (packages/api/src/__tests__)

**`hire-confirmation.test.ts`** — new file
```typescript
describe('PATCH /jobs/:jobId/applications/:appId (hire action)', () => {
  it('sets hired_at and sends FCM when status = "hired"', async () => {
    const res = await request(app)
      .patch(`/jobs/${jobId}/applications/${appId}`)
      .set('Authorization', `Bearer ${posterToken}`)
      .send({ status: 'hired' });
    expect(res.status).toBe(200);
    expect(res.body.hiredAt).toBeTruthy();
    expect(res.body.hiredConfirmedAt).toBeNull();
    expect(fcmSpy).toHaveBeenCalledWith(applicantFcm, expect.objectContaining({
      data: { screen: 'confirm_hire' }
    }));
  });

  it('returns 403 if user is not job poster', async () => {
    const res = await request(app)
      .patch(`/jobs/${jobId}/applications/${appId}`)
      .set('Authorization', `Bearer ${randomUserToken}`)
      .send({ status: 'hired' });
    expect(res.status).toBe(403);
  });
});

describe('POST /jobs/applications/:appId/confirm-hire', () => {
  it('sets hired_confirmed_at and notifies poster', async () => {
    const res = await request(app)
      .post(`/jobs/applications/${appId}/confirm-hire`)
      .set('Authorization', `Bearer ${applicantToken}`)
      .send({});
    expect(res.status).toBe(200);
    expect(res.body.hiredConfirmedAt).toBeTruthy();
    expect(res.body.ratingPromptAt).toBeTruthy();
    expect(fcmSpy).toHaveBeenCalledWith(posterFcm, expect.objectContaining({
      body: expect.stringMatching(/confirmed/i)
    }));
  });

  it('returns 400 if application is not in "hired" status', async () => {
    const res = await request(app)
      .post(`/jobs/applications/${appliedAppId}/confirm-hire`)
      .set('Authorization', `Bearer ${applicantToken}`)
      .send({});
    expect(res.status).toBe(400);
  });

  it('returns 403 if user is not the applicant', async () => {
    const res = await request(app)
      .post(`/jobs/applications/${appId}/confirm-hire`)
      .set('Authorization', `Bearer ${randomUserToken}`)
      .send({});
    expect(res.status).toBe(403);
  });

  it('returns 409 on double confirm', async () => {
    // First confirm
    await request(app)
      .post(`/jobs/applications/${appId}/confirm-hire`)
      .set('Authorization', `Bearer ${applicantToken}`)
      .send({});
    // Second confirm
    const res = await request(app)
      .post(`/jobs/applications/${appId}/confirm-hire`)
      .set('Authorization', `Bearer ${applicantToken}`)
      .send({});
    expect(res.status).toBe(409);
  });
});

describe('POST /jobs/applications/:appId/decline-hire', () => {
  it('sets status = "declined" and notifies poster', async () => {
    const res = await request(app)
      .post(`/jobs/applications/${appId}/decline-hire`)
      .set('Authorization', `Bearer ${applicantToken}`)
      .send({});
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('declined');
    expect(res.body.hiredConfirmedAt).toBeNull();
    expect(fcmSpy).toHaveBeenCalledWith(posterFcm, expect.stringMatching(/declined/i));
  });

  it('returns 403 if user is not applicant', async () => {
    const res = await request(app)
      .post(`/jobs/applications/${appId}/decline-hire`)
      .set('Authorization', `Bearer ${posterToken}`)
      .send({});
    expect(res.status).toBe(403);
  });
});
```

**`ratings.test.ts`** — new file
```typescript
describe('POST /jobs/applications/:appId/rate-poster', () => {
  it('sets rating and comment for confirmed hire', async () => {
    // Confirm hire first
    await confirmHire(appId, applicantToken);

    const res = await request(app)
      .post(`/jobs/applications/${appId}/rate-poster`)
      .set('Authorization', `Bearer ${applicantToken}`)
      .send({
        rating: 5,
        comment: 'Great experience!'
      });
    expect(res.status).toBe(200);
    expect(res.body.rating).toBe(5);
    expect(res.body.ratingComment).toBe('Great experience!');
    expect(res.body.ratingSubmittedAt).toBeTruthy();
  });

  it('returns 400 if rating not 1–5', async () => {
    await confirmHire(appId, applicantToken);
    const res = await request(app)
      .post(`/jobs/applications/${appId}/rate-poster`)
      .set('Authorization', `Bearer ${applicantToken}`)
      .send({ rating: 6 });
    expect(res.status).toBe(400);
  });

  it('returns 400 if comment exceeds 300 chars', async () => {
    await confirmHire(appId, applicantToken);
    const res = await request(app)
      .post(`/jobs/applications/${appId}/rate-poster`)
      .set('Authorization', `Bearer ${applicantToken}`)
      .send({
        rating: 5,
        comment: 'x'.repeat(301)
      });
    expect(res.status).toBe(400);
  });

  it('returns 409 on second rating (duplicate prevention)', async () => {
    await confirmHire(appId, applicantToken);
    await request(app)
      .post(`/jobs/applications/${appId}/rate-poster`)
      .set('Authorization', `Bearer ${applicantToken}`)
      .send({ rating: 5 });

    const res = await request(app)
      .post(`/jobs/applications/${appId}/rate-poster`)
      .set('Authorization', `Bearer ${applicantToken}`)
      .send({ rating: 4 });
    expect(res.status).toBe(409);
  });

  it('returns 403 if hire not confirmed', async () => {
    const res = await request(app)
      .post(`/jobs/applications/${appliedAppId}/rate-poster`)
      .set('Authorization', `Bearer ${applicantToken}`)
      .send({ rating: 5 });
    expect(res.status).toBe(403);
  });

  it('calls moderation endpoint for comment screening', async () => {
    await confirmHire(appId, applicantToken);
    const modSpy = jest.spyOn(moderationApi, 'screenText');

    await request(app)
      .post(`/jobs/applications/${appId}/rate-poster`)
      .set('Authorization', `Bearer ${applicantToken}`)
      .send({
        rating: 5,
        comment: 'This person used bad language'
      });

    expect(modSpy).toHaveBeenCalledWith(
      expect.stringMatching(/This person used bad language/)
    );
  });
});

describe('PATCH /jobs/:jobId/applications/:appId/rate-applicant', () => {
  it('sets poster_rating when hire confirmed', async () => {
    await confirmHire(appId, applicantToken);

    const res = await request(app)
      .patch(`/jobs/${jobId}/applications/${appId}/rate-applicant`)
      .set('Authorization', `Bearer ${posterToken}`)
      .send({
        rating: 4,
        comment: 'Professional and punctual.'
      });
    expect(res.status).toBe(200);
    expect(res.body.posterRating).toBe(4);
    expect(res.body.posterRatingSubmittedAt).toBeTruthy();
  });

  it('returns 409 on duplicate poster rating', async () => {
    await confirmHire(appId, applicantToken);
    await request(app)
      .patch(`/jobs/${jobId}/applications/${appId}/rate-applicant`)
      .set('Authorization', `Bearer ${posterToken}`)
      .send({ rating: 4 });

    const res = await request(app)
      .patch(`/jobs/${jobId}/applications/${appId}/rate-applicant`)
      .set('Authorization', `Bearer ${posterToken}`)
      .send({ rating: 5 });
    expect(res.status).toBe(409);
  });

  it('returns 403 if user is not job poster', async () => {
    await confirmHire(appId, applicantToken);
    const res = await request(app)
      .patch(`/jobs/${jobId}/applications/${appId}/rate-applicant`)
      .set('Authorization', `Bearer ${randomUserToken}`)
      .send({ rating: 4 });
    expect(res.status).toBe(403);
  });
});

describe('GET /users/:userId/ratings', () => {
  it('returns aggregate ratings for user (applicant ratings)', async () => {
    // Create multiple confirmed hires with ratings
    // ... setup ...

    const res = await request(app).get(`/users/${userId}/ratings`);
    expect(res.status).toBe(200);
    expect(res.body).toEqual(expect.objectContaining({
      userId,
      averageRating: expect.any(Number),
      totalHires: expect.any(Number),
      totalReviews: expect.any(Number),
      ratingBreakdown: expect.objectContaining({
        '5': expect.any(Number),
        '4': expect.any(Number),
        // ...
      }),
      displayable: expect.any(Boolean)
    }));
  });

  it('returns displayable: false if < 3 ratings', async () => {
    // Setup 2 ratings
    // ...

    const res = await request(app).get(`/users/${userId}/ratings`);
    expect(res.status).toBe(200);
    expect(res.body.displayable).toBe(false);
    expect(res.body.averageRating).toBeNull();
  });

  it('returns displayable: true if >= 3 ratings', async () => {
    // Setup 3+ ratings
    // ...

    const res = await request(app).get(`/users/${userId}/ratings`);
    expect(res.body.displayable).toBe(true);
    expect(res.body.averageRating).not.toBeNull();
  });

  it('returns 404 for non-existent user', async () => {
    const res = await request(app).get(
      `/users/00000000-0000-0000-0000-000000000000/ratings`
    );
    expect(res.status).toBe(404);
  });
});

describe('Rating prompt cron job', () => {
  it('finds applications needing prompts (24+ hours after confirmation)', async () => {
    // Create confirmed hire from 25 hours ago
    // ...

    const results = await sendRatingPrompts();
    expect(results.prompted).toBeGreaterThan(0);
    expect(fcmSpy).toHaveBeenCalled();
  });

  it('stops sending prompts after 7 days', async () => {
    // Create confirmed hire from 8 days ago
    // ...

    const results = await sendRatingPrompts();
    expect(results.applicantPrompts).toBe(0);
  });

  it('does not reprompt applications with both ratings', async () => {
    // Create fully rated application
    // ...

    const results = await sendRatingPrompts();
    // Should not be in prompt list
  });
});
```

### Flutter Widget Tests

**`my_applications_screen_test.dart`** — new tests
```dart
testWidgets('Hired application shows "Confirm Hire" banner', (tester) async {
  final app = createTestApp(
    applications: [
      testJobApplication.copyWith(
        status: JobApplicationStatus.hired,
        hiredAt: DateTime.now(),
        hiredConfirmedAt: null,
      ),
    ],
  );
  await tester.pumpWidget(app);
  expect(find.text('Confirm'), findsOneWidget);
});

testWidgets('Confirm dialog appears on tap', (tester) async {
  // ... setup ...
  await tester.tap(find.text('Confirm'));
  await tester.pump();
  expect(find.text('Did you accept this position'), findsOneWidget);
});

testWidgets('Yes confirmation calls confirmHire API', (tester) async {
  final mockJobsApi = MockJobsApi();
  // ... setup ...
  await tester.tap(find.text('Confirm'));
  await tester.pump();
  await tester.tap(find.text('Yes, Confirm'));
  await tester.pumpAndSettle();

  verify(mockJobsApi.confirmHire(appId)).called(1);
});

testWidgets('Rating prompt card shows for confirmed hires without rating', (tester) async {
  final app = createTestApp(
    applications: [
      testJobApplication.copyWith(
        status: JobApplicationStatus.hired,
        hiredConfirmedAt: DateTime.now().subtract(Duration(hours: 25)),
        rating: null,
      ),
    ],
  );
  await tester.pumpWidget(app);
  expect(find.text('How was working with'), findsOneWidget);
});

testWidgets('Rating sheet renders 5-star selector', (tester) async {
  await tester.pumpWidget(testApp);
  await tester.tap(find.text('How was working with'));
  await tester.pumpAndSettle();
  expect(find.byIcon(Icons.star_outline), findsWidgets);
});

testWidgets('Tapping stars updates selection', (tester) async {
  // ... setup rating sheet ...
  final stars = find.byIcon(Icons.star_outline);
  await tester.tap(stars.at(4)); // 5th star
  await tester.pump();
  expect(find.byIcon(Icons.star), findsWidgets);
});

testWidgets('Comment field enforces 300 char limit', (tester) async {
  // ... setup rating sheet ...
  final comment = find.byType(TextField);
  await tester.enterText(comment, 'x' * 301);
  await tester.pump();
  expect(find.text('300'), findsOneWidget); // char count displays max
});

testWidgets('Submit rating calls ratePoster API', (tester) async {
  final mockJobsApi = MockJobsApi();
  // ... setup rating sheet ...
  await tester.tap(stars.at(4)); // Select 5 stars
  await tester.enterText(commentField, 'Great!');
  await tester.tap(find.text('Submit Rating'));
  await tester.pumpAndSettle();

  verify(mockJobsApi.ratePoster(appId, 5, comment: 'Great!')).called(1);
});

testWidgets('User profile shows rating badge when displayable', (tester) async {
  final user = testUser.copyWith(
    ratings: UserRatings(
      userId: userId,
      averageRating: 4.8,
      totalHires: 12,
      totalReviews: 10,
      ratingBreakdown: {'5': 8, '4': 2, ...},
      displayable: true,
    ),
  );
  await tester.pumpWidget(createTestApp(user: user));
  expect(find.text('4.8'), findsOneWidget);
  expect(find.text('(12 hires)'), findsOneWidget);
});

testWidgets('Rating badge hidden when not displayable', (tester) async {
  final user = testUser.copyWith(
    ratings: UserRatings(
      userId: userId,
      averageRating: null,
      totalHires: 1,
      totalReviews: 1,
      displayable: false,
    ),
  );
  await tester.pumpWidget(createTestApp(user: user));
  expect(find.text('4.8'), findsNothing);
});
```

---

## Definition of Done

- [ ] All backend endpoints implemented and tested
- [ ] Rating scheduler (cron job) implemented and manually testable
- [ ] Social app UI: confirm hire dialog, rating sheet, profile badge
- [ ] API tests pass: `cd packages/api && npx jest ratings.test.ts hire-confirmation.test.ts`
- [ ] Flutter widget tests pass: `cd packages/social-app && flutter test`
- [ ] `dart run build_runner build` runs clean after model changes
- [ ] Manual test: job poster marks hired → applicant gets FCM → confirms → rating prompt appears after 24h
- [ ] Manual test: rating submission succeeds; 5-star and comment work; comment goes to moderation
- [ ] Manual test: user profile shows rating badge only after 3+ confirmed hires
- [ ] No existing tests broken
- [ ] Completion Report filled in (below)
- [ ] Interrogative Session with Jeff completed

---

## Completion Report

> To be filled in by the executing agent after implementation is complete.

**Branch:** `feature/E2-hire-confirmation-ratings`
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

### What the next prompt in this track (E3) should know
-

---

## Interrogative Session

**Q1 (Agent):** Did the hire confirmation and rating flow feel frictionless end-to-end? Any UX hiccups in the confirm dialog, rating sheet, or cron timing?
> Jeff:

**Q2 (Agent):** Does the moderation integration (fire-and-forget comment screening) work reliably without blocking the rating submission, and are flagged comments visible in the admin moderation dashboard?
> Jeff:

**Q3 (Agent):** Are there any edge cases around the 24-hour rating prompt window or 7-day cutoff that feel problematic — e.g., what happens if someone confirms a hire at 11:55 PM and the cron runs at midnight?
> Jeff:

**Q4 (Agent):** Does the profile rating badge feel like a meaningful trust signal, or should we add more context (like "recently rated" or "verified by X hires")?
> Jeff:

**Q5 (Agent):** Any concerns about privacy or data exposure — e.g., should individual comments be visible on profiles, or only aggregated averages?
> Jeff:

**Q6 (Jeff):** Did the testing reveal any issues with FCM delivery, especially around timing or token stale-ness?
> —

**Q7 (Jeff):** How should we handle job posters or applicants who never rate — should we show "incomplete" status or just not prompt after 7 days?
> —

**Q8 (Jeff):** Should the average rating on a profile weight recent hires more heavily (recency decay), or is a simple average fine for now?
> —

**Ready for review:** ☐ Yes
