# [Track-A1] Community Board — Wire Feed, Posts, Comments, Likes

**Track:** A (Social App Completion)
**Sequence:** 2 of 4 in Track A
**Model:** claude-sonnet-4-6
**Alternate Model:** gpt-5.3-codex ← excellent fit; heavy Dart UI work + API client signatures play to both models' strengths. Either works well.
**A/B Test:** No — single model execution; serial handoff from A0
**Estimated Effort:** Medium (6-8 hours)
**Dependencies:** A0 (critical fixes must land first), C0 (backend — verify POST /posts/:id/report exists)

## Execution Mode (Required)

- [ ] Stage 1 (required): execute and validate locally first (local Postgres + local API + local admin/mobile against local endpoint).
- [ ] Stage 2 (required for backend/integration-impacting tracks): run shared-dev integration smoke only after local pass.
- [ ] Stage 3 (required before PR merge): run AWS dev deploy/integration smoke for final confidence.
- [ ] Completion log must explicitly record: execution mode used, exact commands run, evidence links, and cleanup actions.


---

## Context

Read these before writing any code:

- `CLAUDE.md` — full project reference (especially Social App section + PostsApi)
- `docs/analysis/implementation_audit.md` — community feed current state audit
- `packages/social-app/lib/features/community/` — screen stubs + implementations
- `packages/shared/lib/api/posts_api.dart` — API client signatures (verify all methods exist)
- `packages/shared/lib/models/post.dart` — Post model with author fields (added in A0)
- `packages/api/src/routes/posts.ts` — backend endpoint behavior and pagination strategy
- `packages/api/src/routes/admin.ts` — verify POST /posts/:id/report endpoint (C1 scope)

---

## Goal

Wire the community feed screens to the real PostsApi. Currently `community_feed_screen`, `create_post_screen`, and `post_detail_screen` are stubbed or partially implemented. After this prompt: users can browse the live feed, create posts, react with likes, and comment — the core retention loop for creative workers between events.

---

## Acceptance Criteria

### Feed Loading & Rendering
- [ ] On first open: `community_feed_screen` calls `postsApi.getPosts()` (default page/offset 0), stores result in local state
- [ ] Posts render as cards with: author avatar + name + specialty tag, post type badge (different colors: general=grey, collaboration=purple, job=green, announcement=orange), post text, image if present, like count + comment count, relative time ("2h ago"), and tap zone to open detail screen
- [ ] Post type color coding: `general` → grey, `collaboration` → #7C3AED (purple), `job` → #10B981 (green), `announcement` → #F59E0B (orange)
- [ ] Long posts (>3 lines in feed view) truncated with "Read more" link that opens detail screen
- [ ] Empty state when API returns []: illustrated empty graphic with "Be the first to post — share what you're working on"
- [ ] Error state: snackbar + retry button; existing content remains visible

### Pull-to-Refresh
- [ ] Drag-to-refresh gesture triggers new `postsApi.getPosts(page: 0)` call
- [ ] During refresh: show spinner/indicator
- [ ] After refresh: update list (prepend new posts or replace list depending on implementation — consistency matters more than strategy)
- [ ] Refresh error: snackbar notification, existing list unchanged

### Infinite Scroll
- [ ] When scrolled near bottom (e.g., within 200px): fetch next page automatically
- [ ] Pagination: use `?page=N` (offset-based) OR `?before=postId` (cursor-based) depending on backend support — **verify which PostsApi.getPosts supports**
- [ ] Next page appends to list (no duplication check needed; assume backend provides unique records)
- [ ] During load: optional spinner at bottom of list
- [ ] Load-more error: snackbar, do not append partial data

