# [Track-C2] Push Notifications — Firebase Cloud Messaging (FCM)

**Track:** C (Backend + Schema)
**Sequence:** 3 of 5 in Track C
**Model:** claude-sonnet-4-6
**Alternate Model:** gpt-5.3-codex ← preferred if running inside OpenAI Codex platform; FCM integration with GCP credentials and batch send logic benefits from GPT-5.3-Codex's structured reasoning
**A/B Test:** No
**Estimated Effort:** Medium (6-8 hours)
**Dependencies:** C0 (schema foundation), C1 (device token tracking + wristband columns), X1 (schema consolidation — must be merged before C2 executes; migration numbering depends on X1 output)

## Execution Mode (Required)

- [ ] Stage 1 (required): execute and validate locally first (local Postgres + local API + local admin/mobile against local endpoint).
- [ ] Stage 2 (required for backend/integration-impacting tracks): run shared-dev integration smoke only after local pass.
- [ ] Stage 3 (required before PR merge): run AWS dev deploy/integration smoke for final confidence.
- [ ] Completion log must explicitly record: execution mode used, exact commands run, evidence links, and cleanup actions.


### C0 Winner Handoff (Control Session)

- Winner for C0 execution/apply authority: `claude-sonnet-4-6` (control session decision).
- Source-of-truth migration: `packages/database/migrations/004_phase0_foundation.sql`.
- Assume these C0 outputs exist before implementing C2:
  - `admin_role` includes `moderator` and `eventOps`
  - `users.fcm_token` and `tickets.wristband_issued_at` columns exist
  - `llm_usage_log` exists for FCM/LLM operational telemetry
  - `platform_config` exists for feature flags and runtime config
- Do not retro-edit C0 in this prompt. New schema needs go in a new migration file.

---

## Context

Read these before implementing FCM:

- `docs/codex/EXECUTION_CONTEXT.md` — living operational context: test infrastructure, migration conventions, API ground truth, deployment patterns (read before touching any code)
- `CLAUDE.md` — full project reference (service patterns in sms.ts, email.ts, storage.ts; Flutter integration notes)
- `packages/api/src/services/sms.ts` — graceful degradation pattern (reference implementation)
- `packages/api/src/services/email.ts` — how to handle missing env vars without crashing
- `packages/api/src/services/storage.ts` — S3 integration with fallback behavior
- `packages/social-app/lib/providers/app_state.dart` — where to hook push notification initialization
- `packages/database/migrations/004_phase0_foundation.sql` — users.fcm_token and tickets.wristband_issued_at columns (from C0)
- `packages/api/src/routes/connections.ts` — where QR scan endpoint will integrate FCM call
- `packages/api/src/routes/events.ts` or new wristband endpoint (from C1) — where wristband confirmation will integrate FCM call
- Firebase Console documentation: service account JSON key download, FCM API enablement

---

## Goal

Implement end-to-end Firebase Cloud Messaging (FCM) push notifications for the Industry Night platform. The backend sends notifications; the Flutter social app receives and displays them. The first production use case is new connection notifications (when someone scans your QR code). Wristband confirmation is the second use case. The architecture is fully additive — FCM failures never cause primary flows to fail or throw errors.

---

## Acceptance Criteria

