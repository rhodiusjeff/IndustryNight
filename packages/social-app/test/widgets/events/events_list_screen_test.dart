import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:industrynight_social/features/events/screens/events_list_screen.dart';
import 'package:network_image_mock/network_image_mock.dart';

import '../../helpers/fake_app_state.dart';

void main() {
  group('EventsListScreen', () {
    testWidgets('shows loading indicator on first frame before API completes',
        (tester) async {
      final appState = FakeAppState();
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(buildTestWidget(EventsListScreen(), appState));
        // Check immediately — first frame has _isLoading = true before async resolves
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    testWidgets('renders without crashing after API resolves (smoke test)',
        (tester) async {
      final appState = FakeAppState();
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(buildTestWidget(EventsListScreen(), appState));
        await tester.pumpAndSettle();
      });

      expect(find.byType(EventsListScreen), findsOneWidget);
    });

    testWidgets('renders on first pump before API resolves (smoke test)',
        (tester) async {
      // Events screen manages its own loading state locally.
      final appState = FakeAppState();
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(buildTestWidget(EventsListScreen(), appState));
        await tester.pump();
      });

      expect(find.byType(EventsListScreen), findsOneWidget);
    });

    testWidgets('renders without crashing (including error state)',
        (tester) async {
      // In test environment, API calls return 400 immediately, so the screen
      // transitions to error state. Verify it renders gracefully.
      final appState = FakeAppState();
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(buildTestWidget(EventsListScreen(), appState));
        await tester.pumpAndSettle();
      });

      expect(find.byType(EventsListScreen), findsOneWidget);
    });
  });
}
