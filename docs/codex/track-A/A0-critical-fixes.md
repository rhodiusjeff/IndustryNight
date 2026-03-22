# [Track-A0] Phase 0 Critical Bug Fixes

**Track:** A (Social App + Critical Fixes)
**Sequence:** 1 of 4 in Track A
**Model:** claude-sonnet-4-6
**Alternate Model:** gpt-5.3-codex ← solid choice; the mix of Dart + TypeScript + running flutter build and npx jest to verify fixes plays to its terminal strength. Either model works well here given the tight spec.
**A/B Test:** Yes ⚡ — run both models on `feature/A0-critical-fixes/claude` and `feature/A0-critical-fixes/gpt`; adversarial panel review before merging to `integration`
**Estimated Effort:** Small (3-5 hours)
**Dependencies:** None — can run in parallel with C0 and B0

---

## Context

Read these before writing any code:

- `CLAUDE.md` — full project reference (key gotchas section especially)
- `docs/analysis/implementation_audit.md` — detailed bug descriptions with root causes
- `packages/api/src/routes/posts.ts` — SQL injection bug location
- `packages/api/src/routes/auth.ts` — token refresh 500 error
- `packages/api/src/routes/admin-auth.ts` — admin token refresh 500 error
- `packages/social-app/lib/features/community/` — unlikePost crash location
- `packages/social-app/lib/features/profile/screens/settings_screen.dart` — Delete Account button missing
- `packages/shared/lib/models/post.dart` — post model (author fields)
- `packages/shared/lib/api/posts_api.dart` — unlikePost signature

---

## Goal

Fix six critical bugs that block App Store submission, cause user-facing crashes, or represent security vulnerabilities. Each fix is surgical — change only what is broken. Do not refactor, rename, or reorganize code beyond what is required to fix the specific defect. After this prompt, the social app can be submitted to the App Store (Delete Account present) and the community board wiring (A1) can proceed on a clean foundation.

---

## Acceptance Criteria

**Fix 1 — Delete Account button**
- [ ] Settings screen has a "Delete Account" button in a "Danger Zone" section, visually distinct (red/destructive color)
- [ ] Tapping shows a confirmation dialog: "Are you sure? This permanently deletes your account and all your data. This cannot be undone."
- [ ] Confirming calls `AppState.deleteAccount()` (which calls `DELETE /auth/me`)
- [ ] On success, navigates to login screen and clears all stored tokens
- [ ] Button is only shown when user is authenticated
- [ ] Error state: if the API call fails, shows a toast error and does NOT navigate away

**Fix 2 — Token refresh 500 → 401**
- [ ] `POST /auth/refresh` returns HTTP 401 (not 500) when the refresh token is invalid, expired, or malformed
- [ ] `POST /admin/auth/refresh` returns HTTP 401 (not 500) under the same conditions
- [ ] Error response body: `{ "error": "Invalid or expired refresh token" }`
- [ ] Valid refresh tokens continue to return 200 with new access/refresh token pair
- [ ] JWT `tokenFamily` cross-check: a token with `tokenFamily: 'admin'` sent to `POST /auth/refresh` returns 401

**Fix 3 — unlikePost crash**
- [ ] `PostsApi.unlikePost(postId)` completes without throwing a runtime TypeError
- [ ] `DELETE /posts/:id/like` endpoint returns a consistent response shape (`{ "success": true }` or empty 204)
- [ ] Unlike action in the community feed UI succeeds and decrements the like count optimistically
- [ ] If unlike fails (network error), like count reverts to previous state

**Fix 4 — SQL injection in posts.ts**
- [ ] `GET /posts` query in `packages/api/src/routes/posts.ts` uses parameterized queries for ALL user-controlled values (no string interpolation of `userId` or any request parameter)
- [ ] Behavior of the endpoint is unchanged (same results, same pagination, same filters)
- [ ] Verify by code review: `grep -n "userId" packages/api/src/routes/posts.ts` shows no string template interpolation

**Fix 5 — Post author data shape**
- [ ] `Post` model in `packages/shared/lib/models/post.dart` has `authorName` (String?) and `authorPhoto` (String?) fields (snake_case JSON: `author_name`, `author_photo`)
- [ ] `Post.fromJson()` correctly deserializes `author_name` and `author_photo` from API response
- [ ] Posts displayed in the community feed show the author's name (not "null" or empty)
- [ ] Run `dart run build_runner build` in `packages/shared` after model changes — no build errors

