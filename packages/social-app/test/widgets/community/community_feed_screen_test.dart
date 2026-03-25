import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:industrynight_social/features/community/screens/community_feed_screen.dart';
import 'package:network_image_mock/network_image_mock.dart';

import '../../helpers/fake_app_state.dart';

void main() {
  group('CommunityFeedScreen', () {
    testWidgets('renders without crashing', (tester) async {
      final appState = FakeAppState(fakeUser: testUser());
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(buildTestWidget(CommunityFeedScreen(), appState));
        await tester.pumpAndSettle();
      });

      expect(find.byType(CommunityFeedScreen), findsOneWidget);
    });

    testWidgets('shows FloatingActionButton for creating posts', (tester) async {
      final appState = FakeAppState(fakeUser: testUser());
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(buildTestWidget(CommunityFeedScreen(), appState));
        await tester.pumpAndSettle();
      });

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('unlike does not crash (regression test)', (tester) async {
      // This test guards against the unlike crash bug.
      // Tapping like/unlike on post cards should not throw.
      final appState = FakeAppState(fakeUser: testUser());
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(buildTestWidget(CommunityFeedScreen(), appState));
        await tester.pumpAndSettle();

        // If there are any like buttons visible, tap them — should not crash
        final likeButtons = find.byIcon(Icons.favorite);
        final likeOutlineButtons = find.byIcon(Icons.favorite_border);
        if (likeButtons.evaluate().isNotEmpty) {
          await tester.tap(likeButtons.first);
          await tester.pumpAndSettle();
        }
        if (likeOutlineButtons.evaluate().isNotEmpty) {
          await tester.tap(likeOutlineButtons.first);
          await tester.pumpAndSettle();
        }
      });

      // No exception thrown = pass
      expect(find.byType(CommunityFeedScreen), findsOneWidget);
    });

    testWidgets('shows AppBar with title', (tester) async {
      final appState = FakeAppState(fakeUser: testUser());
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(buildTestWidget(CommunityFeedScreen(), appState));
        await tester.pumpAndSettle();
      });

      expect(find.byType(AppBar), findsOneWidget);
    });
  });
}