- [ ] Backend FCM service module created at `packages/api/src/services/fcm.ts`
- [ ] `fcm.ts` exports `fcmAvailable: boolean` — true only when FIREBASE_SERVICE_ACCOUNT_JSON or GOOGLE_APPLICATION_CREDENTIALS is set and valid
- [ ] `fcm.ts` exports `sendPushNotification(token, title, body, data?): Promise<boolean>` — returns false on failure without throwing
- [ ] `fcm.ts` exports `sendPushNotificationMulti(tokens, title, body, data?): Promise<{ successCount, failureCount }>` for batch sends
- [ ] Stale token cleanup: if FCM returns `messaging/registration-token-not-registered`, users.fcm_token is set to NULL in DB
- [ ] Environment variables documented: `FIREBASE_SERVICE_ACCOUNT_JSON` (preferred), `GOOGLE_APPLICATION_CREDENTIALS`, `FIREBASE_PROJECT_ID`
- [ ] New connection flow (POST /connections): after creating connection, send FCM to other user's token with title "New Connection!" and connection metadata in data payload
- [ ] Wristband confirmation flow (PATCH /admin/events/:id/attendees/:ticketId/wristband from C1): after setting wristband_issued_at, send FCM to attendee with title "Welcome to {eventName}!" and metadata
- [ ] All FCM sends are fire-and-forget (do not await in request/response cycle; use .catch(console.error))
- [ ] If other user has no fcm_token (null), FCM send is skipped silently (no error)
- [ ] firebase-admin npm package is installed and working
- [ ] K8s secrets template updated with FIREBASE_SERVICE_ACCOUNT_JSON field (documented in comment, not hardcoded)
- [ ] Flutter social app: `pubspec.yaml` updated with firebase_core and firebase_messaging packages
- [ ] Flutter app: `PushNotificationService` class created in `lib/services/push_notification_service.dart`
- [ ] Flutter app: `PushNotificationService.initialize()` requests user permission and registers device token on first launch
- [ ] Flutter app: device token is sent to backend via PATCH /users/me/device-token (from C1)
- [ ] Flutter app: foreground message handler shows snackbar (e.g., "New connection: {name}")
- [ ] Flutter app: background message handler and notification tap routing implemented (navigate to connections list for new_connection, event detail for wristband_confirmed)
- [ ] Flutter app: graceful degradation when notification permission is denied (log, don't crash)
- [ ] Firebase config files (`google-services.json`, `GoogleService-Info.plist`) are NOT committed to repo; `.gitignore` entries added
- [ ] Placeholder README created at `packages/social-app/firebase-setup.md` explaining how to obtain config files
- [ ] iOS entitlements and Info.plist updated with APNs configuration
- [ ] Tests pass: `fcm.test.ts` covers fcmAvailable flag, token cleanup, failure gracefully returns false
- [ ] Integration test: connection flow triggers FCM send with correct payload
- [ ] No hardcoded Firebase credentials or API keys anywhere in codebase

---

## User Stories

| Actor | Story | Notes |
|-------|-------|-------|
| Social app user | As a user at an event, when someone scans my QR code, I receive a push notification within 5 seconds — even if the app is backgrounded — showing their name and the event name | FCM delivery SLA is typically <5sec; backend sends fire-and-forget |
| Social app user | As a new user installing the app, I want notification permission to be requested on first launch, and my device token to be automatically registered so I can receive push notifications without any manual setup | Automatic on app init; stored in users.fcm_token |
| Event attendee | As an attendee at an event, when venue staff confirms my wristband via the admin app, I receive a welcome notification within 5 seconds | PATCH wristband endpoint triggers FCM send |
| Developer (local) | As a developer without Firebase configured, I want the API to start cleanly without crashing, and push sends to return false silently so I can develop locally without GCP credentials | fcmAvailable === false triggers graceful fallback |
| Backend | As the API, I want to batch-send notifications to multiple users (e.g., all event attendees in the future) without blocking the request, so event announcements don't cause latency spikes | sendPushNotificationMulti for future use |
| Platform | As the platform, I want stale FCM tokens to be automatically cleaned up when Firebase reports registration-token-not-registered, so user table doesn't accumulate dead tokens | Automatic on 400 errors from FCM |

---

## Technical Spec

### Backend (packages/api)

#### 1. FCM Service Module (`packages/api/src/services/fcm.ts`)

Pattern matches existing services (sms.ts, email.ts, storage.ts): graceful degradation when Firebase is not configured.

**Structure:**

```typescript
import * as admin from 'firebase-admin';

// Firebase initialized only if credentials available
let firebaseApp: admin.app.App | null = null;
export const fcmAvailable = initializeFirebase();

function initializeFirebase(): boolean {
  try {
    // Priority 1: FIREBASE_SERVICE_ACCOUNT_JSON (for K8s secrets)
    if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
      const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
      firebaseApp = admin.app();
      console.log('[FCM] Firebase initialized via FIREBASE_SERVICE_ACCOUNT_JSON');
      return true;
    }

    // Priority 2: GOOGLE_APPLICATION_CREDENTIALS (for local dev)
    if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
      admin.initializeApp({
        credential: admin.credential.applicationDefault(),
      });
      firebaseApp = admin.app();
      console.log('[FCM] Firebase initialized via GOOGLE_APPLICATION_CREDENTIALS');
      return true;
    }

    console.log('[FCM] Firebase credentials not configured; FCM disabled');
    return false;
  } catch (error) {
    console.error('[FCM] Failed to initialize Firebase:', error);
    return false;
  }
}

/**
 * Send a single push notification.
 * Returns true on success, false on failure (never throws).
 */
export async function sendPushNotification(
  fcmToken: string,
  title: string,
  body: string,
  data?: Record<string, string>
): Promise<boolean> {
  if (!fcmAvailable || !firebaseApp) {
    return false;
  }

  try {
    const messaging = admin.messaging(firebaseApp);
    const message: admin.messaging.Message = {
      token: fcmToken,
      notification: { title, body },
      data,
      webpush: {
        notification: { title, body, icon: '/assets/icon-192.png' },
      },
    };

    const response = await messaging.send(message);
    console.log(`[FCM] Notification sent to ${fcmToken}: ${response}`);
    return true;
  } catch (error: any) {
    // Handle stale token
    if (error.code === 'messaging/registration-token-not-registered') {
      console.warn(`[FCM] Token ${fcmToken} is stale; clearing from DB`);
      await clearStaleToken(fcmToken);
    } else {
      console.error(`[FCM] Send failed for ${fcmToken}:`, error.message);
    }
    return false;
  }
}

/**
 * Batch send to multiple tokens.
 * Returns success + failure counts (never throws).
 */
export async function sendPushNotificationMulti(
  tokens: string[],
  title: string,
  body: string,
  data?: Record<string, string>
): Promise<{ successCount: number; failureCount: number }> {
  if (!fcmAvailable || !firebaseApp) {
    return { successCount: 0, failureCount: tokens.length };
  }

  const results = await Promise.all(
    tokens.map((token) => sendPushNotification(token, title, body, data))
  );

  const successCount = results.filter((r) => r).length;
  const failureCount = results.filter((r) => !r).length;

  console.log(
    `[FCM] Batch send: ${successCount} success, ${failureCount} failure (total: ${tokens.length})`
  );

  return { successCount, failureCount };
}

/**
 * Clear stale FCM token from users table.
 * (Internal function; handles DB cleanup when FCM reports registration-token-not-registered)
 */
async function clearStaleToken(fcmToken: string): Promise<void> {
  try {
    const db = require('../db').default;
    await db.query('UPDATE users SET fcm_token = NULL WHERE fcm_token = $1', [fcmToken]);
  } catch (error) {
    console.error('[FCM] Failed to clear stale token:', error);
  }
}
```

**Exports:**
- `fcmAvailable: boolean` — true only if Firebase credentials are valid
- `sendPushNotification(token, title, body, data?): Promise<boolean>`
- `sendPushNotificationMulti(tokens, title, body, data?): Promise<{ successCount, failureCount }>`

**Behavior:**
- When `FIREBASE_SERVICE_ACCOUNT_JSON` is not set and `GOOGLE_APPLICATION_CREDENTIALS` is not set: `fcmAvailable === false`, all send functions return false silently
- When Firebase returns `registration-token-not-registered`: stale token is cleared from users table automatically
- All errors are logged to console; never thrown to caller
- Fire-and-forget pattern: callers should not await the Promise in the response path

#### 2. Environment Variables

Add to `.env` template and K8s secrets documentation:

```
# Firebase Cloud Messaging (optional)
# Use FIREBASE_SERVICE_ACCOUNT_JSON for K8s secrets (JSON string)
# OR GOOGLE_APPLICATION_CREDENTIALS for local dev (path to file)
FIREBASE_SERVICE_ACCOUNT_JSON=<JSON service account key as string>
GOOGLE_APPLICATION_CREDENTIALS=/path/to/firebase-key.json
FIREBASE_PROJECT_ID=<your-firebase-project-id>
```

**K8s Secrets Note (in infrastructure/k8s/secrets.yaml comment):**
```
# FIREBASE_SERVICE_ACCOUNT_JSON: base64-encoded JSON service account key
# Example: kubectl create secret generic industrynight-secrets \
#   --from-literal=FIREBASE_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'
```

#### 3. Integration: New Connection (QR Scan)

In `packages/api/src/routes/connections.ts`, POST /connections endpoint:

```typescript
// After connection is created in DB:
const otherUser = await db.query(
  'SELECT id, name, fcm_token FROM users WHERE id = $1',
  [connection.to_user_id]
);

if (otherUser.rows[0]?.fcm_token) {
  const { fcmAvailable, sendPushNotification } = await import('../services/fcm');
  if (fcmAvailable) {
    const scannerName = connection.scanner_name || 'Someone';
    const eventName = connection.event_name || 'an event';

    // Fire-and-forget: don't await, use .catch() for logging
    sendPushNotification(
      otherUser.rows[0].fcm_token,
      'New Connection!',
      `${scannerName} connected with you at ${eventName}`,
      {
        type: 'new_connection',
        connectionId: connection.id,
        fromUserId: connection.from_user_id,
        eventName,
      }
    ).catch((err) => console.error('[FCM] Failed to send new connection notification:', err));
  }
}

// Return connection immediately (don't wait for FCM)
res.json(connection);
```

#### 4. Integration: Wristband Confirmation

In `packages/api/src/routes/events.ts` or new endpoint from C1 (PATCH /admin/events/:id/attendees/:ticketId/wristband):

```typescript
// After setting wristband_issued_at:
const ticket = await db.query(
  'SELECT t.id, t.user_id, u.fcm_token, u.name, e.name as event_name FROM tickets t JOIN users u ON t.user_id = u.id JOIN events e ON t.event_id = e.id WHERE t.id = $1',
  [ticketId]
);

if (ticket.rows[0]?.fcm_token) {
  const { fcmAvailable, sendPushNotification } = await import('../services/fcm');
  if (fcmAvailable) {
    // Fire-and-forget
    sendPushNotification(
      ticket.rows[0].fcm_token,
      `Welcome to ${ticket.rows[0].event_name}!`,
      'Your wristband is confirmed. Enjoy the event!',
      {
        type: 'wristband_confirmed',
        eventId: ticketId.split('-')[0], // Extract from ticket if needed
        ticketId: ticket.rows[0].id,
      }
    ).catch((err) => console.error('[FCM] Failed to send wristband notification:', err));
  }
}

// Return ticket immediately
res.json(ticket.rows[0]);
```

#### 5. npm Dependencies

Add to `packages/api/package.json`:

```json
{
  "dependencies": {
    "firebase-admin": "^12.0.0"
  }
}
```

Run `npm install` in packages/api.

#### 6. TypeScript Types

Ensure `firebase-admin` types are available (included in firebase-admin package).

---

### Flutter Social App (packages/social-app)

#### 1. pubspec.yaml Additions

```yaml
dependencies:
  firebase_core: ^3.4.0
  firebase_messaging: ^15.1.0
```

Run `flutter pub get`.

#### 2. Push Notification Service (`packages/social-app/lib/services/push_notification_service.dart`)

Create new file:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart'; // Auto-generated after running flutterfire configure
import '../providers/app_state.dart';
import '../features/networking/screens/connections_list_screen.dart';
import '../features/events/screens/event_detail_screen.dart';

/// Top-level function for background message handler.
/// Firebase SDK calls this when a notification arrives while app is backgrounded.
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling background message: ${message.messageId}');
  // FCM SDK handles display automatically; we just log here.
}

class PushNotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Initialize push notifications: request permission, get token, register with backend.
  Future<void> initialize(AppState appState) async {
    try {
      // Set background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Request permission (iOS; Android 13+ also respects this)
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      print('Permission status: ${settings.authorizationStatus}');

      // If permission denied, return gracefully
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        print('[Push] Notification permission denied; skipping FCM setup');
        return;
      }

      // Get FCM token
      final token = await _messaging.getToken();
      if (token == null) {
        print('[Push] Failed to get FCM token');
        return;
      }

      print('[Push] FCM token: $token');

      // Register token with backend (PATCH /users/me/device-token from C1)
      try {
        await appState.usersApi.registerDeviceToken(token);
        print('[Push] Device token registered with backend');
      } catch (e) {
        print('[Push] Failed to register device token: $e');
        // Non-fatal; don't crash
      }

      // Set up foreground message handler
      setupForegroundMessageHandler(appState);

      // Listen for token refresh (re-register when token changes)
      _messaging.onTokenRefresh.listen((newToken) {
        print('[Push] Token refreshed: $newToken');
        appState.usersApi.registerDeviceToken(newToken).catch(
          (e) => print('[Push] Failed to register refreshed token: $e'),
        );
      });

      // Handle notification tap while app is in foreground/resumed state
      setupNotificationTapHandler(appState);
    } catch (e) {
      print('[Push] Exception during initialization: $e');
      // Non-fatal
    }
  }

  /// Handle messages when app is in foreground.
  void setupForegroundMessageHandler(AppState appState) {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Foreground message received: ${message.notification?.title}');

      // Show snackbar in app
      final notification = message.notification;
      if (notification != null) {
        final title = notification.title ?? 'New notification';
        final body = notification.body ?? '';

        // Show snackbar via AppState or global messenger
        // (Assuming appState has a method or use ScaffoldMessenger globally)
        ScaffoldMessenger.of(appState.navigatorKey.currentContext!).showSnackBar(
          SnackBar(
            content: Text('$title\n$body'),
            duration: const Duration(seconds: 4),
          ),
        );
      }

      // Optionally navigate based on message data
      handleNotificationData(message.data, appState);
    });
  }

  /// Handle notification taps (when user taps notification in notification center).
  void setupNotificationTapHandler(AppState appState) {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Notification opened app: ${message.data}');
      handleNotificationData(message.data, appState);
    });
  }

  /// Route to appropriate screen based on notification data type.
  void handleNotificationData(Map<String, dynamic> data, AppState appState) {
    final type = data['type'];
    final context = appState.navigatorKey.currentContext;
    if (context == null) return;

    if (type == 'new_connection') {
      // Navigate to connections list
      Navigator.of(context).pushNamed('/connections');
    } else if (type == 'wristband_confirmed') {
      // Navigate to event detail
      final eventId = data['eventId'];
      if (eventId != null) {
        Navigator.of(context).pushNamed('/events/$eventId');
      }
    }
  }
}
```

**Note:** This template assumes `appState.navigatorKey` and `appState.usersApi.registerDeviceToken()` exist (from AppState setup). Adjust based on actual AppState structure.

#### 3. Firebase Initialization (`lib/main.dart`)

Add Firebase setup to app entry point:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Auto-generated
import 'services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (must be before runApp)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final appState = Provider.of<AppState>(context, listen: false);

    // Initialize AppState (auth, token restore, etc.)
    await appState.initialize();

    // Initialize push notifications after auth is ready
    if (appState.isLoggedIn) {
      await PushNotificationService().initialize(appState);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: router,
      // ... rest of app config
    );
  }
}
```