**Fix 6 — Comment delete endpoint**
- [ ] `DELETE /posts/:id/comments/:commentId` endpoint exists in `packages/api/src/routes/posts.ts`
- [ ] Returns 200 `{ "success": true }` if the comment exists and the requesting user is the author OR an admin
- [ ] Returns 403 if the requesting user is neither the comment author nor an admin
- [ ] Returns 404 if the comment does not exist or does not belong to the specified post
- [ ] Comment is removed from the database on success
- [ ] `PostsApi` in `packages/shared/lib/api/posts_api.dart` has a `deleteComment(postId, commentId)` method that calls this endpoint

---

## User Stories

| Actor | Story | Notes |
|-------|-------|-------|
| Social user | As a social user, I want a "Delete Account" button in Settings so that I can permanently delete my account and all my data per App Store requirements | App Store Review Guideline 5.1.1 — required for submission |
| Social user | As a social user, when my refresh token expires I want to be silently redirected to the login screen — not see an error toast about a server crash | 500 errors are confusing and feel like a bug |
| Social user | As a social user, I want to unlike a post I previously liked without the app crashing | Runtime crash is P0 |
| Social user | As a social user, I want to see who wrote each community post so that I know whose content I'm reading | Author null is a display regression |
| Social user | As a social user, I want to delete my own comments on posts | Author control over their content |
| Admin | As an admin user, when my refresh token expires I want to be redirected to the login screen, not see a 500 error | Same as social; admin auth route has the same bug |
| System | As the platform, requests to `/posts` must use parameterized SQL to prevent injection attacks | Security hygiene — low risk but must be clean |

---

## Technical Spec

### Fix 1 — Delete Account (Flutter)

File: `packages/social-app/lib/features/profile/screens/settings_screen.dart`

Add a "Danger Zone" section at the bottom of the settings list. Use `ListTile` with `TextStyle(color: Theme.of(context).colorScheme.error)` for the destructive styling.

```dart
// Confirmation dialog pattern (use dialogContext from builder callback — CLAUDE.md gotcha #12)
showDialog<bool>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    title: const Text('Delete Account'),
    content: const Text(
      'Are you sure? This permanently deletes your account and all your data. '
      'This cannot be undone.',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(dialogContext, false),
        child: const Text('Cancel'),
      ),
      TextButton(
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(dialogContext).colorScheme.error,
        ),
        onPressed: () => Navigator.pop(dialogContext, true),
        child: const Text('Delete Account'),
      ),
    ],
  ),
);
```

After confirmation = true: call `context.read<AppState>().deleteAccount()`. The `deleteAccount()` method should already exist on AppState (it calls `DELETE /auth/me`); if not, add it:

```dart
// packages/social-app/lib/providers/app_state.dart
Future<void> deleteAccount() async {
  await authApi.deleteAccount();
  await SecureStorage().clearAll();
  _currentUser = null;
  notifyListeners();
}
```

### Fix 2 — Token refresh 500 → 401 (TypeScript)

Files: `packages/api/src/routes/auth.ts`, `packages/api/src/routes/admin-auth.ts`

Locate the `POST /refresh` handler in each file. The JWT `verify()` call throws on invalid tokens. Wrap in try/catch:

```typescript
// Before (broken):
const payload = jwt.verify(refreshToken, process.env.JWT_SECRET!) as JwtPayload;

// After (fixed):
let payload: JwtPayload;
try {
  payload = jwt.verify(refreshToken, process.env.JWT_SECRET!) as JwtPayload;
} catch (err) {
  return res.status(401).json({ error: 'Invalid or expired refresh token' });
}

// Add tokenFamily check in auth.ts (social endpoint):
if (payload.tokenFamily !== 'social') {
  return res.status(401).json({ error: 'Invalid token type' });
}

// Add tokenFamily check in admin-auth.ts:
if (payload.tokenFamily !== 'admin') {
  return res.status(401).json({ error: 'Invalid token type' });
}
```

### Fix 3 — unlikePost crash (TypeScript + Dart)

The `DELETE /posts/:id/like` route likely returns an empty body or inconsistent shape. Two-part fix:

**Backend** (`packages/api/src/routes/posts.ts`):
```typescript
// Ensure DELETE /posts/:id/like returns a consistent body
res.json({ success: true });
```

**Dart** (`packages/shared/lib/api/posts_api.dart`):
```dart
// Change unlikePost to ignore response body entirely (most robust)
Future<void> unlikePost(String postId) async {
  await client.delete('/posts/$postId/like');
  // Don't try to parse the response body
}
```

The `ApiClient.delete()` method signature may need to return `void` or the method should ignore the return. Check the base `ApiClient` class and adjust accordingly.

