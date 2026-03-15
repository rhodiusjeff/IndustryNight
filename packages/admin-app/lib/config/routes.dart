import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:industrynight_shared/shared.dart';
import '../providers/admin_state.dart';
import '../features/auth/screens/admin_login_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/users/screens/users_list_screen.dart';
import '../features/users/screens/user_detail_screen.dart';
import '../features/users/screens/add_user_screen.dart';
import '../features/events/screens/events_list_screen.dart';
import '../features/events/screens/event_form_screen.dart';
import '../features/events/screens/event_detail_screen.dart';
import '../features/events/screens/image_catalog_screen.dart';
import '../features/events/screens/event_tickets_screen.dart';
import '../features/tickets/screens/tickets_list_screen.dart';
import '../features/customers/screens/customers_list_screen.dart';
import '../features/customers/screens/customer_form_screen.dart';
import '../features/customers/screens/customer_detail_screen.dart';
import '../features/products/screens/product_catalog_screen.dart';
import '../features/products/screens/product_form_screen.dart';
import '../features/customers/screens/discounts_screen.dart';
import '../features/moderation/screens/posts_list_screen.dart';
import '../features/moderation/screens/announcements_screen.dart';
import '../features/settings/screens/admin_settings_screen.dart';
import '../features/settings/screens/markets_screen.dart';
import '../shared/widgets/sidebar.dart';

class AdminRoutes {
  static const String login = '/login';
  static const String dashboard = '/';
  static const String users = '/users';
  static const String userDetail = '/users/:id';
  static const String addUser = '/users/add';
  static const String events = '/events';
  static const String createEvent = '/events/create';
  static const String eventDetail = '/events/:id';
  static const String editEvent = '/events/:id/edit';
  static const String eventTickets = '/events/:id/tickets';
  static const String tickets = '/tickets';
  static const String images = '/images';
  static const String customers = '/customers';
  static const String addCustomer = '/customers/add';
  static const String customerDetail = '/customers/:id';
  static const String editCustomer = '/customers/:id/edit';
  static const String customerDiscounts = '/customers/:id/discounts';
  static const String products = '/products';
  static const String addProduct = '/products/add';
  static const String editProduct = '/products/:id/edit';
  static const String posts = '/moderation/posts';
  static const String announcements = '/moderation/announcements';
  static const String markets = '/markets';
  static const String settings = '/settings';
}

class AdminRouter {
  static GoRouter router(AdminState adminState) {
    return GoRouter(
      initialLocation: AdminRoutes.dashboard,
      refreshListenable: adminState,
      redirect: (context, state) {
        final isLoggedIn = adminState.isLoggedIn;
        final isLoginRoute = state.matchedLocation == AdminRoutes.login;

        if (!isLoggedIn && !isLoginRoute) {
          return AdminRoutes.login;
        }

        if (isLoggedIn && isLoginRoute) {
          return AdminRoutes.dashboard;
        }

        return null;
      },
      routes: [
        GoRoute(
          path: AdminRoutes.login,
          builder: (context, state) => const AdminLoginScreen(),
        ),
        ShellRoute(
          builder: (context, state, child) => AdminScaffold(child: child),
          routes: [
            GoRoute(
              path: AdminRoutes.dashboard,
              builder: (context, state) => const DashboardScreen(),
            ),
            GoRoute(
              path: AdminRoutes.users,
              builder: (context, state) => const UsersListScreen(),
            ),
            GoRoute(
              path: AdminRoutes.addUser,
              builder: (context, state) => const AddUserScreen(),
            ),
            GoRoute(
              path: '/users/:id',
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                final user = state.extra as User?;
                return UserDetailScreen(userId: id, user: user);
              },
            ),
            GoRoute(
              path: AdminRoutes.events,
              builder: (context, state) => const EventsListScreen(),
            ),
            GoRoute(
              path: AdminRoutes.createEvent,
              builder: (context, state) => const EventFormScreen(),
            ),
            GoRoute(
              path: '/events/:id/edit',
              builder: (context, state) {
                final event = state.extra as Event?;
                return EventFormScreen(event: event);
              },
            ),
            GoRoute(
              path: '/events/:id/tickets',
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                return EventTicketsScreen(eventId: id);
              },
            ),
            GoRoute(
              path: '/events/:id',
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                return EventDetailScreen(eventId: id);
              },
            ),
            GoRoute(
              path: AdminRoutes.tickets,
              builder: (context, state) => const TicketsListScreen(),
            ),
            GoRoute(
              path: AdminRoutes.images,
              builder: (context, state) => const ImageCatalogScreen(),
            ),

            // Customers
            GoRoute(
              path: AdminRoutes.customers,
              builder: (context, state) => const CustomersListScreen(),
            ),
            GoRoute(
              path: AdminRoutes.addCustomer,
              builder: (context, state) => const CustomerFormScreen(),
            ),
            GoRoute(
              path: '/customers/:id/edit',
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                final customer = state.extra as Customer?;
                return CustomerFormScreen(customerId: id, customer: customer);
              },
            ),
            GoRoute(
              path: '/customers/:id/discounts',
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                return DiscountsScreen(customerId: id);
              },
            ),
            GoRoute(
              path: '/customers/:id',
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                return CustomerDetailScreen(customerId: id);
              },
            ),

            // Products
            GoRoute(
              path: AdminRoutes.products,
              builder: (context, state) => const ProductCatalogScreen(),
            ),
            GoRoute(
              path: AdminRoutes.addProduct,
              builder: (context, state) => const ProductFormScreen(),
            ),
            GoRoute(
              path: '/products/:id/edit',
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                final product = state.extra as Product?;
                return ProductFormScreen(productId: id, product: product);
              },
            ),

            GoRoute(
              path: AdminRoutes.posts,
              builder: (context, state) => const PostsListScreen(),
            ),
            GoRoute(
              path: AdminRoutes.announcements,
              builder: (context, state) => const AnnouncementsScreen(),
            ),
            GoRoute(
              path: AdminRoutes.markets,
              builder: (context, state) => const MarketsScreen(),
            ),
            GoRoute(
              path: AdminRoutes.settings,
              builder: (context, state) => const AdminSettingsScreen(),
            ),
          ],
        ),
      ],
    );
  }
}

class AdminScaffold extends StatelessWidget {
  final Widget child;

  const AdminScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          const AdminSidebar(),
          Expanded(
            child: child,
          ),
        ],
      ),
    );
  }
}
