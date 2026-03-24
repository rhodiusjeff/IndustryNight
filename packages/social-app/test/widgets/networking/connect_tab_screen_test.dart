import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:industrynight_shared/shared.dart';
import 'package:industrynight_social/features/networking/screens/connect_tab_screen.dart';
import 'package:industrynight_social/features/networking/networking_state.dart';
import 'package:industrynight_social/providers/app_state.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:provider/provider.dart';

import '../../helpers/fake_app_state.dart';

/// Wraps [ConnectTabScreen] with both required providers.
///
/// [ConnectTabScreen] reads [AppState] and [NetworkingState]. Providing a
/// [NetworkingState] backed by a non-responsive URL lets API calls fail
/// gracefully (caught internally) while keeping widget tests hermetic.
Widget _buildConnectWidget({User? user}) {
  final appState = FakeAppState(fakeUser: user ?? testUser());
  final networkingState = NetworkingState(
    connectionsApi: ConnectionsApi(
      ApiClient(baseUrl: 'http://localhost:3000'),
    ),
    getCurrentUserId: () => appState.currentUser?.id ?? '',
  );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppState>.value(value: appState),
      ChangeNotifierProvider<NetworkingState>.value(value: networkingState),
    ],
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: const ConnectTabScreen(),
    ),
  );
}

void main() {
  group('ConnectTabScreen — inactive state (no active event)', () {
    testWidgets('renders without crashing', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildConnectWidget());
        await tester.pumpAndSettle();
      });

      expect(find.byType(ConnectTabScreen), findsOneWidget);
    });

    testWidgets('shows AppBar with Connect title', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildConnectWidget());
        await tester.pumpAndSettle();
      });

      expect(find.text('Connect'), findsOneWidget);
    });

    testWidgets('shows QR icon in inactive state', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildConnectWidget());
        await tester.pumpAndSettle();
      });

      // Inactive state always shows a large QR code icon as placeholder
      expect(find.byIcon(Icons.qr_code), findsOneWidget);
    });

    testWidgets('shows Browse Events button when no tickets', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildConnectWidget());
        await tester.pumpAndSettle();
      });

      expect(find.text('Browse Events'), findsOneWidget);
    });

    testWidgets('shows CircularProgressIndicator on first frame before API resolves',
        (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(_buildConnectWidget());
        // Check immediately after first frame — _isLoadingTickets starts true
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // After settling, loading resolves and inactive state is shown
        await tester.pumpAndSettle();
        expect(find.byType(ConnectTabScreen), findsOneWidget);
      });
    });
  });
}
