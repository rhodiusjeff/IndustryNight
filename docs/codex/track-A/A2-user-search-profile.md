# [Track-A2] User Search + Profile Screens

**Track:** A (Social App Completion)
**Sequence:** 3 of 4 in Track A
**Model:** claude-sonnet-4-6
**Alternate Model:** gpt-5.3-codex
**A/B Test:** No
**Estimated Effort:** Medium (8-10 hours) — includes profile photo upload endpoint + Flutter UI (was incorrectly marked Complete in A0)
**Dependencies:** A0 (critical fixes), A1 (community feed wiring)

## Execution Mode (Required)

- [ ] Stage 1 (required): execute and validate locally first (local Postgres + local API + local admin/mobile against local endpoint).
- [ ] Stage 2 (required for backend/integration-impacting tracks): run shared-dev integration smoke only after local pass.
- [ ] Stage 3 (required before PR merge): run AWS dev deploy/integration smoke for final confidence.
- [ ] Completion log must explicitly record: execution mode used, exact commands run, evidence links, and cleanup actions.


---

## Context

Read these before writing any code:

- `docs/codex/EXECUTION_CONTEXT.md` — living operational context: test infrastructure, migration conventions, API ground truth, deployment patterns (read before touching any code)
- `CLAUDE.md` — full project reference, especially Roles and Architecture Decisions sections
- `packages/social-app/lib/features/search/` — existing search_screen.dart (may be stub)
- `packages/social-app/lib/features/profile/screens/my_profile_screen.dart` — current user profile (will refactor)
- `packages/social-app/lib/features/networking/screens/connections_list_screen.dart` — connections (will wire)
- `packages/shared/lib/api/users_api.dart` — user API client (verify or add methods)
- `packages/shared/lib/api/connections_api.dart` — connections API client (verify or add methods)
- `packages/shared/lib/models/user.dart` — User model (may need fields added)
- `packages/social-app/lib/config/routes.dart` — GoRouter config (verify `/users/:userId` route exists)

> **Flutter Widget Test Gotcha:** `FakeAppState.initialize()` MUST be a no-op override in all widget tests. Without this, `SecureStorage` throws `MissingPluginException` in test context. See `EXECUTION_CONTEXT.md` §1 and the reference test at `packages/social-app/test/features/settings/settings_screen_test.dart`.

---

## Goal

Wire the search and profile screens to real API calls. Users can discover other creative workers, view their profiles, see mutual connections, and navigate seamlessly from community feed → user profile → QR scanner for connection. This closes the discovery loop in the social app and enables the complete user-to-user engagement funnel.

---

## Scope

### 1. `search_screen.dart`

**File:** `packages/social-app/lib/features/search/screens/search_screen.dart`

Build a full-featured discovery screen:

- **Search bar:** auto-focuses on mount (`autofocus: true`)
- **Debounce:** 350ms before triggering API call (use `_debounce` from `dart:async` or a custom `Timer`)
- **API call:** `usersApi.searchUsers(query: text)` triggers only for queries >= 2 characters
- **Results display:**
  - List of `User` objects
  - Each item: avatar + name + primary specialty + verification badge (if verified)
  - Tap → navigate to `GoRouter.push('/users/$userId')`
  - Loading state: thin `LinearProgressIndicator` at top (not a full-page spinner — keep results visible while loading)
  - Clear button (X icon) in search bar when text is present
- **Recent searches:** store last 5 searches in memory (List<String>), display below search bar when focused with empty text
- **Empty states:**
  - No query: show hint "Search for photographers, stylists, directors..."
  - Query with no results: "No results for '{query}'"
  - Error state: toast with error message, results remain visible

**Key details:**
- Search should not auto-trigger on screen open; require user input
- Search hints/recent searches should be locally stored, not persisted to disk
- Tapping a result adds it to recent searches (max 5, FIFO)
- Clear recent searches: optional "Clear history" button (minor feature)

### 2. `user_profile_screen.dart` (new; replace or refactor current detail screen)

**File:** `packages/social-app/lib/features/profile/screens/user_profile_screen.dart`

A unified profile display used for:
- Viewing other users (from search, post author tap, connections list)
- Viewing own profile (from bottom nav `/profile` route) — determined by comparing `userId` param to `currentUser.id`

**Screen layout:**

```
┌─────────────────────────────────────┐
│ Cover photo (or gradient fallback)  │
│ [Avatar overlapping bottom]          │
├─────────────────────────────────────┤
│ Name [Verification badge if ✓]      │
│ [Primary specialty chip]             │
│ [Other specialties: up to 4 chips]   │
│ [Bio text — expandable if >3 lines]  │
│                                       │
│ [Social links: Instagram/TikTok/etc] │
│                                       │
│ [Connection status or Connect btn]   │
│ 47 connections | 12 posts            │
├─────────────────────────────────────┤
│ [Edit Profile] (only own profile)    │
│ [Posts below] (only own profile)     │
└─────────────────────────────────────┘
```

**Data loading:**
- On `initState`: `usersApi.getUser(userId)` (detailed user with all fields)
- Load own posts if viewing own profile: `postsApi.getPosts(userId: userId)` (paginated)
- Connection status: `connectionsApi.getConnectionStatus(userId)` → shows "Connected ✓" chip or "Connect" button