### Likes (Optimistic Update)
- [ ] Like button on each feed card: tappable
- [ ] On tap: immediately toggle like count + button state (optimistic)
- [ ] Call `postsApi.likePost(postId)` in background (do NOT await for UX snappiness)
- [ ] If API fails: revert UI to previous state + show snackbar error
- [ ] Unlike flow: same pattern, call `postsApi.unlikePost(postId)` (must not crash — A0 fixed this)
- [ ] Like state synced with post author state (author's own like count reflects in their feed)

### Create Post Flow
- [ ] Button in app bar or bottom nav tab → navigates to `create_post_screen`
- [ ] Fields:
  - Post type selector (segmented control or chips): General, Collab Needed, Job Post, Announcement
  - Text body (required, max 2000 chars; show char counter "120/2000")
  - Optional image attachment (single image only)
- [ ] Image attachment UX: uses FileReader on web, image_picker on mobile (same pattern as profile photo)
- [ ] Validation: body required, non-empty after trim; show inline error if invalid
- [ ] Submit button: disabled until body is non-empty; shows loading spinner on tap
- [ ] On success: call `postsApi.createPost(body, type, image)` → returns new Post
- [ ] Post create UX: two options (pick one, implement consistently):
  - **Option A:** Optimistic prepend — immediately show new post at top of feed, no refresh
  - **Option B:** Navigate back + re-fetch feed — simpler but less snappy
  - Document which strategy in Completion Report
- [ ] Error on submit: show snackbar error, remain on form, text + image preserved
- [ ] Success: pop back to feed; if Option A, new post visible immediately; if Option B, feed reloads
- [ ] Post type descriptions (optional): brief one-liner under each type option for clarity

### Post Detail Screen
- [ ] Load: `postsApi.getPost(postId)` on init (or use Post passed via GoRouter extra, but ALWAYS refresh from API anyway)
- [ ] Display full post: author profile chip (avatar + name + primary specialty), post text (full, no truncation), image (full size), like count + comment count, relative time
- [ ] Like button: same optimistic pattern as feed
- [ ] Author name → taps to `user_profile_screen`
- [ ] Comments section:
  - Scrollable list of all comments (reverse chronological; newest first is standard)
  - Each comment shows: author avatar + name + text + relative time + delete button (only for comment author or admin)
  - Delete button only visible on own comments (check `comment.authorId == currentUserId`)
  - Tap delete → confirmation snackbar "Comment deleted" (or simple pop)
- [ ] Comment input (sticky above keyboard):
  - Text field: "Add a comment..." placeholder
  - Send button: disabled until text non-empty
  - On send: call `postsApi.addComment(postId, body)` → returns PostComment
  - Optimistically prepend new comment to list
  - On error: show snackbar, remove optimistic comment
- [ ] Empty comments state: "No comments yet — start the conversation"
- [ ] Loading: spinner while detail + comments load
- [ ] Error: snackbar + back button to return to feed

### Report Flow
- [ ] Long-press post card (or 3-dot menu) → triggers report flow
- [ ] Report modal: bottom sheet with reason picker
- [ ] Reasons (5 preset + "Other"):
  - "Spam"
  - "Inappropriate content"
  - "Harassment"
  - "Fake/misleading"
  - "Other"
- [ ] Selecting reason: calls `postsApi.reportPost(postId, reason)`
- [ ] On success: bottom sheet closes + snackbar "Report submitted"
- [ ] On error: snackbar error, modal remains open
- [ ] PostsApi method signature: `reportPost(postId, reason) → Future<void>` — calls backend `POST /posts/:id/report` (C1 endpoint)

### AppState Integration
- [ ] Do NOT store global posts list in AppState (each screen manages local state)
- [ ] Exception: after `createPost()` completes, emit a simple event/callback so if user navigates back to feed it reloads (e.g., use `VoidCallback` passed via route context, or a simple `StreamController<void>` for feed refresh events)
- [ ] No `AppState.notifyListeners()` inside GoRouter push/pop cycles (CLAUDE.md gotcha #13)

---

## User Stories

| Actor | Story | Notes |
|-------|-------|-------|
| Hair stylist | As a hair stylist who just attended an event, I open the community tab and see posts from other creative workers in the network | Retention loop — users stay engaged between events |
| Photographer | As a photographer looking for work, I post a "Collab Needed" post and it appears at the top of the feed immediately | Fast feedback motivates posting |
| User (moderation) | As a user who sees spam, I long-press the post and report it in 2 taps | Community health — easy reporting |
| Post author | As a post author, I see my comment appear instantly when I submit it; if it fails (offline), I see a snackbar error and the failed comment is removed | Optimistic updates feel responsive; graceful failure |
| Post author | As a post author, I can delete my own comments on my posts | Author control over content |
| Casual browser | As a casual browser, I scroll through the feed and new posts load automatically as I reach the bottom | Infinite scroll is frictionless |

---

## Technical Spec

### 1. `community_feed_screen.dart`

**State:**
```dart
class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  late Future<List<Post>> _postsFuture;
  List<Post> _posts = [];
  int _currentPage = 0;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _postsFuture = _loadPosts(page: 0);
  }

  Future<List<Post>> _loadPosts({required int page}) async {
    final posts = await context.read<AppState>().postsApi.getPosts(page: page);
    return posts;
  }

  void _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final nextPosts = await _loadPosts(page: _currentPage + 1);
      if (nextPosts.isEmpty) {
        setState(() => _hasMore = false);
      } else {
        setState(() {
          _posts.addAll(nextPosts);
          _currentPage++;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading more posts: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }
}
```

**UI:**
- FutureBuilder: show spinner while loading
- ListView.builder with NotificationListener for scroll-to-bottom detection
- Each post: `PostCard` widget (see below)
- Pull-to-refresh: RefreshIndicator wrapper
- Empty state + error state as shown in A0 style

**PostCard widget:**
- Avatar (network image, circular)
- Author name + specialty tag (e.g. "Sarah Chen • Makeup Artist")
- Post type badge (color-coded chip or icon label)
- Post body text (truncated to ~3 lines)
- "Read more" link if truncated
- Image preview if present (square thumbnail)
- Like + comment buttons + counts
- Relative time (e.g., "2h ago" via `timeago` package or custom formatter)
- Tap post → `GoRouter.push('/posts/:id')`
- Like button: optimistic toggle + API call
- Long-press: report flow (bottom sheet)

### 2. `create_post_screen.dart`

**State:**
```dart
class _CreatePostScreenState extends State<CreatePostScreen> {
  late TextEditingController _bodyController;
  PostType _selectedType = PostType.general;
  File? _selectedImage;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _bodyController = TextEditingController();
  }

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    // Use image_picker on mobile or FileReader on web (same as profile photo upload)
  }

  Future<void> _submitPost() async {
    if (_bodyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post cannot be empty')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final newPost = await context.read<AppState>().postsApi.createPost(
        body: _bodyController.text,
        type: _selectedType,
        image: _selectedImage,
      );
      if (mounted) {
        // Option A: Optimistic prepend (requires feed to be in scope)
        // Option B: Simple pop, let feed refresh on next open
        Navigator.of(context).pop(newPost); // Pass newPost back to feed
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating post: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
```

**UI:**
- AppBar with title "New Post"
- Post type selector: 4 chips or segmented control (General / Collab Needed / Job Post / Announcement)
- Type descriptions (optional, 1-liner under each)
- Body text field: max 2000 chars, char counter
- Image picker button: "Add photo" button + preview if selected; tap to remove
- Submit button: "Post" text, disabled until body is non-empty, shows spinner when submitting
- Validation inline (red text under body field if empty + trying to submit)

### 3. `post_detail_screen.dart`

**State:**
```dart
class _PostDetailScreenState extends State<PostDetailScreen> {
  late Future<Post> _postFuture;
  late Future<List<PostComment>> _commentsFuture;
  late TextEditingController _commentController;
  List<PostComment> _comments = [];
  Post? _post;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
    final postId = widget.postId;
    _postFuture = context.read<AppState>().postsApi.getPost(postId);
    _commentsFuture = context.read<AppState>().postsApi.getComments(postId);
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;
    final text = _commentController.text;
    _commentController.clear();

    final optimisticComment = PostComment(
      id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
      postId: widget.postId,
      authorId: context.read<AppState>().currentUser!.id,
      authorName: context.read<AppState>().currentUser!.name,
      authorPhoto: context.read<AppState>().currentUser!.photo,
      body: text,
      createdAt: DateTime.now(),
    );
    setState(() => _comments.insert(0, optimisticComment));

    try {
      final newComment = await context.read<AppState>().postsApi.addComment(
        widget.postId,
        text,
      );
      setState(() {
        _comments.removeWhere((c) => c.id == optimisticComment.id);
        _comments.insert(0, newComment);
      });
    } catch (e) {
      setState(() => _comments.removeWhere((c) => c.id == optimisticComment.id));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error posting comment: $e')),
      );
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      await context.read<AppState>().postsApi.deleteComment(
        widget.postId,
        commentId,
      );
      setState(() => _comments.removeWhere((c) => c.id == commentId));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comment deleted')),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting comment: $e')),
      );
    }
  }
}
```

**UI:**
- AppBar with back button
- FutureBuilder for post + comments
- Post section (non-scrollable):
  - Author profile chip: avatar + name + specialty (tap name → user_profile_screen)
  - Post body (full text, no truncation)
  - Post image (if present, full width)
  - Like button + count + comment count + relative time
- Comments list (scrollable):
  - Each comment: avatar + author name + body + relative time + delete button (if author match)
  - Delete button: icon button, red/destructive color
  - Tap delete → confirmation dialog or snackbar (design choice)
- Comment input (sticky above keyboard):
  - TextField with "Add a comment..." placeholder
  - Send button (icon or text) in row
  - On send: optimistically prepend + API call
- Empty comments state: "No comments yet — start the conversation"
- Loading state: full-screen spinner during initial load
- Error state: snackbar + back button

### 4. PostsApi additions (packages/shared/lib/api/posts_api.dart)

**Verify these methods exist and have correct signatures:**

```dart
// Fetch posts with pagination
Future<List<Post>> getPosts({
  int? page,
  String? type,
  String? before, // cursor-based pagination alternative
}) async {
  // Query: GET /posts?page=0&type=general&before=...
  // Returns: List<Post>
}

// Fetch single post with full details
Future<Post> getPost(String postId) async {
  // Query: GET /posts/:id
  // Returns: Post (with author fields, images, full text)
}

// Create new post
Future<Post> createPost({
  required String body,
  required PostType type,
  File? image,
}) async {
  // Multipart POST /posts with FormData (image field if present)
  // Returns: Post (newly created, with id, createdAt, etc.)
}

// Delete post (author or admin only)
Future<void> deletePost(String postId) async {
  // DELETE /posts/:id
}

// Like a post (idempotent)
Future<void> likePost(String postId) async {
  // POST /posts/:id/like
}

// Unlike a post (idempotent)
Future<void> unlikePost(String postId) async {
  // DELETE /posts/:id/like
  // Must NOT throw TypeError (A0 fixed this)
}

// Fetch comments for a post
Future<List<PostComment>> getComments(String postId) async {
  // GET /posts/:id/comments
  // Returns: List<PostComment>
}

// Add comment to post
Future<PostComment> addComment(String postId, String body) async {
  // POST /posts/:id/comments { "body": "..." }
  // Returns: PostComment (newly created)
}

// Delete own comment
Future<void> deleteComment(String postId, String commentId) async {
  // DELETE /posts/:id/comments/:commentId
  // Returns 403 if not author/admin
}

// Report post (C1 endpoint)
Future<void> reportPost(String postId, String reason) async {
  // POST /posts/:id/report { "reason": "Spam" | ... }
  // Returns: empty 200 response
}
```

**Implementation notes:**
- All methods use `client.get()`, `client.post()`, `client.delete()` from ApiClient base class
- Multipart image upload: use `client.uploadFile()` or manual FormData construction
- Error handling: API errors bubble up as exceptions (caught in UI via try/catch)
- JSON deserialization: Dart models use `.fromJson()` auto-generated from `@JsonSerializable` annotations

### 5. AppState Integration

**No global posts list.** Each screen manages its own state:

- `community_feed_screen`: local `_posts` list + pagination state
- `create_post_screen`: form state only
- `post_detail_screen`: local `_post` + `_comments` lists

**Feed refresh event (optional, for better UX):**

If using Option B (pop + re-fetch), consider adding a simple refresh callback:

```dart
// In AppState or as a module-level StreamController:
final feedRefreshStream = StreamController<void>.broadcast();

// In create_post_screen, after successful create:
feedRefreshStream.add(null); // Trigger feed to reload

// In community_feed_screen:
late StreamSubscription _feedRefreshSub;

@override
void initState() {
  super.initState();
  _feedRefreshSub = context.read<AppState>().feedRefreshStream.listen((_) {
    setState(() => _postsFuture = _loadPosts(page: 0));
  });
}

@override
void dispose() {
  _feedRefreshSub.cancel();
  super.dispose();
}
```

Alternatively: simpler approach is Option A (optimistic prepend) — no refresh event needed.

---

## Test Suite

### Widget Tests (packages/social-app/test/features/community/)

**`community_feed_test.dart`:**

```dart
group('CommunityFeedScreen', () {
  testWidgets('renders loading state on init', (tester) async {
    final mockApi = MockPostsApi();
    when(mockApi.getPosts()).thenAnswer((_) => Future.delayed(
      const Duration(seconds: 1),
      () => [],
    ));
    await tester.pumpWidget(buildTestApp(mockApi: mockApi));
    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });

  testWidgets('renders post cards when API returns posts', (tester) async {
    final mockApi = MockPostsApi();
    when(mockApi.getPosts()).thenAnswer((_) async => [
      testPost1,
      testPost2,
    ]);
    await tester.pumpWidget(buildTestApp(mockApi: mockApi));
    await tester.pumpAndSettle();
    expect(find.byType(PostCard), findsNWidgets(2));
    expect(find.text(testPost1.body), findsOneWidget);
  });

  testWidgets('renders empty state when API returns []', (tester) async {
    final mockApi = MockPostsApi();
    when(mockApi.getPosts()).thenAnswer((_) async => []);
    await tester.pumpWidget(buildTestApp(mockApi: mockApi));
    await tester.pumpAndSettle();
    expect(find.text('Be the first to post'), findsOneWidget);
  });

  testWidgets('pull-to-refresh triggers new API call', (tester) async {
    final mockApi = MockPostsApi();
    when(mockApi.getPosts()).thenAnswer((_) async => [testPost1]);
    await tester.pumpWidget(buildTestApp(mockApi: mockApi));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 200));
    await tester.pumpAndSettle();
    verify(mockApi.getPosts()).called(greaterThan(1));
  });

  testWidgets('like button: optimistic toggle + revert on error', (tester) async {
    final mockApi = MockPostsApi();
    when(mockApi.getPosts()).thenAnswer((_) async => [testPost1]);
    when(mockApi.likePost(testPost1.id)).thenThrow(Exception('Network error'));
    await tester.pumpWidget(buildTestApp(mockApi: mockApi));
    await tester.pumpAndSettle();

    final likeButton = find.byIcon(Icons.favorite_border).first;
    expect(find.byIcon(Icons.favorite), findsNothing); // Not yet liked
    await tester.tap(likeButton);
    await tester.pump();
    expect(find.byIcon(Icons.favorite), findsOneWidget); // Optimistic update
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite_border), findsOneWidget); // Reverted on error
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('tapping post navigates to detail screen', (tester) async {
    final mockApi = MockPostsApi();
    when(mockApi.getPosts()).thenAnswer((_) async => [testPost1]);
    await tester.pumpWidget(buildTestApp(mockApi: mockApi));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PostCard).first);
    await tester.pumpAndSettle();
    expect(find.byType(PostDetailScreen), findsOneWidget);
  });
});
```

**`create_post_test.dart`:**

```dart
group('CreatePostScreen', () {
  testWidgets('submit with empty body shows validation error', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Post'));
    await tester.pump();
    expect(find.text('Post cannot be empty'), findsOneWidget);
  });

  testWidgets('submit with valid body calls postsApi.createPost', (tester) async {
    final mockApi = MockPostsApi();
    when(mockApi.createPost(
      body: 'Test post',
      type: PostType.general,
      image: null,
    )).thenAnswer((_) async => testPost1);

    await tester.pumpWidget(buildTestApp(mockApi: mockApi));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Test post');
    await tester.tap(find.text('Post'));
    await tester.pumpAndSettle();

    verify(mockApi.createPost(
      body: 'Test post',
      type: any(named: 'type'),
      image: any(named: 'image'),
    )).called(1);
  });

  testWidgets('post type selector changes selected type', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Job Post'));
    await tester.pump();

    // Verify UI shows Job Post is selected (e.g., chip color or highlight)
    final jobChip = find.byWidgetPredicate(
      (w) => w is Chip && (w.label as Text?)?.data == 'Job Post',
    );
    expect(jobChip, findsOneWidget);
  });
});
```

**`post_detail_test.dart`:**

```dart
group('PostDetailScreen', () {
  testWidgets('loads post and comments on init', (tester) async {
    final mockApi = MockPostsApi();
    when(mockApi.getPost(testPost1.id)).thenAnswer((_) async => testPost1);
    when(mockApi.getComments(testPost1.id)).thenAnswer((_) async => [
      testComment1,
      testComment2,
    ]);

    await tester.pumpWidget(buildTestApp(mockApi: mockApi));
    await tester.pumpAndSettle();

    expect(find.text(testPost1.body), findsOneWidget);
    expect(find.byType(PostComment), findsNWidgets(2));
  });

  testWidgets('comment submit calls postsApi.addComment', (tester) async {
    final mockApi = MockPostsApi();
    when(mockApi.getPost(testPost1.id)).thenAnswer((_) async => testPost1);
    when(mockApi.getComments(testPost1.id)).thenAnswer((_) async => []);
    when(mockApi.addComment(testPost1.id, 'Test comment'))
      .thenAnswer((_) async => testComment1);

    await tester.pumpWidget(buildTestApp(mockApi: mockApi));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Test comment');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    verify(mockApi.addComment(testPost1.id, 'Test comment')).called(1);
  });

  testWidgets('delete button only appears on own comments', (tester) async {
    final mockApi = MockPostsApi();
    when(mockApi.getPost(testPost1.id)).thenAnswer((_) async => testPost1);

    final ownComment = testComment1.copyWith(authorId: currentUserId);
    final otherComment = testComment2.copyWith(authorId: 'other-user-id');

    when(mockApi.getComments(testPost1.id)).thenAnswer((_) async => [
      ownComment,
      otherComment,
    ]);

    await tester.pumpWidget(buildTestApp(mockApi: mockApi));
    await tester.pumpAndSettle();

    // Find delete button count (should be 1, not 2)
    expect(find.byIcon(Icons.delete), findsOneWidget);
  });

  testWidgets('delete comment calls postsApi.deleteComment', (tester) async {
    final mockApi = MockPostsApi();
    when(mockApi.getPost(testPost1.id)).thenAnswer((_) async => testPost1);
    final ownComment = testComment1.copyWith(authorId: currentUserId);
    when(mockApi.getComments(testPost1.id)).thenAnswer((_) async => [ownComment]);
    when(mockApi.deleteComment(testPost1.id, ownComment.id))
      .thenAnswer((_) async => {});

    await tester.pumpWidget(buildTestApp(mockApi: mockApi));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();

    verify(mockApi.deleteComment(testPost1.id, ownComment.id)).called(1);
  });

  testWidgets('report flow: long-press → bottom sheet → select reason', (tester) async {
    final mockApi = MockPostsApi();
    when(mockApi.getPost(testPost1.id)).thenAnswer((_) async => testPost1);
    when(mockApi.getComments(testPost1.id)).thenAnswer((_) async => []);
    when(mockApi.reportPost(testPost1.id, 'Spam'))
      .thenAnswer((_) async => {});

    await tester.pumpWidget(buildTestApp(mockApi: mockApi));
    await tester.pumpAndSettle();

    // Long-press the post or tap 3-dot menu
    // (Exact trigger depends on implementation)
    await tester.longPress(find.text(testPost1.body));
    await tester.pumpAndSettle();

    expect(find.text('Spam'), findsOneWidget);
    await tester.tap(find.text('Spam'));
    await tester.pumpAndSettle();

    verify(mockApi.reportPost(testPost1.id, 'Spam')).called(1);
    expect(find.text('Report submitted'), findsOneWidget);
  });
});
```

---

## Definition of Done

- [ ] All three screens wired to PostsApi
- [ ] Feed loads posts, renders cards, pull-to-refresh works
- [ ] Infinite scroll appends next page on scroll-to-bottom
- [ ] Like/unlike: optimistic updates, revert on error
- [ ] Create post form validates, uploads, and navigates back successfully
- [ ] Post detail loads full post + comments
- [ ] Commenting works: optimistic append, error handling
- [ ] Delete comment: only on own comments, confirmed delete + removal
- [ ] Report flow: long-press → bottom sheet → reason picker → API call → confirmation snackbar
- [ ] Post type badges render with correct colors (grey/purple/green/orange)
- [ ] Empty states + error states render (no crash on empty array or API error)
- [ ] Like count, comment count displayed and updated correctly
- [ ] Relative time formatting ("2h ago") works
- [ ] Author avatars + names display (not "null")
- [ ] Long posts (>3 lines) truncated in feed with "Read more" link
- [ ] All widget tests pass: `cd packages/social-app && flutter test test/features/community/`
- [ ] Flutter build succeeds: `cd packages/social-app && flutter build apk` (or iOS)
- [ ] No AppState.notifyListeners() in push/pop cycles (CLAUDE.md gotcha #13)
- [ ] Code review checklist:
  - [ ] No hardcoded "Loading..." strings (use localizations or constants)
  - [ ] Images use cached_network_image or Image.network with error handling
  - [ ] TextField validation clear and UX-friendly
  - [ ] All async operations have try/catch + mounted checks
  - [ ] No memory leaks (dispose TextEditingControllers, StreamSubscriptions, etc.)
- [ ] Completion Report filled in (below)
- [ ] Interrogative Session completed with Jeff

---

## Completion Report

> To be filled in by the executing agent after implementation is complete.

**Branch:** `feature/A1-community-board`
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

### PostsApi observations (for C0 handoff)
-

### What the next prompt in this track (A2) should know
-

---

## Interrogative Session

**Q1: Does the feed feel snappy and responsive — specifically optimistic like/unlike and comment submit?**
> Jeff:

**Q2: Is pagination working smoothly without duplication or missed posts?**
> Jeff:

**Q3: Did you choose Option A (optimistic prepend) or Option B (pop + refresh) for post creation? Any UX trade-offs observed?**
> Jeff:

**Ready for review:** ☐ Yes
