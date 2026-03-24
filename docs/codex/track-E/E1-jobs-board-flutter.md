# [Track-E1] Jobs Board Flutter UI

**Track:** E (Jobs Board)
**Sequence:** 1 of 1 in Track E (follows backend E0 completion)
**Model:** claude-sonnet-4-6
**Alternate Model:** gpt-5.3-codex — solid choice for UI/state integration work with mixed Dart + TypeScript understanding. Either model works well.
**A/B Test:** No
**Estimated Effort:** Large (12-16 hours)
**Dependencies:** E0 (backend), A1 (community board pattern — similar screen architecture)

## Execution Mode (Required)

- [ ] Stage 1 (required): execute and validate locally first (local Postgres + local API + local admin/mobile against local endpoint).
- [ ] Stage 2 (required for backend/integration-impacting tracks): run shared-dev integration smoke only after local pass.
- [ ] Stage 3 (required before PR merge): run AWS dev deploy/integration smoke for final confidence.
- [ ] Completion log must explicitly record: execution mode used, exact commands run, evidence links, and cleanup actions.


---

## Context

Read these before writing any code:

- `CLAUDE.md` — full project reference (key gotchas section especially: #5 theme classes, #6 build_runner, #13 GoRouter refreshListenable + push/pop)
- `docs/product/requirements.md` — Jobs Board feature requirements and user stories
- `docs/codex/track-E/E0-jobs-board-backend.md` — backend API spec, database schema, endpoints
- `packages/shared/lib/models/post.dart` — similar model structure (use as pattern)
- `packages/social-app/lib/features/community/` — community board screens (similar navigation and list patterns)
- `packages/social-app/lib/providers/app_state.dart` — AppState structure for integrating new APIs
- `packages/social-app/lib/config/routes.dart` — GoRouter routing (add /jobs and /my-applications)
- `packages/social-app/lib/features/profile/screens/settings_screen.dart` — reference for settings screen structure

---

## Goal

Build the Jobs Board feature in the Flutter social app, enabling creative workers to browse, filter, and apply to job listings. The feature is gated behind a `feature.jobs_board` platform config flag. When enabled, a Jobs tab appears in the bottom navigation. Users can browse jobs filtered by type, specialty, and location; view detailed job postings; apply with optional cover notes and portfolio links; and track their application status.

After this prompt, users can fully discover and apply to jobs, and the admin app can manage job postings (if admin E2 proceeds).

---

## Acceptance Criteria

**Platform Config & Feature Flag**
- [ ] `AppState` calls `GET /platform-config` (or lightweight flag endpoint) on app init
- [ ] `AppState.jobsBoardEnabled` (bool) reflects `feature.jobs_board` from the response
- [ ] Jobs tab does NOT appear in bottom nav when `jobsBoardEnabled == false`
- [ ] Jobs tab appears as 5th nav item (briefcase icon) when `jobsBoardEnabled == true`
- [ ] Dev fallback: if API is unavailable on init, `jobsBoardEnabled` defaults to `true` (fail-open for local dev)

**Jobs List Screen**
- [ ] Route: `/jobs`
- [ ] On init: calls `JobsApi.getJobs()`, stores results in local state
- [ ] Filter bar (sticky, horizontally scrollable):
  - Job type chips: All / Full-time / Part-time / Freelance / Gig / Internship
  - Specialty multi-select: opens picker with specialty list from AppState
  - Location type chips: All / On-site / Remote / Hybrid
  - Urgent toggle: filters to only urgent jobs
- [ ] Each filter chip updates the API query and refreshes the list (debounced, 300ms)
- [ ] Job cards show:
  - Poster business logo (or initials fallback) + business name (line 1)
  - Job title (headline, bold, 2 lines max with ellipsis)
  - Type badge (Full-time: blue, Part-time: grey, Freelance: purple, Gig: green, Internship: cyan)
  - Compensation range or "Negotiable"
  - Location: city + location type icon (📍 on-site, 🌐 remote, 🔀 hybrid)
  - Required specialties: 3 chips max + "+N more" overflow
  - "Urgent" red ribbon on card if is_urgent == true
  - Time posted: "3h ago", "2 days ago" (relative format)
  - "Applied ✓" green chip if current user has already applied
- [ ] Pull-to-refresh (top) refreshes job list
- [ ] Infinite scroll: when user scrolls near bottom, auto-fetch next page
- [ ] Empty state: "No jobs right now — check back soon"
- [ ] Error state: shows error message with "Retry" button
- [ ] Tapping card navigates to `/jobs/{jobId}`

**Job Detail Screen**
- [ ] Route: `/jobs/:jobId`
- [ ] On init: calls `JobsApi.getJob(jobId)`
- [ ] Header: poster logo + business name
- [ ] Job title (prominent, headline size)
- [ ] Tags row: type badge, location type icon + city, compensation, urgency indicator
- [ ] "Required Specialties" section: horizontal chips for each specialty
- [ ] Full description (plain text or markdown if possible)
- [ ] "Compensation" section: range (min–max) + optional note/currency
- [ ] "Location Details" section: city, state (if available), address snippet
- [ ] "About {Business Name}" section: brief poster profile, website link if available
- [ ] Apply button (sticky/fixed at bottom):
  - If already applied: "✓ Applied" (disabled, green background)
  - If job status is filled/expired: "Position Filled" (disabled, grey)
  - If not applied and job active: "Apply" (purple/primary color, enabled)
- [ ] Tapping Apply → opens `ApplySheet`
- [ ] Swipe or back button to dismiss screen
- [ ] Error loading: shows error message with retry button

**Apply Sheet (Bottom Sheet)**
- [ ] Triggered from Job Detail "Apply" button
- [ ] Header: "Apply for {Job Title}"
- [ ] Form fields:
  - **Cover Note** (optional, TextFormField, max 500 chars):
    - Placeholder: "Tell them why you're a great fit..."
    - Character counter below field
    - Validation: none required (optional)
  - **Portfolio URL** (optional, TextFormField):
    - Placeholder: "https://yourportfolio.com"
    - Validation: valid URL or empty (rejects invalid URLs)
- [ ] "Apply Now" button (purple, enabled if form valid)
- [ ] "Cancel" button closes sheet
- [ ] Submitting:
  - Shows loading state (button disabled, spinner)
  - Calls `JobsApi.applyToJob(jobId, coverNote: ..., portfolioUrl: ...)`
- [ ] On success:
  - Sheet closes
  - Parent Job Detail screen: Apply button changes to "✓ Applied" (disabled, green)
  - Shows success snackbar: "Application submitted!"
- [ ] On error:
  - Shows error snackbar: "Could not submit application. Try again."
  - Sheet remains open (user can retry)

**My Applications Screen**
- [ ] Route: `/my-applications` (can be accessed from Jobs tab header button or Profile menu)
- [ ] On init: calls `JobsApi.getMyApplications()`
- [ ] List of applications:
  - Each row: job title, business name, status badge, date applied
  - Status badges with colors:
    - Submitted (grey)
    - Viewed (blue)
    - Shortlisted (yellow)
    - Declined (red)
    - Hired (green)
    - Withdrawn (light grey)
  - Tapping row → navigates to job detail for that job
- [ ] Pull-to-refresh
- [ ] Empty state: "No applications yet — find your next gig in the Jobs tab"
- [ ] Error state with retry
- [ ] If user has not applied to any jobs and visits this screen, empty state is shown (not an error)

**State & Routing**
- [ ] Add `/jobs` and `/jobs/:jobId` and `/my-applications` routes to `GoRouter` config
- [ ] Auth redirects: `/jobs` requires authenticated user (redirects to login if not)
- [ ] Add `JobsApi` instance to `AppState` (lazy initialized like other APIs)
- [ ] `AppState` exposes `jobsBoardEnabled` (bool) for UI gating
- [ ] No new global providers — all state is managed via local screen state or AppState

---

## User Stories

| Actor | Story | Notes |
|-------|-------|-------|
| Creative worker | As a freelance makeup artist, I browse the Jobs tab and find a fashion shoot gig that matches my makeup specialty | Job type = Freelance, specialty filter works |
| Creative worker | As a photographer who just applied to a gig, I see "✓ Applied" on the listing so I don't accidentally double-apply | Applied state persists after screen refresh |
| Creative worker | As a full-time hair stylist, I use the Full-time filter to see only permanent positions | Type filter calls API correctly |
| Creative worker | As a user, I can add a cover note explaining why I'm a great fit when I apply | Cover note is optional, max 500 chars |
| Creative worker | As a user, I can link my portfolio when applying so the poster can see my work | Portfolio URL field, validation, optional |
| Shortlisted candidate | As a user who was shortlisted for a job, I open My Applications and see a "Shortlisted" badge | Status badges render correctly |
| Platform ops (future) | After backend E0 is complete, the API endpoints for jobs, applications, and platform config are available | Backend dependency satisfied |

---

## Technical Spec

### 1. Platform Config & Feature Flag

**AppState initialization** (`packages/social-app/lib/providers/app_state.dart`):

Add to `AppState`:

```dart
class AppState extends ChangeNotifier {
  bool _jobsBoardEnabled = true; // dev default (fail-open)
  bool get jobsBoardEnabled => _jobsBoardEnabled;

  late final JobsApi jobsApi; // Add jobs API

  Future<void> initialize() async {
    // ... existing init code ...

    // Fetch platform config on app startup
    try {
      final config = await apiClient.get('/platform-config') as Map<String, dynamic>;
      _jobsBoardEnabled = config['features']?['jobs_board'] ?? true;
    } catch (e) {
      // Dev fallback: show jobs if API unavailable
      _jobsBoardEnabled = true;
      print('Platform config unavailable, defaulting jobs to enabled for dev');
    }
    notifyListeners();
  }
}
```

Lazy-initialize `JobsApi`:

```dart
late final JobsApi jobsApi = JobsApi(apiClient);
```

### 2. Jobs List Screen (`packages/social-app/lib/features/jobs/screens/jobs_list_screen.dart`)

```dart
class JobsListScreen extends StatefulWidget {
  const JobsListScreen({Key? key}) : super(key: key);

  @override
  State<JobsListScreen> createState() => _JobsListScreenState();
}

class _JobsListScreenState extends State<JobsListScreen> {
  late Future<List<Job>> _jobsFuture;

  // Filters
  String _typeFilter = ''; // empty = all
  List<String> _specialtyFilter = [];
  String _locationTypeFilter = ''; // empty = all
  bool _urgentOnly = false;

  // Pagination
  int _page = 0;
  final int _pageSize = 20;
  List<Job> _allJobs = [];
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    final appState = context.read<AppState>();
    try {
      _allJobs = await appState.jobsApi.getJobs(
        type: _typeFilter.isEmpty ? null : _typeFilter,
        specialtyIds: _specialtyFilter.isEmpty ? null : _specialtyFilter,
        locationType: _locationTypeFilter.isEmpty ? null : _locationTypeFilter,
        urgent: _urgentOnly ? true : null,
        page: _page,
        pageSize: _pageSize,
      );
      _hasMore = _allJobs.length >= _pageSize;
      setState(() {
        _jobsFuture = Future.value(_allJobs);
      });
    } catch (e) {
      setState(() {
        _jobsFuture = Future.error(e);
      });
    }
  }

  void _onFilterChanged() {
    _page = 0; // Reset pagination on filter change
    _loadJobs();
  }

  void _onLoadMore() {
    if (_hasMore && mounted) {
      _page++;
      _loadJobs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jobs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _onFilterChanged,
          ),
        ],
      ),
      body: FutureBuilder<List<Job>>(
        future: _jobsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _allJobs.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error loading jobs: ${snapshot.error}'),
                  ElevatedButton(
                    onPressed: _onFilterChanged,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (_allJobs.isEmpty) {
            return const Center(
              child: Text('No jobs right now — check back soon'),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              _page = 0;
              await _loadJobs();
            },
            child: CustomScrollView(
              slivers: [
                // Filter bar
                SliverToBoxAdapter(
                  child: _buildFilterBar(context),
                ),
                // Job list
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index == _allJobs.length) {
                        if (_hasMore) {
                          _onLoadMore();
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          );
                        }
                        return const SizedBox.shrink();
                      }
                      final job = _allJobs[index];
                      return _buildJobCard(context, job);
                    },
                    childCount: _allJobs.length + (_hasMore ? 1 : 0),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Type filter
          ChoiceChip(
            label: const Text('All'),
            selected: _typeFilter.isEmpty,
            onSelected: (_) {
              setState(() => _typeFilter = '');
              _onFilterChanged();
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Full-time'),
            selected: _typeFilter == 'full_time',
            onSelected: (_) {
              setState(() => _typeFilter = 'full_time');
              _onFilterChanged();
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Part-time'),
            selected: _typeFilter == 'part_time',
            onSelected: (_) {
              setState(() => _typeFilter = 'part_time');
              _onFilterChanged();
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Freelance'),
            selected: _typeFilter == 'freelance',
            onSelected: (_) {
              setState(() => _typeFilter = 'freelance');
              _onFilterChanged();
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Gig'),
            selected: _typeFilter == 'gig',
            onSelected: (_) {
              setState(() => _typeFilter = 'gig');
              _onFilterChanged();
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Specialty'),
            onSelected: (_) => _showSpecialtyPicker(context),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Urgent'),
            selected: _urgentOnly,
            onSelected: (selected) {
              setState(() => _urgentOnly = selected);
              _onFilterChanged();
            },
          ),
        ],
      ),
    );
  }

  void _showSpecialtyPicker(BuildContext context) {
    final appState = context.read<AppState>();
    showModalBottomSheet(
      context: context,
      builder: (context) => MultiSelectSpecialtyPicker(
        selected: _specialtyFilter,
        onSelected: (specialties) {
          setState(() => _specialtyFilter = specialties);
          _onFilterChanged();
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildJobCard(BuildContext context, Job job) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: GestureDetector(
          onTap: () => context.push('/jobs/${job.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: logo + business name
              Row(
                children: [
                  CircleAvatar(
                    backgroundImage: job.posterLogoUrl != null
                        ? NetworkImage(job.posterLogoUrl!)
                        : null,
                    child: job.posterLogoUrl == null
                        ? Text(job.posterBusinessName[0].toUpperCase())
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      job.posterBusinessName,
                      style: Theme.of(context).textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (job.isUrgent)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'URGENT',
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // Job title
              Text(
                job.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // Type badge
              Chip(
                label: Text(job.jobType),
                backgroundColor: _jobTypeColor(job.jobType),
                labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              const SizedBox(height: 8),
              // Compensation + location
              Row(
                children: [
                  Expanded(
                    child: Text(
                      job.compensationNote ?? '${job.compensationMin}–${job.compensationMax}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    '${_locationTypeIcon(job.locationType)} ${job.locationCity ?? "Remote"}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Specialties
              Wrap(
                spacing: 4,
                children: job.requiredSpecialties
                    .take(3)
                    .map((s) => Chip(label: Text(s), onDeleted: null))
                    .toList(),
              ),
              if (job.requiredSpecialties.length > 3)
                Text('+${job.requiredSpecialties.length - 3} more'),
              const SizedBox(height: 8),
              // Footer: time posted + applied status
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatTimeAgo(job.postedAt),
                      style: Theme.of(context).textTheme.caption,
                    ),
                  ),
                  if (job.hasApplied ?? false)
                    Chip(
                      label: const Text('✓ Applied'),
                      backgroundColor: Colors.green[100],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _jobTypeColor(String type) {
    switch (type) {
      case 'full_time':
        return Colors.blue;
      case 'part_time':
        return Colors.grey;
      case 'freelance':
        return Colors.purple;
      case 'gig':
        return Colors.green;
      case 'internship':
        return Colors.cyan;
      default:
        return Colors.grey;
    }
  }

  String _locationTypeIcon(String type) {
    switch (type) {
      case 'on_site':
        return '📍';
      case 'remote':
        return '🌐';
      case 'hybrid':
        return '🔀';
      default:
        return '📍';
    }
  }

  String _formatTimeAgo(DateTime? date) {
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
```

### 3. Job Detail Screen (`packages/social-app/lib/features/jobs/screens/job_detail_screen.dart`)

```dart
class JobDetailScreen extends StatefulWidget {
  final String jobId;
  const JobDetailScreen(this.jobId, {Key? key}) : super(key: key);

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  late Future<Job> _jobFuture;
  bool _hasApplied = false;

  @override
  void initState() {
    super.initState();
    _loadJob();
  }

  Future<void> _loadJob() async {
    final appState = context.read<AppState>();
    try {
      final job = await appState.jobsApi.getJob(widget.jobId);
      setState(() {
        _jobFuture = Future.value(job);
        _hasApplied = job.hasApplied ?? false;
      });
    } catch (e) {
      setState(() {
        _jobFuture = Future.error(e);
      });
    }
  }

  void _showApplySheet(Job job) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ApplySheet(
        jobId: job.id,
        jobTitle: job.title,
        onApplySuccess: () {
          setState(() => _hasApplied = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Application submitted!')),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Job Details')),
      body: FutureBuilder<Job>(
        future: _jobFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error loading job: ${snapshot.error}'),
                  ElevatedButton(
                    onPressed: _loadJob,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final job = snapshot.data!;

          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundImage: job.posterLogoUrl != null
                                ? NetworkImage(job.posterLogoUrl!)
                                : null,
                            child: job.posterLogoUrl == null
                                ? Text(job.posterBusinessName[0].toUpperCase())
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(job.posterBusinessName),
                                Text(job.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Tags
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          Chip(label: Text(job.jobType)),
                          Chip(
                              label: Text(
                                  '${_locationTypeIcon(job.locationType)} ${job.locationCity ?? "Remote"}')),
                          Chip(
                              label: Text(job.compensationNote ??
                                  '${job.compensationMin}–${job.compensationMax}')),
                          if (job.isUrgent)
                            const Chip(
                              label: Text('URGENT'),
                              backgroundColor: Colors.red,
                              labelStyle: TextStyle(color: Colors.white),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Description
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(job.description),
                    ),
                    const SizedBox(height: 16),
                    // Required specialties
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Required Specialties',
                              style:
                                  Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: job.requiredSpecialties
                                .map((s) => Chip(label: Text(s)))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // About business
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('About ${job.posterBusinessName}',
                              style:
                                  Theme.of(context).textTheme.titleMedium),
                          // Placeholder for business profile
                          const Text('Business profile coming soon'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Apply button (fixed at bottom)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: _hasApplied ? null : () => _showApplySheet(job),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _hasApplied ? Colors.green : null,
                    ),
                    child: Text(_hasApplied ? '✓ Applied' : 'Apply'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _locationTypeIcon(String type) {
    switch (type) {
      case 'on_site':
        return '📍';
      case 'remote':
        return '🌐';
      case 'hybrid':
        return '🔀';
      default:
        return '📍';
    }
  }
}
```

### 4. Apply Sheet (`packages/social-app/lib/features/jobs/screens/apply_sheet.dart`)

```dart
class ApplySheet extends StatefulWidget {
  final String jobId;
  final String jobTitle;
  final VoidCallback onApplySuccess;

  const ApplySheet({
    required this.jobId,
    required this.jobTitle,
    required this.onApplySuccess,
    Key? key,
  }) : super(key: key);

  @override
  State<ApplySheet> createState() => _ApplySheetState();
}

class _ApplySheetState extends State<ApplySheet> {
  final _coverNoteController = TextEditingController();
  final _portfolioUrlController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _coverNoteController.dispose();
    _portfolioUrlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final appState = context.read<AppState>();
      await appState.jobsApi.applyToJob(
        widget.jobId,
        coverNote: _coverNoteController.text.isNotEmpty
            ? _coverNoteController.text
            : null,
        portfolioUrl: _portfolioUrlController.text.isNotEmpty
            ? _portfolioUrlController.text
            : null,
      );
      widget.onApplySuccess();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
      setState(() => _isSubmitting = false);
    }
  }

  bool _isValidUrl(String url) {
    if (url.isEmpty) return true;
    try {
      Uri.parse(url);
      return url.startsWith('http://') || url.startsWith('https://');
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFormValid = _isValidUrl(_portfolioUrlController.text);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 16,
        left: 16,
        right: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Apply for ${widget.jobTitle}',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _coverNoteController,
              decoration: InputDecoration(
                labelText: 'Cover Note',
                hintText: 'Tell them why you\'re a great fit...',
                border: OutlineInputBorder(),
                maxLength: 500,
                counterText: '${_coverNoteController.text.length}/500',
              ),
              maxLines: 4,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _portfolioUrlController,
              decoration: InputDecoration(
                labelText: 'Portfolio URL (optional)',
                hintText: 'https://yourportfolio.com',
                border: OutlineInputBorder(),
                errorText: _portfolioUrlController.text.isNotEmpty &&
                        !_isValidUrl(_portfolioUrlController.text)
                    ? 'Enter a valid URL'
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting || !isFormValid ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Apply Now'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
```

### 5. My Applications Screen (`packages/social-app/lib/features/jobs/screens/my_applications_screen.dart`)

```dart
class MyApplicationsScreen extends StatefulWidget {
  const MyApplicationsScreen({Key? key}) : super(key: key);

  @override
  State<MyApplicationsScreen> createState() => _MyApplicationsScreenState();
}

class _MyApplicationsScreenState extends State<MyApplicationsScreen> {
  late Future<List<JobApplication>> _applicationsFuture;

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    final appState = context.read<AppState>();
    setState(() {
      _applicationsFuture = appState.jobsApi.getMyApplications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Applications')),
      body: FutureBuilder<List<JobApplication>>(
        future: _applicationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error loading applications: ${snapshot.error}'),
                  ElevatedButton(
                    onPressed: _loadApplications,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final applications = snapshot.data ?? [];

          if (applications.isEmpty) {
            return const Center(
              child: Text('No applications yet — find your next gig in the Jobs tab'),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadApplications,
            child: ListView.builder(
              itemCount: applications.length,
              itemBuilder: (context, index) {
                final app = applications[index];
                return ListTile(
                  title: Text(app.jobTitle),
                  subtitle: Text(app.businessName),
                  trailing: Chip(
                    label: Text(app.status),
                    backgroundColor: _statusColor(app.status),
                  ),
                  onTap: () => context.push('/jobs/${app.jobId}'),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'submitted':
        return Colors.grey[300]!;
      case 'viewed':
        return Colors.blue[300]!;
      case 'shortlisted':
        return Colors.yellow[300]!;
      case 'declined':
        return Colors.red[300]!;
      case 'hired':
        return Colors.green[300]!;
      case 'withdrawn':
        return Colors.grey[100]!;
      default:
        return Colors.grey[300]!;
    }
  }
}
```

### 6. JobsApi (`packages/shared/lib/api/jobs_api.dart`) — create new file

```dart
class JobsApi {
  final ApiClient _client;

  JobsApi(this._client);

  Future<List<Job>> getJobs({
    String? type,
    List<String>? specialtyIds,
    String? locationType,
    bool? urgent,
    int? page,
    int? pageSize,
  }) async {
    final query = <String, dynamic>{
      if (type != null) 'type': type,
      if (specialtyIds != null && specialtyIds.isNotEmpty)
        'specialtyIds': specialtyIds.join(','),
      if (locationType != null) 'locationType': locationType,
      if (urgent != null) 'urgent': urgent,
      if (page != null) 'page': page,
      if (pageSize != null) 'pageSize': pageSize,
    };

    final response = await _client.get(
      '/jobs',
      queryParameters: query,
    );

    return (response as List)
        .map((j) => Job.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<Job> getJob(String jobId) async {
    final response = await _client.get('/jobs/$jobId');
    return Job.fromJson(response as Map<String, dynamic>);
  }

  Future<JobApplication> applyToJob(
    String jobId, {
    String? coverNote,
    String? portfolioUrl,
  }) async {
    final response = await _client.post(
      '/jobs/$jobId/apply',
      data: {
        if (coverNote != null) 'coverNote': coverNote,
        if (portfolioUrl != null) 'portfolioUrl': portfolioUrl,
      },
    );
    return JobApplication.fromJson(response as Map<String, dynamic>);
  }

  Future<List<JobApplication>> getMyApplications() async {
    final response = await _client.get('/jobs/my-applications');
    return (response as List)
        .map((a) => JobApplication.fromJson(a as Map<String, dynamic>))
        .toList();
  }
}
```

### 7. Models (`packages/shared/lib/models/`)

**`job.dart`** (new file):

```dart
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'job.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class Job extends Equatable {
  final String id;
  final String posterBusinessName;
  final String? posterLogoUrl;
  final String title;
  final String description;
  final String jobType; // 'full_time', 'part_time', 'freelance', 'gig', 'internship'
  final String compensationType;
  final double? compensationMin;
  final double? compensationMax;
  final String? compensationNote;
  final List<String> requiredSpecialties;
  final String locationType; // 'on_site', 'remote', 'hybrid'
  final String? locationCity;
  final String? locationState;
  final bool isUrgent;
  final DateTime? expiresAt;
  final String status; // 'active', 'filled', 'expired'
  final DateTime? postedAt;
  final int applicantCount;
  final bool? hasApplied;

  const Job({
    required this.id,
    required this.posterBusinessName,
    this.posterLogoUrl,
    required this.title,
    required this.description,
    required this.jobType,
    required this.compensationType,
    this.compensationMin,
    this.compensationMax,
    this.compensationNote,
    required this.requiredSpecialties,
    required this.locationType,
    this.locationCity,
    this.locationState,
    required this.isUrgent,
    this.expiresAt,
    required this.status,
    this.postedAt,
    required this.applicantCount,
    this.hasApplied,
  });

  @override
  List<Object?> get props => [
    id,
    title,
    posterBusinessName,
    jobType,
    isUrgent,
    hasApplied,
  ];

  factory Job.fromJson(Map<String, dynamic> json) => _$JobFromJson(json);
  Map<String, dynamic> toJson() => _$JobToJson(this);
}
```

**`job_application.dart`** (new file):

```dart
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'job_application.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class JobApplication extends Equatable {
  final String id;
  final String jobId;
  final String jobTitle;
  final String businessName;
  final String? coverNote;
  final String? portfolioUrl;
  final String status; // 'submitted', 'viewed', 'shortlisted', 'declined', 'hired', 'withdrawn'
  final DateTime appliedAt;
  final DateTime? viewedAt;
  final DateTime? respondedAt;

  const JobApplication({
    required this.id,
    required this.jobId,
    required this.jobTitle,
    required this.businessName,
    this.coverNote,
    this.portfolioUrl,
    required this.status,
    required this.appliedAt,
    this.viewedAt,
    this.respondedAt,
  });

  @override
  List<Object?> get props => [id, jobId, status, appliedAt];

  factory JobApplication.fromJson(Map<String, dynamic> json) =>
      _$JobApplicationFromJson(json);
  Map<String, dynamic> toJson() => _$JobApplicationToJson(this);
}
```

After creating models, regenerate:
```bash
cd packages/shared && dart run build_runner build --delete-conflicting-outputs
```

### 8. Routing Update (`packages/social-app/lib/config/routes.dart`)

Add routes to GoRouter:

```dart
GoRoute(
  path: 'jobs',
  builder: (context, state) => const JobsListScreen(),
  routes: [
    GoRoute(
      path: ':jobId',
      builder: (context, state) {
        final jobId = state.pathParameters['jobId']!;
        return JobDetailScreen(jobId);
      },
    ),
  ],
),
GoRoute(
  path: 'my-applications',
  builder: (context, state) => const MyApplicationsScreen(),
),
```

Add to auth redirect logic to require auth for `/jobs` routes.

### 9. Bottom Navigation Update (`packages/social-app/lib/main.dart`)

Update `BottomNavigationBar` to conditionally show Jobs tab:

```dart
BottomNavigationBar(
  items: [
    // ... existing items ...
    if (appState.jobsBoardEnabled)
      BottomNavigationBarItem(
        icon: const Icon(Icons.work_outline),
        activeIcon: const Icon(Icons.work),
        label: 'Jobs',
      ),
  ],
  onTap: (index) {
    // Handle navigation...
    if (appState.jobsBoardEnabled && index == 4) {
      context.go('/jobs');
    }
  },
)
```

---

## Test Suite

### Widget Tests

**`jobs_list_test.dart`:**
```dart
testWidgets('JobsListScreen loads and renders jobs', (tester) async {
  await tester.pumpWidget(buildTestApp());
  expect(find.byType(CircularProgressIndicator), findsWidgets);
  await tester.pumpAndSettle();
  expect(find.byType(Card), findsWidgets); // Job cards
});

testWidgets('Type filter updates query', (tester) async {
  await tester.pumpWidget(buildTestApp());
  await tester.pumpAndSettle();
  await tester.tap(find.text('Full-time'));
  await tester.pumpAndSettle();
  // Verify API was called with type filter
});

testWidgets('Applied jobs show checkmark chip', (tester) async {
  // Mock job with hasApplied: true
  await tester.pumpWidget(buildTestApp());
  await tester.pumpAndSettle();
  expect(find.text('✓ Applied'), findsWidgets);
});

testWidgets('Empty state shown when no jobs', (tester) async {
  // Mock empty response
  await tester.pumpWidget(buildTestApp());
  await tester.pumpAndSettle();
  expect(find.text('No jobs right now'), findsOneWidget);
});
```

**`job_detail_test.dart`:**
```dart
testWidgets('Apply button is disabled when already applied', (tester) async {
  final job = Job(..., hasApplied: true);
  await tester.pumpWidget(buildTestApp(job: job));
  await tester.pumpAndSettle();
  final button = find.byType(ElevatedButton);
  expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
  expect(find.text('✓ Applied'), findsOneWidget);
});

testWidgets('Apply button is enabled when not applied', (tester) async {
  final job = Job(..., hasApplied: false);
  await tester.pumpWidget(buildTestApp(job: job));
  await tester.pumpAndSettle();
  expect(find.text('Apply'), findsOneWidget);
});
```

**`apply_sheet_test.dart`:**
```dart
testWidgets('Cover note is optional', (tester) async {
  await tester.pumpWidget(buildTestApp());
  await tester.tap(find.text('Apply'));
  await tester.pumpAndSettle();
  expect(find.byType(ApplySheet), findsOneWidget);
  // Submit without entering cover note
  await tester.tap(find.text('Apply Now'));
  await tester.pumpAndSettle();
  // Should succeed
});

testWidgets('Portfolio URL validation rejects invalid URL', (tester) async {
  await tester.pumpWidget(buildTestApp());
  await tester.tap(find.text('Apply'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byType(TextFormField).at(1),
    'not-a-url',
  );
  await tester.pumpAndSettle();
  expect(find.text('Enter a valid URL'), findsOneWidget);
  expect(find.byType(ElevatedButton).first, isDisabled);
});
```

---

## Definition of Done

- [ ] All screens implemented (jobs list, job detail, apply sheet, my applications)
- [ ] Feature flag gating: Jobs tab hidden when `jobsBoardEnabled == false`
- [ ] All models created and code-generated (`.g.dart` files)
- [ ] JobsApi fully implemented with all required endpoints
- [ ] Routes added to GoRouter with auth redirects
- [ ] Bottom nav updated to show/hide Jobs tab based on feature flag
- [ ] Pull-to-refresh works on all list screens
- [ ] Filter chips work and update API query correctly
- [ ] Apply flow: sheet opens, validates, submits, shows success/error
- [ ] My Applications screen shows correct status badges
- [ ] Widget tests pass: `cd packages/social-app && flutter test`
- [ ] No compiler errors: `cd packages/social-app && flutter build apk` (or iOS)
- [ ] Manual test: feature flag toggle shows/hides Jobs tab after app restart
- [ ] Completion Report filled in (below)
- [ ] Interrogative Session completed with Jeff

---

## Completion Report

> To be filled in by the executing agent after implementation is complete.

**Branch:** `feature/E1-jobs-board-flutter-[claude|gpt]`
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

### What the next prompt in this track (E2 or follow-up) should know
-

---

## Interrogative Session

**Q1: Does the feature flag gating work correctly — specifically when API is unavailable on init, do jobs still show for local dev testing?**
> Jeff:

**Q2: The apply flow has optional fields (cover note, portfolio URL) — does the form validation feel right, especially for URL validation? Should portfolio be URL-only or allow text?**
> Jeff:

**Q3: My Applications status badges use colors — are these accessible and clear enough for users who can't distinguish colors, or should we add icons/text suffixes?**
> Jeff:

**Q4: The infinite scroll pagination in the jobs list — does it feel natural, or should we add a "Load More" button instead?**
> Jeff:

**Q5: Any concerns or polish issues before merging?**
> Jeff:

**Ready for review:** ☐ Yes