**Fields displayed:**
- `name`, `verificationStatus` → badge only if `verified`
- `primarySpecialtyId` + `primarySpecialtyName` → primary specialty chip (prominent color)
- `specialties[]` → secondary specialty chips (up to 4 visible, smaller)
- `bio` → expandable ("Read more" if > 3 lines; "Show less" to collapse)
- `photoUrl` (avatar) + `coverPhotoUrl` (hero)
- `socialLinks.instagram`, `.tikTok`, `.website` → icon buttons (tap → open URL via `url_launcher`)
- `connectionCount` → "47 connections" (tappable for own profile only)
- `postCount` → "12 posts"

**Own profile vs. other profile:**
- **Own profile** (`userId == currentUser.id`):
  - Show "Edit Profile" button in app bar
  - Show "Settings" icon in top-right nav
  - Display own posts list below profile info (paginated, pull-to-refresh)
  - Do NOT show "Connect" button
- **Other profile:**
  - Show "Connect" button if not already connected
  - Show "Message" button (greyed/disabled for now — future feature)
  - Do NOT show "Edit Profile" button
  - Do NOT show own posts (connection's posts can be added later)

**Connection button behavior:**
- If status is `connected: true` → show "Connected ✓" chip (read-only, no tap)
- If status is `connected: false` → show "Connect" button (tap → navigate to QR scanner screen at `/connect/scan`)
- Important: QR connection is the only way to establish mutual connection (no request/accept flow per CLAUDE.md)

**Error handling:**
- User not found (404) → show "This profile is no longer available" and back button
- API error → show toast, allow user to retry by tapping reload button
- Loading state → show skeleton loaders for profile sections

**Post list (own profile only):**
- Below profile info, show user's recent posts
- Use `PostsList` widget or similar (paginated)
- Pull-to-refresh to load new posts
- Tap post → navigate to post_detail_screen

### 3. `my_profile_screen.dart` (refactor to reuse user_profile_screen)

**File:** `packages/social-app/lib/features/profile/screens/my_profile_screen.dart`

Simplify to just a wrapper:

```dart
class MyProfileScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.read(appStateProvider);
    final currentUserId = appState.currentUser?.id;

    if (currentUserId == null) {
      return const LoginScreen(); // or redirect
    }

    return UserProfileScreen(userId: currentUserId);
  }
}
```

Alternatively, add a parameter to `UserProfileScreen`:
```dart
class UserProfileScreen extends ConsumerWidget {
  final String userId;
  final bool isSelf;

  UserProfileScreen({
    required this.userId,
    this.isSelf = false, // or compute from currentUser.id
  });
}
```

Ensure:
- Edit profile navigation still works
- Settings icon in top-right still routes to settings_screen

> **Note:** Profile photo upload was incorrectly marked Complete in A0. The API endpoint does not exist and the Flutter button is disabled. Implement it as part of A2 — see §9 below.

### 4. `connections_list_screen.dart` (fully wire)

**File:** `packages/social-app/lib/features/networking/screens/connections_list_screen.dart`

Display all current user's connections.

**Data loading:**
- On `initState`: `connectionsApi.getConnections()` → List of Connection objects with embedded User profile
- Load once on screen open; support pull-to-refresh

**Display:**
- List of connected users: avatar + name + primary specialty + connection date
- Connection date format: "Connected at Industry Night #12 · 2 weeks ago" (or similar)
- Tap item → `GoRouter.push('/users/$userId')` to view that user's profile
- Empty state: "No connections yet — attend an event and scan some QR codes"
- Search/filter: local filter on already-loaded list (no new API call)

**Connection model:**
The API response for `GET /connections` should include:
- `id`, `userId` (your user), `connectedUserId` (other person), `connectedAt` (DateTime)
- `connectedUser` object embedded with `name`, `specialtyName`, `photoUrl`, `verificationStatus`

### 5. UsersApi additions

**File:** `packages/shared/lib/api/users_api.dart`

Verify or implement:

```dart
// Search users by query string (min 2 chars)
Future<List<User>> searchUsers({
  required String query,
  int limit = 20,
}) async {
  final response = await client.get('/users?q=$query&limit=$limit');
  return (response as List).map((u) => User.fromJson(u as Map<String, dynamic>)).toList();
}

// Get single user by ID (includes all profile fields)
Future<User> getUser(String userId) async {
  final response = await client.get('/users/$userId');
  return User.fromJson(response as Map<String, dynamic>);
}

// Get current authenticated user (alias for /auth/me if needed)
Future<User> getCurrentUser() async {
  final response = await client.get('/auth/me');
  return User.fromJson(response as Map<String, dynamic>);
}
```

**User model fields** (`packages/shared/lib/models/user.dart`):

Verify these exist (add if missing):
- `id` (String)
- `name` (String)
- `photoUrl` (String?)
- `coverPhotoUrl` (String?) — new field for profile hero
- `bio` (String?)
- `verificationStatus` (VerificationStatus — enum: unverified, pending, verified, rejected)
- `primarySpecialtyId` (String?)
- `primarySpecialtyName` (String?) — denormalized for display (from JOIN in API)
- `specialties` (List<Specialty>) — full specialty objects with id + name
- `socialLinks` (SocialLinks) — object with instagram, tikTok, website URLs
- `connectionCount` (int) — computed field from API JOIN COUNT
- `postCount` (int) — computed field from API JOIN COUNT
- `role` (UserRole — enum)
- `createdAt` (DateTime)
- `updatedAt` (DateTime)

After model changes, run:
```bash
cd packages/shared && dart run build_runner build --delete-conflicting-outputs
```

### 6. ConnectionsApi

**File:** `packages/shared/lib/api/connections_api.dart`

Verify or implement:

```dart
// Get all current user's connections
Future<List<Connection>> getConnections({int? limit, int? offset}) async {
  final response = await client.get('/connections?limit=${limit ?? 50}&offset=${offset ?? 0}');
  return (response as List)
      .map((c) => Connection.fromJson(c as Map<String, dynamic>))
      .toList();
}

// Check if connected to specific user
Future<bool> isConnected(String userId) async {
  try {
    final response = await client.get('/connections/$userId');
    return response['connected'] == true;
  } catch (e) {
    return false;
  }
}
```

**Connection model** (`packages/shared/lib/models/connection.dart`):

Verify these fields:
- `id` (String)
- `userId` (String) — your user ID
- `connectedUserId` (String) — the other person
- `connectedAt` (DateTime)
- `connectedUser` (User?) — embedded User profile (name, photo, specialty, verification)

### 7. Navigation updates

**File:** `packages/social-app/lib/config/routes.dart`

### 9. Profile Photo Upload (A2 delivery — was NOT completed in A0)

This feature was incorrectly marked Complete in A0. Both the API endpoint and the Flutter UI are missing. A2 owns full delivery.

#### A. API endpoint — `POST /users/me/photo`

**File:** `packages/api/src/routes/users.ts`

```typescript
// Add multer import at top of file (already used in admin.ts — same pattern)
import multer from 'multer';
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 5 * 1024 * 1024 } });

router.post(
  '/me/photo',
  authenticate,
  upload.single('photo'),
  async (req, res, next): Promise<void> => {
    try {
      if (!req.file) {
        res.status(400).json({ error: 'No file uploaded' });
        return;
      }

      // sharp validation: reject non-images
      let metadata: sharp.Metadata;
      try {
        metadata = await sharp(req.file.buffer).metadata();
      } catch {
        res.status(422).json({ error: 'Invalid image file' });
        return;
      }

      if (!['jpeg', 'png', 'webp'].includes(metadata.format ?? '')) {
        res.status(422).json({ error: 'Unsupported image format. Use JPEG, PNG, or WebP.' });
        return;
      }

      // Resize to max 800px wide, convert to WebP for consistency
      const processed = await sharp(req.file.buffer)
        .resize({ width: 800, withoutEnlargement: true })
        .webp({ quality: 85 })
        .toBuffer();

      const filename = `profile-photos/${req.user!.userId}-${Date.now()}.webp`;
      const url = await uploadImage(processed, filename, 'profile-photos');

      const updated = await queryOne<{ profile_photo_url: string }>(
        'UPDATE users SET profile_photo_url = $1, updated_at = NOW() WHERE id = $2 RETURNING profile_photo_url',
        [url, req.user!.userId]
      );

      res.json({ profilePhotoUrl: updated!.profile_photo_url });
    } catch (error) {
      next(error);
    }
  }
);
```

**Constraints:**
- Max file size: 5MB (multer limit)
- Accepted formats: JPEG, PNG, WebP (sharp validates)
- sharp resizes and converts to WebP before S3 upload
- Returns `{ profilePhotoUrl: string }` on success
- 400 if no file; 422 if not an image or unsupported format
- Graceful degradation: if `s3Available` is false in dev, `uploadImage` returns placeholder URL (existing behavior)

#### B. Flutter UI — `edit_profile_screen.dart`

**File:** `packages/social-app/lib/features/profile/screens/edit_profile_screen.dart`

Wire the currently-disabled photo upload button:

```dart
// Replace the disabled button with:
GestureDetector(
  onTap: _isUploadingPhoto ? null : _pickAndUploadPhoto,
  child: Stack(
    children: [
      CircleAvatar(
        radius: 48,
        backgroundImage: _localPhotoBytes != null
            ? MemoryImage(_localPhotoBytes!) as ImageProvider
            : (user?.profilePhotoUrl != null
                ? NetworkImage(user!.profilePhotoUrl!)
                : null),
        child: (user?.profilePhotoUrl == null && _localPhotoBytes == null)
            ? const Icon(Icons.person, size: 48)
            : null,
      ),
      Positioned(
        bottom: 0, right: 0,
        child: _isUploadingPhoto
            ? const CircularProgressIndicator(strokeWidth: 2)
            : const CircleAvatar(
                radius: 14,
                backgroundColor: Colors.white,
                child: Icon(Icons.camera_alt, size: 16),
              ),
      ),
    ],
  ),
)
```

Add the pick-and-upload handler:

```dart
Uint8List? _localPhotoBytes;
bool _isUploadingPhoto = false;

Future<void> _pickAndUploadPhoto() async {
  // Web: use dart:html FileReader
  // Mobile: use image_picker
  final bytes = await _pickImageBytes();
  if (bytes == null) return;

  setState(() {
    _localPhotoBytes = bytes;
    _isUploadingPhoto = true;
  });

  try {
    final filename = 'profile-${DateTime.now().millisecondsSinceEpoch}.jpg';
    final updatedUser = await context.read<AppState>().usersApi.uploadProfilePhoto(
      bytes,
      filename,
    );
    context.read<AppState>().updateCurrentUser(updatedUser);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo updated')),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
      setState(() { _localPhotoBytes = null; });
    }
  } finally {
    if (mounted) setState(() { _isUploadingPhoto = false; });
  }
}

Future<Uint8List?> _pickImageBytes() async {
  // Use the same FileReader/image_picker pattern as A1 community post image attachment
  // Web: dart:html FileReader (see A1-community-board.md §3 for pattern)
  // Mobile: image_picker ImageSource.gallery
  // Return null if user cancels
}
```

**Packages needed (verify in pubspec.yaml):**
- `image_picker` (already likely present from onboarding — verify)
- `dart:html` for web FileReader (no pubspec entry needed — platform SDK)

#### C. Jest test — `POST /users/me/photo`

Add to `packages/api/src/__tests__/users.test.ts` (or a new `user-photo.test.ts`):

```typescript
describe('POST /users/me/photo', () => {
  it('uploads photo and returns profilePhotoUrl', async () => {
    const res = await request(app)
      .post('/users/me/photo')
      .set('Authorization', `Bearer ${userToken}`)
      .attach('photo', Buffer.from('fake-image-bytes'), { filename: 'test.jpg', contentType: 'image/jpeg' });

    // In test env without S3, expect placeholder URL or actual URL
    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('profilePhotoUrl');
    expect(typeof res.body.profilePhotoUrl).toBe('string');
  });

  it('returns 400 when no file uploaded', async () => {
    const res = await request(app)
      .post('/users/me/photo')
      .set('Authorization', `Bearer ${userToken}`);

    expect(res.status).toBe(400);
  });

  it('returns 422 for non-image file', async () => {
    const res = await request(app)
      .post('/users/me/photo')
      .set('Authorization', `Bearer ${userToken}`)
      .attach('photo', Buffer.from('not an image'), { filename: 'doc.txt', contentType: 'text/plain' });

    expect(res.status).toBe(422);
  });

  it('requires authentication', async () => {
    const res = await request(app)
      .post('/users/me/photo')
      .attach('photo', Buffer.from('fake'), { filename: 'test.jpg', contentType: 'image/jpeg' });

    expect(res.status).toBe(401);
  });

  it('updates profile_photo_url in database after upload', async () => {
    await request(app)
      .post('/users/me/photo')
      .set('Authorization', `Bearer ${userToken}`)
      .attach('photo', Buffer.from('fake-image'), { filename: 'p.jpg', contentType: 'image/jpeg' });

    const user = await db.query('SELECT profile_photo_url FROM users WHERE id = $1', [testUserId]);
    expect(user.rows[0].profile_photo_url).toBeTruthy();
  });
});
```

#### D. Widget test — photo upload button in `edit_profile_screen.dart`

**File:** `packages/social-app/test/features/profile/edit_profile_screen_test.dart`

```dart
testWidgets('Photo upload button is tappable (not null)', (tester) async {
  await tester.pumpWidget(buildTestApp());
  // Camera icon should be present and tappable
  expect(find.byIcon(Icons.camera_alt), findsOneWidget);
  // Should not be disabled
  final gesture = find.byIcon(Icons.camera_alt);
  expect(tester.widget<GestureDetector>(gesture.first).onTap, isNotNull);
});

testWidgets('Shows loading indicator while uploading', (tester) async {
  // Mock usersApi.uploadProfilePhoto to delay
  // Verify CircularProgressIndicator appears during upload
});

testWidgets('Shows snackbar on upload success', (tester) async {
  // Mock uploadProfilePhoto to return updatedUser
  // Verify 'Photo updated' snackbar appears
});

testWidgets('Shows error snackbar on upload failure', (tester) async {
  // Mock uploadProfilePhoto to throw
  // Verify 'Upload failed' snackbar appears
});
```

Verify these routes exist (add if missing):

```dart
GoRoute(
  path: 'users/:userId',
  name: 'user-profile',
  builder: (context, state) {
    final userId = state.pathParameters['userId']!;
    return UserProfileScreen(userId: userId);
  },
),

GoRoute(
  path: 'connect',
  name: 'connect',
  builder: (context, state) => const ConnectTabScreen(),
  routes: [
    GoRoute(
      path: 'scan',
      name: 'qr-scanner',
      builder: (context, state) => const QrScannerScreen(),
    ),
  ],
),

GoRoute(
  path: 'profile',
  name: 'profile',
  builder: (context, state) => MyProfileScreen(),
),
```

**Navigation patterns:**
- Post author name tap (in community_feed_screen or post_detail_screen) → `context.go('/users/$authorId')`
- Connection list item tap → `context.go('/users/$userId')`
- "Connect" button on user profile → `context.push('/connect/scan')` (push so user returns to profile after scanning)
- Search result tap → `context.go('/users/$userId')`

### 8. Post author taps (wiring existing screens)

**Files:**
- `packages/social-app/lib/features/community/screens/community_feed_screen.dart`
- `packages/social-app/lib/features/community/screens/post_detail_screen.dart`

Update post list items and post detail header:

When rendering post author name/avatar, make it tappable:
```dart
GestureDetector(
  onTap: () => context.go('/users/${post.authorId}'),
  child: Row(
    children: [
      CircleAvatar(backgroundImage: NetworkImage(post.authorPhoto ?? '')),
      SizedBox(width: 8),
      Text(post.authorName ?? 'Unknown'),
    ],
  ),
)
```

---

## Acceptance Criteria

- [ ] Search screen renders with auto-focused input and hint text
- [ ] Search debounces 350ms before API call
- [ ] Search results return within 500ms for queries of 2+ characters
- [ ] Results show avatar, name, primary specialty, verification badge if verified
- [ ] Tapping search result navigates to correct user_profile_screen
- [ ] Recent searches stored in memory (max 5 items, FIFO)
- [ ] User profile screen loads and renders for any valid userId
- [ ] User not found (404) shows error message with back button
- [ ] Verification badge renders correctly on verified users
- [ ] Primary specialty chip is prominent; secondary specialties are smaller
- [ ] Bio is expandable if > 3 lines ("Read more" / "Show less")
- [ ] Social links (Instagram, TikTok, Website) open in external browser via url_launcher
- [ ] "Connected ✓" chip shows when viewing a connected user's profile
- [ ] "Connect" button shown when viewing unconnected user's profile
- [ ] Tapping "Connect" button navigates to QR scanner at `/connect/scan`
- [ ] Own profile shows "Edit Profile" button, not "Connect" button
- [ ] Own profile displays own posts below profile info (paginated)
- [ ] Own profile shows "Settings" icon in top-right nav
- [ ] Connections list loads all current user's connections
- [ ] Connections list shows name, specialty, connection date
- [ ] Tapping connection navigates to that user's profile
- [ ] Connections list empty state: "No connections yet..."
- [ ] Local search/filter in connections list works without new API call
- [ ] Post author name tap (in feed) navigates to author's profile
- [ ] Connection count tappable (own profile only) → navigates to connections_list_screen
- [ ] All screens handle loading and error states without white screen flash
- [ ] url_launcher package added to pubspec.yaml (social-app)
- [ ] All API calls use correct endpoints per backend (verify GET /users, GET /users/:id, GET /connections)
- [ ] `POST /users/me/photo` endpoint implemented in `packages/api/src/routes/users.ts` (multer + sharp validation + S3 upload + DB update)
- [ ] `edit_profile_screen.dart` photo upload button wired (not `onPressed: null`)
- [ ] Photo upload shows local preview immediately, loading indicator during upload, success/error snackbar
- [ ] Jest tests cover: upload success, 400 no file, 422 non-image, 401 unauthenticated, DB update verified
- [ ] Widget tests cover: button is tappable, loading state, success snackbar, error snackbar

---

## User Stories

| Actor | Story | Notes |
|-------|-------|-------|
| Creative Worker | As a photographer, I search "stylist" and find stylists to connect with at Industry Night | Discovery loop |
| Creative Worker | As a user, I tap an interesting post author and see their full profile with social media links | Seamless feed-to-profile navigation |
| Creative Worker | As a user, I see my verification badge on my profile so others know I'm verified | Trust signal |
| Creative Worker | As a user, I view all my connections and see when/where we met | Connection history |
| Creative Worker | As a user, I can expand my bio to read the full text | Long-form profile info |
| Creative Worker | As a user viewing someone's profile, I tap "Connect" and it takes me to scan their QR code | Single unified connection flow |
| Creative Worker | As a verified user, my gold/purple verification badge appears on my profile and in search results | Visual distinction |
| Admin | As a platform operator, I can verify all search/profile screens work correctly on mobile devices | QA sign-off |

---

## Test Suite

### Widget Tests

**File:** `packages/social-app/test/features/search/search_screen_test.dart`

```dart
testWidgets('Search screen renders with auto-focused input', (tester) async {
  await tester.pumpWidget(buildTestApp());
  expect(find.byType(TextField), findsOneWidget);
  // Verify input is focused (check focus state or hint visible)
  expect(find.text('Search for photographers'), findsOneWidget);
});

testWidgets('Search hint displayed when no query', (tester) async {
  await tester.pumpWidget(buildTestApp());
  expect(find.text('Search for photographers, stylists, directors...'), findsOneWidget);
});

testWidgets('Typing triggers debounce (wait 350ms before API call)', (tester) async {
  final mockUsersApi = MockUsersApi();
  when(mockUsersApi.searchUsers(query: 'photo'))
      .thenAnswer((_) async => [testUser1, testUser2]);

  await tester.pumpWidget(buildTestApp(usersApi: mockUsersApi));
  await tester.enterText(find.byType(TextField), 'photo');

  // API should NOT be called immediately
  verifyNever(mockUsersApi.searchUsers(query: any));

  // Wait 350ms + pump frame
  await tester.pumpAndSettle(const Duration(milliseconds: 350));

  // API should now be called
  verify(mockUsersApi.searchUsers(query: 'photo')).called(1);
});

testWidgets('Search results display with avatar, name, specialty', (tester) async {
  await tester.pumpWidget(buildTestApp());
  await tester.enterText(find.byType(TextField), 'stylist');
  await tester.pumpAndSettle();

  expect(find.text('Sarah Stylist'), findsOneWidget);
  expect(find.text('Hair Stylist'), findsOneWidget);
  expect(find.byType(CircleAvatar), findsWidgets);
});

testWidgets('Tapping result navigates to user profile', (tester) async {
  await tester.pumpWidget(buildTestApp());
  await tester.enterText(find.byType(TextField), 'stylist');
  await tester.pumpAndSettle();

  await tester.tap(find.text('Sarah Stylist'));
  await tester.pumpAndSettle();

  expect(find.byType(UserProfileScreen), findsOneWidget);
});

testWidgets('Clear button (X) appears when text entered', (tester) async {
  await tester.pumpWidget(buildTestApp());
  expect(find.byIcon(Icons.clear), findsNothing);

  await tester.enterText(find.byType(TextField), 'photo');
  await tester.pumpAndSettle();

  expect(find.byIcon(Icons.clear), findsOneWidget);

  await tester.tap(find.byIcon(Icons.clear));
  await tester.pumpAndSettle();

  expect(find.text('photo'), findsNothing);
});

testWidgets('Recent searches display when search bar focused with no text', (tester) async {
  await tester.pumpWidget(buildTestApp());

  // Perform a search
  await tester.enterText(find.byType(TextField), 'stylist');
  await tester.pumpAndSettle();
  await tester.tap(find.text('Sarah Stylist'));
  await tester.pumpAndSettle();

  // Go back to search screen
  await tester.pageBack();
  await tester.pumpAndSettle();

  // Clear search and focus
  await tester.enterText(find.byType(TextField), '');
  await tester.pumpAndSettle();

  // Recent searches should be visible
  expect(find.text('stylist'), findsOneWidget);
});

testWidgets('Empty state: no query', (tester) async {
  await tester.pumpWidget(buildTestApp());
  expect(find.text('Search for photographers, stylists, directors...'), findsOneWidget);
});

testWidgets('Empty state: query with no results', (tester) async {
  final mockUsersApi = MockUsersApi();
  when(mockUsersApi.searchUsers(query: 'xyz'))
      .thenAnswer((_) async => []);

  await tester.pumpWidget(buildTestApp(usersApi: mockUsersApi));
  await tester.enterText(find.byType(TextField), 'xyz');
  await tester.pumpAndSettle();

  expect(find.text('No results for \'xyz\''), findsOneWidget);
});
```

**File:** `packages/social-app/test/features/profile/user_profile_screen_test.dart`

```dart
testWidgets('User profile loads and displays data', (tester) async {
  final mockUsersApi = MockUsersApi();
  final testUser = User(
    id: '123',
    name: 'John Photographer',
    photoUrl: 'https://...',
    verificationStatus: VerificationStatus.verified,
    primarySpecialtyName: 'Photographer',
    bio: 'Professional photographer',
    connectionCount: 47,
    postCount: 12,
  );
  when(mockUsersApi.getUser('123')).thenAnswer((_) async => testUser);

  await tester.pumpWidget(buildTestApp(usersApi: mockUsersApi, userId: '123'));
  await tester.pumpAndSettle();

  expect(find.text('John Photographer'), findsOneWidget);
  expect(find.text('Photographer'), findsOneWidget);
  expect(find.text('Professional photographer'), findsOneWidget);
  expect(find.text('47 connections'), findsOneWidget);
  expect(find.text('12 posts'), findsOneWidget);
});

testWidgets('Verification badge displays for verified users', (tester) async {
  final verifiedUser = User(
    id: '123',
    name: 'Verified User',
    verificationStatus: VerificationStatus.verified,
  );
  final mockUsersApi = MockUsersApi();
  when(mockUsersApi.getUser('123')).thenAnswer((_) async => verifiedUser);

  await tester.pumpWidget(buildTestApp(usersApi: mockUsersApi, userId: '123'));
  await tester.pumpAndSettle();

  // Look for verification badge (could be icon or chip with verification indicator)
  expect(find.byIcon(Icons.verified), findsOneWidget);
});

testWidgets('Bio expandable when > 3 lines', (tester) async {
  final longBioUser = User(
    id: '123',
    name: 'User',
    bio: 'Line 1\nLine 2\nLine 3\nLine 4\nLine 5',
  );
  final mockUsersApi = MockUsersApi();
  when(mockUsersApi.getUser('123')).thenAnswer((_) async => longBioUser);

  await tester.pumpWidget(buildTestApp(usersApi: mockUsersApi, userId: '123'));
  await tester.pumpAndSettle();

  expect(find.text('Read more'), findsOneWidget);

  await tester.tap(find.text('Read more'));
  await tester.pumpAndSettle();

  expect(find.text('Show less'), findsOneWidget);
  expect(find.text('Line 5'), findsOneWidget);
});

testWidgets('"Connected ✓" chip when already connected', (tester) async {
  final mockUsersApi = MockUsersApi();
  final mockConnectionsApi = MockConnectionsApi();
  final testUser = User(id: '123', name: 'Other User');

  when(mockUsersApi.getUser('123')).thenAnswer((_) async => testUser);
  when(mockConnectionsApi.isConnected('123')).thenAnswer((_) async => true);

  await tester.pumpWidget(buildTestApp(
    usersApi: mockUsersApi,
    connectionsApi: mockConnectionsApi,
    userId: '123',
  ));
  await tester.pumpAndSettle();

  expect(find.text('Connected'), findsOneWidget);
  expect(find.byIcon(Icons.check), findsOneWidget);
});

testWidgets('"Connect" button when not connected', (tester) async {
  final mockUsersApi = MockUsersApi();
  final mockConnectionsApi = MockConnectionsApi();
  final testUser = User(id: '123', name: 'Other User');

  when(mockUsersApi.getUser('123')).thenAnswer((_) async => testUser);
  when(mockConnectionsApi.isConnected('123')).thenAnswer((_) async => false);

  await tester.pumpWidget(buildTestApp(
    usersApi: mockUsersApi,
    connectionsApi: mockConnectionsApi,
    userId: '123',
  ));
  await tester.pumpAndSettle();

  expect(find.text('Connect'), findsOneWidget);
});

testWidgets('Tapping Connect navigates to QR scanner', (tester) async {
  final mockUsersApi = MockUsersApi();
  final mockConnectionsApi = MockConnectionsApi();

  when(mockUsersApi.getUser('123')).thenAnswer((_) async => User(id: '123'));
  when(mockConnectionsApi.isConnected('123')).thenAnswer((_) async => false);

  await tester.pumpWidget(buildTestApp(
    usersApi: mockUsersApi,
    connectionsApi: mockConnectionsApi,
    userId: '123',
  ));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Connect'));
  await tester.pumpAndSettle();

  expect(find.byType(QrScannerScreen), findsOneWidget);
});

testWidgets('Own profile shows Edit button, not Connect', (tester) async {
  final mockUsersApi = MockUsersApi();
  final currentUser = User(id: 'me', name: 'My Profile');

  when(mockUsersApi.getUser('me')).thenAnswer((_) async => currentUser);

  await tester.pumpWidget(buildTestApp(
    usersApi: mockUsersApi,
    currentUserId: 'me',
    userId: 'me',
  ));
  await tester.pumpAndSettle();

  expect(find.text('Edit Profile'), findsOneWidget);
  expect(find.text('Connect'), findsNothing);
});

testWidgets('Own profile displays own posts', (tester) async {
  final mockUsersApi = MockUsersApi();
  final mockPostsApi = MockPostsApi();

  when(mockUsersApi.getUser('me')).thenAnswer((_) async => User(id: 'me'));
  when(mockPostsApi.getPosts(userId: 'me')).thenAnswer((_) async => [
    Post(id: '1', title: 'My Post 1'),
    Post(id: '2', title: 'My Post 2'),
  ]);

  await tester.pumpWidget(buildTestApp(
    usersApi: mockUsersApi,
    postsApi: mockPostsApi,
    currentUserId: 'me',
    userId: 'me',
  ));
  await tester.pumpAndSettle();

  expect(find.text('My Post 1'), findsOneWidget);
  expect(find.text('My Post 2'), findsOneWidget);
});

testWidgets('User not found shows error message', (tester) async {
  final mockUsersApi = MockUsersApi();
  when(mockUsersApi.getUser('invalid'))
      .thenThrow(Exception('User not found'));

  await tester.pumpWidget(buildTestApp(usersApi: mockUsersApi, userId: 'invalid'));
  await tester.pumpAndSettle();

  expect(find.text('This profile is no longer available'), findsOneWidget);
  expect(find.byIcon(Icons.arrow_back), findsOneWidget);
});
```

**File:** `packages/social-app/test/features/networking/connections_list_screen_test.dart`

```dart
testWidgets('Connections list loads and displays', (tester) async {
  final mockConnectionsApi = MockConnectionsApi();
  final testConnections = [
    Connection(
      id: '1',
      userId: 'me',
      connectedUserId: 'user1',
      connectedAt: DateTime(2024, 1, 15),
      connectedUser: User(
        id: 'user1',
        name: 'Sarah Stylist',
        primarySpecialtyName: 'Hair Stylist',
      ),
    ),
  ];

  when(mockConnectionsApi.getConnections()).thenAnswer((_) async => testConnections);

  await tester.pumpWidget(buildTestApp(connectionsApi: mockConnectionsApi));
  await tester.pumpAndSettle();

  expect(find.text('Sarah Stylist'), findsOneWidget);
  expect(find.text('Hair Stylist'), findsOneWidget);
  expect(find.text('2 weeks ago'), findsOneWidget);
});

testWidgets('Tapping connection navigates to profile', (tester) async {
  final mockConnectionsApi = MockConnectionsApi();
  when(mockConnectionsApi.getConnections()).thenAnswer((_) async => [
    Connection(
      connectedUserId: 'user1',
      connectedUser: User(id: 'user1', name: 'User'),
    ),
  ]);

  await tester.pumpWidget(buildTestApp(connectionsApi: mockConnectionsApi));
  await tester.pumpAndSettle();

  await tester.tap(find.text('User'));
  await tester.pumpAndSettle();

  expect(find.byType(UserProfileScreen), findsOneWidget);
});

testWidgets('Empty state when no connections', (tester) async {
  final mockConnectionsApi = MockConnectionsApi();
  when(mockConnectionsApi.getConnections()).thenAnswer((_) async => []);

  await tester.pumpWidget(buildTestApp(connectionsApi: mockConnectionsApi));
  await tester.pumpAndSettle();

  expect(find.text('No connections yet'), findsOneWidget);
});
```

### API Integration Tests

**File:** `packages/api/src/__tests__/users.test.ts`

```typescript
describe('GET /users (search)', () => {
  it('returns users matching query', async () => {
    const res = await request(app)
      .get('/users?q=photographer')
      .set('Authorization', `Bearer ${userToken}`);

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body[0]).toHaveProperty('name');
    expect(res.body[0]).toHaveProperty('primarySpecialtyName');
  });

  it('returns empty array for no matches', async () => {
    const res = await request(app)
      .get('/users?q=nonexistent-query-xyz')
      .set('Authorization', `Bearer ${userToken}`);

    expect(res.status).toBe(200);
    expect(res.body).toEqual([]);
  });

  it('returns users with verification status', async () => {
    const res = await request(app)
      .get('/users?q=test')
      .set('Authorization', `Bearer ${userToken}`);

    expect(res.body[0]).toHaveProperty('verificationStatus');
  });
});

describe('GET /users/:id (profile)', () => {
  it('returns full user profile', async () => {
    const res = await request(app)
      .get(`/users/${testUserId}`)
      .set('Authorization', `Bearer ${userToken}`);

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('name');
    expect(res.body).toHaveProperty('bio');
    expect(res.body).toHaveProperty('photoUrl');
    expect(res.body).toHaveProperty('connectionCount');
    expect(res.body).toHaveProperty('postCount');
    expect(res.body).toHaveProperty('specialties');
    expect(res.body).toHaveProperty('socialLinks');
  });

  it('returns 404 for non-existent user', async () => {
    const res = await request(app)
      .get('/users/00000000-0000-0000-0000-000000000000')
      .set('Authorization', `Bearer ${userToken}`);

    expect(res.status).toBe(404);
  });

  it('includes verification badge for verified users', async () => {
    const res = await request(app)
      .get(`/users/${verifiedUserId}`)
      .set('Authorization', `Bearer ${userToken}`);

    expect(res.body.verificationStatus).toBe('verified');
  });
});

describe('GET /connections', () => {
  it('returns current user connections with embedded profiles', async () => {
    const res = await request(app)
      .get('/connections')
      .set('Authorization', `Bearer ${userToken}`);

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body[0]).toHaveProperty('connectedUserId');
    expect(res.body[0]).toHaveProperty('connectedAt');
    expect(res.body[0]).toHaveProperty('connectedUser');
    expect(res.body[0].connectedUser).toHaveProperty('name');
  });

  it('returns empty array when no connections', async () => {
    const res = await request(app)
      .get('/connections')
      .set('Authorization', `Bearer ${newUserToken}`);

    expect(res.status).toBe(200);
    expect(res.body).toEqual([]);
  });
});
```

---

## Definition of Done

- [ ] search_screen.dart fully implemented with debounce, results, recent searches
- [ ] user_profile_screen.dart fully implemented (both own and other profiles)
- [ ] my_profile_screen.dart refactored to reuse user_profile_screen
- [ ] connections_list_screen.dart wired to API
- [ ] UsersApi methods implemented (searchUsers, getUser, getCurrentUser)
- [ ] ConnectionsApi methods implemented (getConnections, isConnected)
- [ ] User model includes all required fields (connectionCount, postCount, primarySpecialtyName, socialLinks, coverPhotoUrl)
- [ ] Connection model includes embedded User profile
- [ ] GoRouter config has /users/:userId route
- [ ] Post author taps (community feed + post detail) navigate to user profile
- [ ] url_launcher package added to pubspec.yaml (social-app)
- [ ] build_runner executed: `dart run build_runner build` passes in packages/shared
- [ ] All widget tests pass
- [ ] API integration tests pass: `cd packages/api && npx jest`
- [ ] Flutter app builds successfully: `cd packages/social-app && flutter build apk` (or iOS)
- [ ] Manual test: search for "photographer" → results display → tap user → profile loads
- [ ] Manual test: view own profile → shows Edit button, not Connect button
- [ ] Manual test: view other profile → shows Connect button (not connected) or Connected chip (connected)
- [ ] Manual test: tap Connect button → navigates to QR scanner
- [ ] Manual test: connections list displays all connections with date
- [ ] Manual test: post author tap navigates to author's profile
- [ ] No existing tests broken
- [ ] Manual test: tap photo avatar in edit_profile_screen → file picker opens → photo uploads → avatar updates immediately
- [ ] Completion Report filled in (below)
- [ ] Interrogative Session completed with Jeff

---

## Completion Report

> To be filled in by the executing agent after implementation is complete.

**Branch:** `feature/A2-user-search-profile-[claude|gpt]`
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

### What the next prompt in this track (A3) should know
- Profile photo upload endpoint (`POST /users/me/photo`) is implemented and tested — A3 may reference `profile_photo_url` as a known-present field in the User model without re-implementing upload

---

## Interrogative Session

**Q1 (Agent):** Are all search, profile, and connections flows fully wired to the API with no remaining mocks or stubs?
> Jeff:

**Q2 (Agent):** Do social links (Instagram, TikTok, Website) open correctly in the browser, and do they handle missing URLs gracefully?
> Jeff:

**Q3 (Agent):** Is the "Connect" button flow (navigate to QR scanner, no "send request") implemented correctly per CLAUDE.md, and can users return to the profile after scanning?
> Jeff:

**Q4 (Jeff):** How does the profile screen handle the case where a user deletes their account while someone is viewing their profile? Should we show an error or a "profile deleted" state?
> Claude:

**Q5 (Jeff):** Should own posts on the profile be paginated with infinite scroll, or is a fixed list of recent posts (e.g., last 10) sufficient for MVP?
> Claude:

---

## Architecture Notes

**GoRouter integration:**
- `/users/:userId` is a named route that works for both own and other profiles
- `my_profile_screen.dart` is a wrapper that reads `currentUser.id` and pushes to `/users/currentUser.id`
- "Connect" button pushes (not goes) to `/connect/scan` to preserve navigation stack (user can pop back to profile after scanning)

**API response shapes:**
- `GET /users?q=query` returns flat List<User> with all profile fields
- `GET /users/:id` returns User with nested `specialties[]` and `socialLinks` object
- `GET /connections` returns Connection[] with embedded `connectedUser: User`

**State management:**
- AppState holds current user; UsersApi is late final on AppState
- Search results are local (no caching); each search re-queries API
- Connection status checked via lightweight `isConnected()` call on profile load
- Own posts loaded separately on profile init if viewing own profile

**Fields requiring backend JOIN:**
- `User.connectionCount` — SELECT COUNT(*) FROM connections WHERE user_id = $1
- `User.postCount` — SELECT COUNT(*) FROM posts WHERE author_id = $1
- `Connection.connectedUser` — JOIN users table to get profile of the connected person

---

## Known Gotchas

1. **Debounce timing:** Use `Timer` or custom debounce helper; don't rely on `FutureBuilder` rebuild timing.
2. **Recent searches memory-only:** Store in a `List<String>` on screen state, not SharedPreferences. Clear when user logs out.
3. **url_launcher:** Add to pubspec, use `launchUrl(Uri.parse(url))` with `mode: LaunchMode.externalApplication` to open browser.
4. **Own profile detection:** Compare `userId == appState.currentUser?.id`, not user.role. Both are "owned" profiles.
5. **Post list pagination:** For MVP, can load first 10 posts and show "Load more" button. Full infinite scroll is optional.
6. **Connection check:** Lightweight call; can be done on profile load without blocking UI.
7. **Social links object:** If URL is null/empty, don't render the icon button (or render as disabled/greyed).
8. **Verification badge:** Use consistent icon (e.g., `Icons.verified` with app's brand color) across search results and profile.