**Alternative:** If push notification initialization should happen on every app launch (not just after login), add it before the auth state check.

#### 4. Firebase Config Files (NOT in repo)

Run the flutterfire CLI to generate config files:

```bash
cd packages/social-app
flutterfire configure --project=<your-firebase-project-id>
```

This generates:
- `lib/firebase_options.dart` (auto-generated; safe to commit)
- `android/app/google-services.json` (project-specific; add to .gitignore)
- `ios/Runner/GoogleService-Info.plist` (project-specific; add to .gitignore)

Add to `.gitignore`:

```
# Firebase config (project-specific)
packages/social-app/android/app/google-services.json
packages/social-app/ios/Runner/GoogleService-Info.plist
```

#### 5. iOS Configuration

**Info.plist** (`packages/social-app/ios/Runner/Info.plist`):

Ensure these keys exist (added by flutterfire if missing):

```xml
<key>UIBackgroundModes</key>
<array>
  <string>fetch</string>
  <string>remote-notification</string>
</array>
```

**Entitlements** (`packages/social-app/ios/Runner/Runner.entitlements`):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>aps-environment</key>
  <string>development</string>
  <!-- or 'production' for production builds -->
</dict>
</plist>
```

#### 6. Firebase Setup Documentation

Create `packages/social-app/firebase-setup.md`:

```markdown
# Firebase Setup for Industry Night Social App

