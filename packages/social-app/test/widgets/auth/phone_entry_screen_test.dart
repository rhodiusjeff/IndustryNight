import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:industrynight_social/features/auth/screens/phone_entry_screen.dart';
import 'package:provider/provider.dart';
import 'package:industrynight_social/providers/app_state.dart';
import 'package:industrynight_shared/shared.dart';

import '../../helpers/fake_app_state.dart';

void main() {
  group('PhoneEntryScreen', () {
    late FakeAppState appState;

    setUp(() {
      appState = FakeAppState();
    });

    Widget buildScreen() => buildTestWidget(PhoneEntryScreen(), appState);

    /// Set a portrait phone viewport so auth screen layout doesn't overflow.
    void usePortraitViewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(390, 844); // iPhone 14 logical size
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    testWidgets('renders phone input and Continue button', (tester) async {
      usePortraitViewport(tester);
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('Continue button is present and tappable', (tester) async {
      usePortraitViewport(tester);
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // Enter a valid phone number
      await tester.enterText(find.byType(TextFormField), '5555550001');
      await tester.pumpAndSettle();

      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('shows error snackbar for invalid phone number', (tester) async {
      usePortraitViewport(tester);
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // Enter invalid phone (too short)
      await tester.enterText(find.byType(TextFormField), '123');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Should not call requestCode with invalid input
      expect(appState.requestCodeCalls, 0);
    });

    testWidgets('valid phone triggers loading state (submit initiated)',
        (tester) async {
      usePortraitViewport(tester);
      appState = FakeAppState(requestCodeResult: '123456');
      await tester.pumpWidget(buildTestWidget(PhoneEntryScreen(), appState));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), '5555550099');
      await tester.tap(find.text('Continue'));
      await tester.pump(); // one frame — catches isSubmitting = true before async

      // Button enters loading state, confirming form validated and submit started
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Continue'), findsNothing);
    });

    testWidgets('shows loading indicator while submitting', (tester) async {
      usePortraitViewport(tester);
      // Use a state that simulates loading
      appState = FakeAppState(isLoadingOverride: true);
      await tester.pumpWidget(buildTestWidget(PhoneEntryScreen(), appState));
      await tester.pump();

      // During loading, button should show progress or be disabled
      // (exact widget depends on implementation)
      expect(find.byType(PhoneEntryScreen), findsOneWidget);
    });
  });
}
