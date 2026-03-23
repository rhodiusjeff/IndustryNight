import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:industrynight_social/features/profile/screens/settings_screen.dart';
import 'package:industrynight_social/providers/app_state.dart';
import 'package:industrynight_social/config/routes.dart';
import 'package:industrynight_social/shared/theme/app_theme.dart';
import 'package:industrynight_shared/shared.dart';
import 'package:provider/provider.dart';

class FakeAppState extends AppState {
  FakeAppState({
    required this.fakeUser,
    this.deleteResult = true,
    this.deleteError,
  }) : super(
          apiClient: ApiClient(
            baseUrl: 'http://localhost:3000',
          ),
          storage: SecureStorage(),
        );

  final User? fakeUser;
  final bool deleteResult;
  final String? deleteError;
  int deleteCalls = 0;

  @override
  User? get currentUser => fakeUser;

  @override
  bool get isLoggedIn => fakeUser != null;

  @override
  String? get error => deleteError;

  @override
  Future<bool> deleteAccount() async {
    deleteCalls += 1;
    return deleteResult;
  }
}

Widget _buildTestApp(FakeAppState appState) {
  return ChangeNotifierProvider<AppState>.value(
    value: appState,
    child: MaterialApp(
      theme: AppTheme.darkTheme,
      home: const SettingsScreen(),
    ),
  );
}

User _testUser() {
  final now = DateTime.now();
  return User(
    id: 'user-1',
    phone: '+15555555555',
    name: 'Test User',
    createdAt: now,
  );
}

void main() {
  Future<void> _scrollToDeleteAccount(WidgetTester tester) async {
    final listFinder = find.byType(ListView);
    expect(listFinder, findsOneWidget);
    await tester.drag(listFinder, const Offset(0, -1200));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
  }

  testWidgets('Delete Account button is visible for authenticated users',
      (tester) async {
    final appState = FakeAppState(fakeUser: _testUser());
    await tester.pumpWidget(_buildTestApp(appState));
    await tester.pumpAndSettle();

    await _scrollToDeleteAccount(tester);

    expect(find.text('Danger Zone'), findsOneWidget);
    expect(find.text('Delete Account'), findsWidgets);
  });

  testWidgets('Delete Account opens confirmation dialog', (tester) async {
    final appState = FakeAppState(fakeUser: _testUser());
    await tester.pumpWidget(_buildTestApp(appState));
    await tester.pumpAndSettle();

    await _scrollToDeleteAccount(tester);
    await tester.tap(find.text('Delete Account').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('This cannot be undone.'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('Cancel dismisses dialog without deleting account',
      (tester) async {
    final appState = FakeAppState(fakeUser: _testUser());
    await tester.pumpWidget(_buildTestApp(appState));
    await tester.pumpAndSettle();

    await _scrollToDeleteAccount(tester);
    await tester.tap(find.text('Delete Account').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(appState.deleteCalls, 0);
    expect(find.textContaining('This cannot be undone.'), findsNothing);
  });
}