## Prerequisites

1. Firebase project created in [Firebase Console](https://console.firebase.google.com)
2. iOS + Android apps registered in the Firebase project
3. Cloud Messaging API enabled

## Configuration

### 1. Generate config files

```bash
cd packages/social-app

# Install flutterfire CLI if not already installed
dart pub global activate flutterfire_cli

# Generate config files for this project
flutterfire configure --project=<your-firebase-project-id>
```

This will generate:
- `lib/firebase_options.dart` (safe to commit)
- `android/app/google-services.json` (do NOT commit)
- `ios/Runner/GoogleService-Info.plist` (do NOT commit)

### 2. iOS Setup

After flutterfire generates config:
1. Open `ios/Runner.xcworkspace` (NOT .xcodeproj) in Xcode
2. Select "Runner" in the project navigator
3. Ensure "Runner" target is selected
4. In Build Settings, search for "Code Signing Identity" and verify it's set
5. In Capabilities, enable "Push Notifications"

### 3. Android Setup

The `google-services.json` file is auto-downloaded by gradle and handled by the google-services plugin.

### 4. Local Development

For local testing without real FCM:
- Mock Firebase services or use Firebase emulator suite
- Ensure Twilio is also mocked/emulated for full testing

## Troubleshooting

- **"google-services.json not found"** — Run `flutterfire configure` again
- **"Token request failed"** — Check that Cloud Messaging API is enabled in Firebase Console
- **"Permission denied"** — User may have declined notification permission; graceful fallback is in place
```

---

## Test Suite

### Backend Tests (`packages/api/src/__tests__/fcm.test.ts`)

```typescript
import { sendPushNotification, sendPushNotificationMulti, fcmAvailable } from '../services/fcm';

describe('FCM Service', () => {
  describe('fcmAvailable flag', () => {
    it('should be false when Firebase credentials are not configured', () => {
      // Run in environment where FIREBASE_SERVICE_ACCOUNT_JSON and GOOGLE_APPLICATION_CREDENTIALS are unset
      expect(fcmAvailable).toBe(false);
    });

    it('should be true when FIREBASE_SERVICE_ACCOUNT_JSON is set and valid', () => {
      // Run in environment where credentials are present (e.g., test container with real Firebase setup)
      // This test may be skipped if real Firebase setup is unavailable in CI
      if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
        expect(fcmAvailable).toBe(true);
      }
    });
  });

  describe('sendPushNotification', () => {
    it('should return false when FCM not available', async () => {
      // Ensure fcmAvailable is false
      const result = await sendPushNotification(
        'fake-token',
        'Test',
        'Test body'
      );
      expect(result).toBe(false);
    });

    it('should return false on invalid token', async () => {
      // Requires real Firebase setup; skip if fcmAvailable is false
      if (!fcmAvailable) this.skip();

      const result = await sendPushNotification(
        'invalid-token-xyz',
        'Test',
        'Test body'
      );
      expect(result).toBe(false);
    });

    it('should return true on success', async () => {
      if (!fcmAvailable) this.skip();
      // This test requires a valid real token; use a test token from Firebase Console
      // For CI, either skip or mock firebase-admin
    });

    it('should clear stale token from DB when registration-token-not-registered error occurs', async () => {
      if (!fcmAvailable) this.skip();
      // Mock firebase-admin to return registration-token-not-registered error
      // Verify that UPDATE users SET fcm_token = NULL is called
    });
  });

  describe('sendPushNotificationMulti', () => {
    it('should return { successCount: 0, failureCount: n } when FCM not available', async () => {
      const tokens = ['token1', 'token2'];
      const result = await sendPushNotificationMulti(
        tokens,
        'Test',
        'Test body'
      );
      expect(result.successCount).toBe(0);
      expect(result.failureCount).toBe(2);
    });

    it('should return success/failure counts', async () => {
      if (!fcmAvailable) this.skip();
      // Mock firebase-admin to return mix of successes/failures
      // Verify counts are correct
    });
  });
});
```

### Integration Test (`packages/api/src/__tests__/connections-fcm.test.ts`)

```typescript
describe('Connections with FCM', () => {
  it('should send push notification to other user when QR connection is created', async () => {
    if (!fcmAvailable) this.skip();

    // Create two users
    const user1 = await createTestUser({ fcm_token: 'valid-test-token-1' });
    const user2 = await createTestUser({ fcm_token: 'valid-test-token-2' });

    // Mock firebase-admin sendPushNotification
    const sendSpy = jest.spyOn(fcmService, 'sendPushNotification');

    // Simulate QR scan
    const response = await request(app)
      .post('/connections')
      .set('Authorization', `Bearer ${user1.token}`)
      .send({ toUserId: user2.id, eventId: 'test-event' });

    expect(response.status).toBe(201);

    // Verify FCM was called with user2's token
    expect(sendSpy).toHaveBeenCalledWith(
      'valid-test-token-2',
      'New Connection!',
      expect.stringContaining(user1.name),
      expect.objectContaining({ type: 'new_connection' })
    );

    sendSpy.mockRestore();
  });

  it('should skip FCM send if other user has no fcm_token', async () => {
    if (!fcmAvailable) this.skip();

    const user1 = await createTestUser({ fcm_token: 'token-1' });
    const user2 = await createTestUser({ fcm_token: null }); // No token

    const sendSpy = jest.spyOn(fcmService, 'sendPushNotification');

    const response = await request(app)
      .post('/connections')
      .set('Authorization', `Bearer ${user1.token}`)
      .send({ toUserId: user2.id, eventId: 'test-event' });

    expect(response.status).toBe(201);
    expect(sendSpy).not.toHaveBeenCalled(); // No FCM call

    sendSpy.mockRestore();
  });
});
```

### Manual Verification

```bash
# 1. Ensure Firebase credentials are set
export FIREBASE_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'

