import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../features/auth/screens/phone_entry_screen.dart';
import '../features/auth/screens/sms_verify_screen.dart';
import '../features/onboarding/screens/profile_setup_screen.dart';
import '../features/events/screens/events_list_screen.dart';
import '../features/events/screens/event_detail_screen.dart';
import '../features/events/screens/activation_code_screen.dart';
import '../features/networking/networking_state.dart';
import '../features/networking/screens/connect_tab_screen.dart';
import '../features/networking/screens/qr_scanner_screen.dart';
import '../features/networking/screens/connections_list_screen.dart';
import '../features/community/screens/community_feed_screen.dart';
import '../features/community/screens/create_post_screen.dart';
import '../features/community/screens/post_detail_screen.dart';
import '../features/search/screens/search_screen.dart';
import '../features/search/screens/user_profile_screen.dart';
import '../features/profile/screens/my_profile_screen.dart';
import '../features/profile/screens/edit_profile_screen.dart';
import '../features/profile/screens/settings_screen.dart';
import '../features/perks/screens/perks_screen.dart';
import '../features/perks/screens/sponsor_detail_screen.dart';

/// Route names for navigation
class Routes {
  // Splash
  static const String splash = '/splash';

  // Auth
  static const String phoneEntry = '/auth/phone';
  static const String smsVerify = '/auth/verify';

  // Onboarding
  static const String profileSetup = '/onboarding/profile';

  // Main tabs
  static const String events = '/events';
  static const String connect = '/connect';
  static const String community = '/community';
  static const String network = '/network';
  static const String profile = '/profile';

  // Events
  static const String eventDetail = '/events/:id';
  static const String activationCode = '/events/:id/checkin';

  // Connect
  static const String qrScanner = '/connect/scan';

  // Community
  static const String createPost = '/community/create';
  static const String postDetail = '/community/post/:id';

  // Search
  static const String search = '/search';
  static const String userProfile = '/users/:id';

  // Profile
  static const String settings = '/profile/settings';
  static const String editProfile = '/profile/edit';
  static const String perks = '/profile/perks';
  static const String sponsorDetail = '/profile/perks/:id';
}

class AppRouter {
  static GoRouter router(AppState appState) {
    return GoRouter(
      initialLocation: Routes.splash,
      refreshListenable: appState,
      redirect: (context, state) {
        final isInitialized = appState.isInitialized;
        final isLoggedIn = appState.isLoggedIn;
        final isOnboarded = appState.isOnboarded;
        final isSplash = state.matchedLocation == Routes.splash;
        final isAuthRoute = state.matchedLocation.startsWith('/auth');
        final isOnboardingRoute = state.matchedLocation.startsWith('/onboarding');

        // Still initializing → stay on splash
        if (!isInitialized) {
          return isSplash ? null : Routes.splash;
        }

        // Initialized → leave splash
        if (isSplash) {
          if (!isLoggedIn) return Routes.phoneEntry;
          if (!isOnboarded) return Routes.profileSetup;
          return Routes.events;
        }

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
        // Splash screen (shown while checking auth state)
        GoRoute(
          path: Routes.splash,
          builder: (context, state) => const _SplashScreen(),
        ),

        // Auth routes
        GoRoute(
          path: Routes.phoneEntry,
          builder: (context, state) => const PhoneEntryScreen(),
        ),
        GoRoute(
          path: Routes.smsVerify,
          builder: (context, state) {
            final extras = state.extra as Map<String, dynamic>? ?? {};
            return SmsVerifyScreen(
              phone: extras['phone'] as String? ?? '',
              devCode: extras['devCode'] as String?,
            );
          },
        ),

        // Onboarding
        GoRoute(
          path: Routes.profileSetup,
          builder: (context, state) => const ProfileSetupScreen(),
        ),

        // Main app with bottom navigation
        ShellRoute(
          builder: (context, state, child) {
            final appState = context.read<AppState>();
            return ChangeNotifierProvider(
              create: (_) => NetworkingState(
                connectionsApi: appState.connectionsApi,
                getCurrentUserId: () => appState.currentUser?.id ?? '',
                getActiveEventId: () => appState.activeEventId,
              ),
              child: MainScaffold(child: child),
            );
          },
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
                        final extras = state.extra as Map<String, dynamic>?;
                        return ActivationCodeScreen(
                          eventId: id,
                          eventName: extras?['eventName'] as String?,
                          eventEndTime: extras?['eventEndTime'] != null
                              ? DateTime.parse(extras!['eventEndTime'] as String)
                              : null,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
            GoRoute(
              path: Routes.connect,
              builder: (context, state) => const ConnectTabScreen(),
              routes: [
                GoRoute(
                  path: 'scan',
                  builder: (context, state) => const QrScannerScreen(),
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
              path: Routes.network,
              builder: (context, state) => const ConnectionsListScreen(),
            ),
            GoRoute(
              path: Routes.profile,
              builder: (context, state) => const MyProfileScreen(),
              routes: [
                GoRoute(
                  path: 'edit',
                  builder: (context, state) => const EditProfileScreen(),
                ),
                GoRoute(
                  path: 'settings',
                  builder: (context, state) => const SettingsScreen(),
                ),
                GoRoute(
                  path: 'perks',
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
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event),
            label: 'Events',
          ),
          const NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Network',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_outlined, size: 48),
            selectedIcon: Icon(Icons.qr_code, size: 48),
            label: 'Connect',
          ),
          const NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum),
            label: 'Community',
          ),
          const NavigationDestination(
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
    if (location.startsWith('/network')) return 1;
    if (location.startsWith('/connect')) return 2;
    if (location.startsWith('/community')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go(Routes.events);
        break;
      case 1:
        context.go(Routes.network);
        break;
      case 2:
        context.go(Routes.connect);
        break;
      case 3:
        context.go(Routes.community);
        break;
      case 4:
        context.go(Routes.profile);
        break;
    }
  }
}

/// Splash screen shown while checking auth state on startup
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Image.asset(
            'assets/images/logo_white.png',
            width: double.infinity,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
