import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_state.dart';
import '../features/auth/screens/phone_entry_screen.dart';
import '../features/auth/screens/sms_verify_screen.dart';
import '../features/auth/screens/not_registered_screen.dart';
import '../features/onboarding/screens/profile_setup_screen.dart';
import '../features/events/screens/events_list_screen.dart';
import '../features/events/screens/event_detail_screen.dart';
import '../features/events/screens/activation_code_screen.dart';
import '../features/networking/screens/my_qr_screen.dart';
import '../features/networking/screens/qr_scanner_screen.dart';
import '../features/networking/screens/connections_list_screen.dart';
import '../features/community/screens/community_feed_screen.dart';
import '../features/community/screens/create_post_screen.dart';
import '../features/community/screens/post_detail_screen.dart';
import '../features/search/screens/search_screen.dart';
import '../features/search/screens/user_profile_screen.dart';
import '../features/profile/screens/my_profile_screen.dart';
import '../features/profile/screens/settings_screen.dart';
import '../features/perks/screens/perks_screen.dart';
import '../features/perks/screens/sponsor_detail_screen.dart';

/// Route names for navigation
class Routes {
  // Auth
  static const String phoneEntry = '/auth/phone';
  static const String smsVerify = '/auth/verify';
  static const String notRegistered = '/auth/not-registered';

  // Onboarding
  static const String profileSetup = '/onboarding/profile';

  // Main tabs
  static const String events = '/events';
  static const String networking = '/networking';
  static const String community = '/community';
  static const String perks = '/perks';
  static const String profile = '/profile';

  // Events
  static const String eventDetail = '/events/:id';
  static const String activationCode = '/events/:id/checkin';

  // Networking
  static const String myQr = '/networking/qr';
  static const String qrScanner = '/networking/scan';
  static const String connections = '/networking/connections';

  // Community
  static const String createPost = '/community/create';
  static const String postDetail = '/community/post/:id';

  // Search
  static const String search = '/search';
  static const String userProfile = '/users/:id';

  // Profile
  static const String settings = '/profile/settings';

  // Perks
  static const String sponsorDetail = '/perks/:id';
}

class AppRouter {
  static GoRouter router(AppState appState) {
    return GoRouter(
      initialLocation: Routes.phoneEntry,
      refreshListenable: appState,
      redirect: (context, state) {
        final isLoggedIn = appState.isLoggedIn;
        final isOnboarded = appState.isOnboarded;
        final isAuthRoute = state.matchedLocation.startsWith('/auth');
        final isOnboardingRoute = state.matchedLocation.startsWith('/onboarding');

        // Not logged in and not on auth route → redirect to login
        if (!isLoggedIn && !isAuthRoute) {
          return Routes.phoneEntry;
        }

        // Logged in but not onboarded → redirect to profile setup
        if (isLoggedIn && !isOnboarded && !isOnboardingRoute) {
          return Routes.profileSetup;
        }

        // Logged in and on auth route → redirect to events
        if (isLoggedIn && isOnboarded && isAuthRoute) {
          return Routes.events;
        }

        return null;
      },
      routes: [
        // Auth routes
        GoRoute(
          path: Routes.phoneEntry,
          builder: (context, state) => const PhoneEntryScreen(),
        ),
        GoRoute(
          path: Routes.smsVerify,
          builder: (context, state) {
            final phone = state.extra as String? ?? '';
            return SmsVerifyScreen(phone: phone);
          },
        ),
        GoRoute(
          path: Routes.notRegistered,
          builder: (context, state) => const NotRegisteredScreen(),
        ),

        // Onboarding
        GoRoute(
          path: Routes.profileSetup,
          builder: (context, state) => const ProfileSetupScreen(),
        ),

        // Main app with bottom navigation
        ShellRoute(
          builder: (context, state, child) => MainScaffold(child: child),
          routes: [
            GoRoute(
              path: Routes.events,
              builder: (context, state) => const EventsListScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (context, state) {
                    final id = state.pathParameters['id']!;
                    return EventDetailScreen(eventId: id);
                  },
                  routes: [
                    GoRoute(
                      path: 'checkin',
                      builder: (context, state) {
                        final id = state.pathParameters['id']!;
                        return ActivationCodeScreen(eventId: id);
                      },
                    ),
                  ],
                ),
              ],
            ),
            GoRoute(
              path: Routes.networking,
              builder: (context, state) => const MyQrScreen(),
              routes: [
                GoRoute(
                  path: 'scan',
                  builder: (context, state) => const QrScannerScreen(),
                ),
                GoRoute(
                  path: 'connections',
                  builder: (context, state) => const ConnectionsListScreen(),
                ),
              ],
            ),
            GoRoute(
              path: Routes.community,
              builder: (context, state) => const CommunityFeedScreen(),
              routes: [
                GoRoute(
                  path: 'create',
                  builder: (context, state) => const CreatePostScreen(),
                ),
                GoRoute(
                  path: 'post/:id',
                  builder: (context, state) {
                    final id = state.pathParameters['id']!;
                    return PostDetailScreen(postId: id);
                  },
                ),
              ],
            ),
            GoRoute(
              path: Routes.perks,
              builder: (context, state) => const PerksScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (context, state) {
                    final id = state.pathParameters['id']!;
                    return SponsorDetailScreen(sponsorId: id);
                  },
                ),
              ],
            ),
            GoRoute(
              path: Routes.profile,
              builder: (context, state) => const MyProfileScreen(),
              routes: [
                GoRoute(
                  path: 'settings',
                  builder: (context, state) => const SettingsScreen(),
                ),
              ],
            ),
          ],
        ),

        // Search (outside shell)
        GoRoute(
          path: Routes.search,
          builder: (context, state) => const SearchScreen(),
        ),
        GoRoute(
          path: '/users/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return UserProfileScreen(userId: id);
          },
        ),
      ],
    );
  }
}

/// Main scaffold with bottom navigation
class MainScaffold extends StatelessWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _calculateSelectedIndex(context),
        onDestinationSelected: (index) => _onItemTapped(index, context),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event),
            label: 'Events',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_outlined),
            selectedIcon: Icon(Icons.qr_code),
            label: 'Network',
          ),
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum),
            label: 'Community',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_offer_outlined),
            selectedIcon: Icon(Icons.local_offer),
            label: 'Perks',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/events')) return 0;
    if (location.startsWith('/networking')) return 1;
    if (location.startsWith('/community')) return 2;
    if (location.startsWith('/perks')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go(Routes.events);
        break;
      case 1:
        context.go(Routes.networking);
        break;
      case 2:
        context.go(Routes.community);
        break;
      case 3:
        context.go(Routes.perks);
        break;
      case 4:
        context.go(Routes.profile);
        break;
    }
  }
}
