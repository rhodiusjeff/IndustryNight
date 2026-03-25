import 'package:flutter/material.dart';
import 'package:industrynight_shared/shared.dart';
import 'package:industrynight_social/providers/app_state.dart';
import 'package:provider/provider.dart';

/// Shared FakeAppState for widget tests.
///
/// Override only what each test needs — everything else returns sensible defaults.
class FakeAppState extends AppState {
  FakeAppState({
    this.fakeUser,
    this.fakeEvents = const [],
    this.deleteResult = true,
    this.deleteError,
    this.isLoadingOverride = false,
    this.requestCodeResult,
    this.verifyCodeResult,
  }) : super(
          apiClient: ApiClient(baseUrl: 'http://localhost:3000'),
          storage: SecureStorage(),
        );

  final User? fakeUser;
  final List<Event> fakeEvents;
  final bool deleteResult;
  final String? deleteError;
  final bool isLoadingOverride;
  final String? requestCodeResult; // devCode returned
  final bool? verifyCodeResult;

  int deleteCalls = 0;
  int requestCodeCalls = 0;
  int verifyCodeCalls = 0;
  String? lastRequestedPhone;
  String? lastVerifiedCode;

  @override
  User? get currentUser => fakeUser;

  @override
  bool get isLoggedIn => fakeUser != null;

  @override
  bool get isLoading => isLoadingOverride;

  @override
  String? get error => deleteError;

  // No-op: prevents MissingPluginException from SecureStorage in widget tests.
  @override
  Future<void> initialize() async {}

  @override
  Future<bool> deleteAccount() async {
    deleteCalls++;
    return deleteResult;
  }

  @override
  Future<String?> requestVerificationCode(String phone) async {
    requestCodeCalls++;
    lastRequestedPhone = phone;
    return requestCodeResult;
  }

  @override
  Future<bool> verifyCode(String phone, String code) async {
    verifyCodeCalls++;
    lastVerifiedCode = code;
    return verifyCodeResult ?? true;
  }
}

/// Test user with sensible defaults.
User testUser({
  String id = 'user-test-1',
  String phone = '+15555550001',
  String name = 'Test User',
  String? bio,
  String? profilePhotoUrl,
}) {
  final now = DateTime.now();
  return User(
    id: id,
    phone: phone,
    name: name,
    bio: bio,
    profilePhotoUrl: profilePhotoUrl,
    createdAt: now,
  );
}

/// Wrap a widget with Provider and MaterialApp for testing.
Widget buildTestWidget(
  Widget child,
  FakeAppState appState, {
  ThemeData? theme,
}) {
  return ChangeNotifierProvider<AppState>.value(
    value: appState,
    child: MaterialApp(
      theme: theme ?? ThemeData.dark(),
      home: child,
    ),
  );
}