# 2. Run FCM tests (skip if Firebase not configured)
cd packages/api && npx jest fcm.test.ts

# 3. Run integration tests
npx jest connections-fcm.test.ts

# 4. Verify in app:
#    - Launch Flutter social app
#    - Check for notification permission prompt on first launch
#    - Accept permission
#    - Check device logs for FCM token registration
#    - Perform QR scan between two devices
#    - Verify push notification appears on recipient device within 5 seconds
```

### CI/CD Integration

Add to `api.yml` GitHub Actions workflow (if FCM tests are added):

```yaml
- name: Run FCM tests
  run: |
    cd packages/api
    export FIREBASE_SERVICE_ACCOUNT_JSON='${{ secrets.FIREBASE_SERVICE_ACCOUNT_JSON }}'
    npx jest fcm.test.ts connections-fcm.test.ts
```

---

## Definition of Done

- [ ] `packages/api/src/services/fcm.ts` created and exports fcmAvailable, sendPushNotification, sendPushNotificationMulti
- [ ] `fcmAvailable` is false when Firebase credentials not configured
- [ ] firebase-admin npm package installed in packages/api
- [ ] POST /connections integration: FCM send is fire-and-forget after connection created
- [ ] PATCH /admin/events/:id/attendees/:ticketId/wristband integration: FCM send for wristband confirmation
- [ ] Stale token cleanup implemented (registration-token-not-registered error)
- [ ] K8s secrets documentation updated with FIREBASE_SERVICE_ACCOUNT_JSON
- [ ] `packages/social-app/pubspec.yaml` updated with firebase_core and firebase_messaging
- [ ] `packages/social-app/lib/services/push_notification_service.dart` created
- [ ] `PushNotificationService.initialize()` requests permission and registers token
- [ ] `PushNotificationService.initialize()` gracefully handles permission denial (no crash)
- [ ] Foreground and background message handlers implemented
- [ ] Notification tap routing implemented (navigate to connections/event detail)
- [ ] `packages/social-app/.gitignore` includes google-services.json and GoogleService-Info.plist
- [ ] `packages/social-app/firebase-setup.md` created with setup instructions
- [ ] iOS entitlements and Info.plist configured for APNs
- [ ] `fcm.test.ts` and `connections-fcm.test.ts` tests pass
- [ ] No hardcoded Firebase credentials in codebase
- [ ] Completion Report filled in (below)
- [ ] Interrogative Session completed with Jeff

---

## Completion Report

> To be filled in by the executing agent after implementation is complete.

**Branch:** `feature/C2-push-notifications`
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

### Firebase project prerequisites
- [ ] Firebase project created
- [ ] iOS app registered in Firebase
- [ ] Android app registered in Firebase
- [ ] Cloud Messaging API enabled
- [ ] Service account key downloaded

**If Firebase project setup is incomplete, note this as a blocker and do not mark this prompt complete.**

### What the next prompt in this track (C3) should know
-

---

## Interrogative Session

**Q1: Did you successfully implement the FCM service with graceful degradation — does it start cleanly when Firebase credentials are missing?**
> Jeff:

**Q2: Is the fire-and-forget pattern in place for both integration points (new connection and wristband)? Verify that a Firebase outage or slow response does not delay the API response to the client.**
> Jeff:

**Q3: Did you test the complete Flutter flow — permission request, token registration, receiving a foreground notification, and tapping it to navigate?**
> Jeff:

**Q4: Are the Firebase config files (google-services.json, GoogleService-Info.plist) properly gitignored and documented so team members know how to obtain them?**
> Jeff:

**Q5: Did the stale token cleanup work — i.e., when Firebase reports registration-token-not-registered, is the DB updated automatically?**
> Jeff:

**Q6 (Deployment): Have you updated the K8s secrets template and documented where FIREBASE_SERVICE_ACCOUNT_JSON goes?**
> Jeff:

**Q7 (Testing): Are the fcm.test.ts and connections-fcm.test.ts integration tests in place and passing?**
> Jeff:

**Ready for review:** ☐ Yes