### Fix 4 — SQL injection (TypeScript)

File: `packages/api/src/routes/posts.ts`

Find any query containing `${userId}` or similar template literal interpolation. Replace with parameterized form:

```typescript
// Before (broken):
const result = await db.query(
  `SELECT ... FROM posts WHERE author_id = '${userId}'`
);

// After (fixed):
const result = await db.query(
  `SELECT ... FROM posts WHERE author_id = $1`,
  [userId]
);
```

Review the entire file for any other interpolation patterns and fix all instances.

### Fix 5 — Post author data shape (Dart)

File: `packages/shared/lib/models/post.dart`

Add fields and update `fromJson`. Since `Post` uses `@JsonSerializable(fieldRename: FieldRename.snake)`, simply add:

```dart
final String? authorName;
final String? authorPhoto;
```

Run `cd packages/shared && dart run build_runner build --delete-conflicting-outputs` to regenerate `post.g.dart`.

In the community feed list tile, display `post.authorName ?? 'Unknown'`.

### Fix 6 — Comment delete endpoint (TypeScript + Dart)

**Backend** — add to `packages/api/src/routes/posts.ts`:
```typescript
router.delete('/:id/comments/:commentId', authenticate, async (req, res) => {
  const { id: postId, commentId } = req.params;
  const userId = req.user!.userId;

  // Verify comment exists and belongs to this post
  const comment = await db.query(
    `SELECT id, author_id FROM post_comments WHERE id = $1 AND post_id = $2`,
    [commentId, postId]
  );
  if (comment.rows.length === 0) {
    return res.status(404).json({ error: 'Comment not found' });
  }

  // Check authorization: author or admin
  const isAuthor = comment.rows[0].author_id === userId;
  const isAdmin = req.user!.role === 'platformAdmin';
  if (!isAuthor && !isAdmin) {
    return res.status(403).json({ error: 'Forbidden' });
  }

  await db.query(`DELETE FROM post_comments WHERE id = $1`, [commentId]);
  res.json({ success: true });
});
```

**Dart** — add to `packages/shared/lib/api/posts_api.dart`:
```dart
Future<void> deleteComment(String postId, String commentId) async {
  await client.delete('/posts/$postId/comments/$commentId');
}
```

---

## Test Suite

### Unit Tests (add to `packages/api/src/__tests__/posts.test.ts`)

```typescript
describe('POST /posts fix: SQL parameterization', () => {
  it('GET /posts does not contain string interpolation (static analysis)', () => {
    const fs = require('fs');
    const content = fs.readFileSync('src/routes/posts.ts', 'utf8');
    // Verify no template literal SQL with request parameters
    expect(content).not.toMatch(/`[^`]*\$\{req\.(params|query|body|user)/);
  });
});

describe('POST /auth/refresh', () => {
  it('returns 401 for invalid refresh token', async () => {
    const res = await request(app)
      .post('/auth/refresh')
      .send({ refreshToken: 'not-a-valid-token' });
    expect(res.status).toBe(401);
    expect(res.body.error).toMatch(/invalid|expired/i);
  });

  it('returns 401 for admin token sent to social refresh endpoint', async () => {
    // Create an admin-family token
    const adminToken = jwt.sign(
      { userId: 'test-id', tokenFamily: 'admin' },
      process.env.JWT_SECRET!,
      { expiresIn: '7d' }
    );
    const res = await request(app)
      .post('/auth/refresh')
      .send({ refreshToken: adminToken });
    expect(res.status).toBe(401);
  });

  it('returns 200 for valid social refresh token', async () => {
    // Create social token, verify 200 response
    const socialToken = jwt.sign(
      { userId: testUserId, tokenFamily: 'social' },
      process.env.JWT_SECRET!,
      { expiresIn: '7d' }
    );
    const res = await request(app)
      .post('/auth/refresh')
      .send({ refreshToken: socialToken });
    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('accessToken');
  });
});

describe('DELETE /posts/:id/comments/:commentId', () => {
  it('returns 404 for non-existent comment', async () => {
    const res = await request(app)
      .delete(`/posts/${testPostId}/comments/00000000-0000-0000-0000-000000000000`)
      .set('Authorization', `Bearer ${userToken}`);
    expect(res.status).toBe(404);
  });

  it('returns 403 when non-author tries to delete comment', async () => {
    const res = await request(app)
      .delete(`/posts/${testPostId}/comments/${otherUsersCommentId}`)
      .set('Authorization', `Bearer ${userToken}`);
    expect(res.status).toBe(403);
  });

  it('returns 200 when author deletes their own comment', async () => {
    const res = await request(app)
      .delete(`/posts/${testPostId}/comments/${ownCommentId}`)
      .set('Authorization', `Bearer ${userToken}`);
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);

    // Verify it's gone
    const check = await db.query(
      `SELECT id FROM post_comments WHERE id = $1`,
      [ownCommentId]
    );
    expect(check.rows.length).toBe(0);
  });

  it('admin can delete any comment', async () => {
    const res = await request(app)
      .delete(`/posts/${testPostId}/comments/${anyCommentId}`)
      .set('Authorization', `Bearer ${adminToken}`);
    expect(res.status).toBe(200);
  });
});

describe('DELETE /posts/:id/like (unlikePost)', () => {
  it('returns a parseable response (not empty body)', async () => {
    const res = await request(app)
      .delete(`/posts/${testPostId}/like`)
      .set('Authorization', `Bearer ${userToken}`);
    expect([200, 204]).toContain(res.status);
    if (res.status === 200) {
      expect(res.body).toHaveProperty('success', true);
    }
  });
});
```

### Flutter Widget Tests

Add to `packages/social-app/test/settings_screen_test.dart`:

```dart
testWidgets('Delete Account button is visible in settings', (tester) async {
  // Render settings screen with authenticated user
  await tester.pumpWidget(buildTestApp(isAuthenticated: true));
  expect(find.text('Delete Account'), findsOneWidget);
});

testWidgets('Delete Account shows confirmation dialog', (tester) async {
  await tester.pumpWidget(buildTestApp(isAuthenticated: true));
  await tester.tap(find.text('Delete Account'));
  await tester.pump();
  expect(find.text('This cannot be undone.'), findsOneWidget);
  expect(find.text('Cancel'), findsOneWidget);
});

testWidgets('Cancel dismisses dialog without calling deleteAccount', (tester) async {
  final mockState = MockAppState();
  await tester.pumpWidget(buildTestApp(appState: mockState));
  await tester.tap(find.text('Delete Account'));
  await tester.pump();
  await tester.tap(find.text('Cancel'));
  await tester.pump();
  verifyNever(mockState.deleteAccount());
  expect(find.text('This cannot be undone.'), findsNothing);
});
```

### Smoke Tests (post-deploy)

```bash
# Fix 2: Verify token refresh returns 401 not 500
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST "$API_URL/auth/refresh" \
  -H "Content-Type: application/json" \
  -d '{"refreshToken":"invalid-token"}')
[ "$RESPONSE" = "401" ] || (echo "FAIL: token refresh returned $RESPONSE, expected 401" && exit 1)

# Fix 6: Verify comment delete endpoint exists
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
  -X DELETE "$API_URL/posts/00000000-0000-0000-0000-000000000000/comments/00000000-0000-0000-0000-000000000000" \
  -H "Authorization: Bearer invalid")
[ "$RESPONSE" = "401" ] || (echo "FAIL: comment delete endpoint not found (expected 401 for unauth, got $RESPONSE)" && exit 1)

echo "✓ A0 smoke tests passed"
```

---

## Definition of Done

- [ ] All 6 fixes implemented and committed
- [ ] API tests pass: `cd packages/api && npx jest`
- [ ] Flutter build succeeds: `cd packages/social-app && flutter build apk` (or iOS)
- [ ] `dart run build_runner build` runs clean in `packages/shared` after model changes
- [ ] Manual test: tapping "Unlike" on a post no longer throws a Dart exception
- [ ] Manual test: "Delete Account" button visible in Settings and confirmation dialog appears
- [ ] Smoke tests pass against dev API
- [ ] No existing passing tests are broken
- [ ] Completion Report filled in (below)
- [ ] Interrogative Session completed with Jeff
- [ ] (A/B) Adversarial panel review complete — see `docs/codex/reviews/A0-adversarial-review.md`

---

## Completion Report

> To be filled in by the executing agent after implementation is complete.

**Branch:** `feature/A0-critical-fixes/[claude|gpt]`
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

### What the next prompt in this track (A1) should know
-

---

## Interrogative Session

**Q1: Do all six fixes behave as expected — specifically Delete Account dialog flow and the unlikePost fix?**
> Jeff:

**Q2: Does anything feel off about any of the fixes — UX, error messages, confirmation copy — that the acceptance criteria wouldn't catch?**
> Jeff:

**Q3: Any concerns before adversarial review?**
> Jeff:

**Ready for review:** ☐ Yes
