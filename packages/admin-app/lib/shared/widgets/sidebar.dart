import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/routes.dart';

class AdminSidebar extends StatelessWidget {
  const AdminSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Column(
        children: [
          // Logo
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Image.asset(
              'assets/logo.png',
              width: 218,
              fit: BoxFit.fitWidth,
            ),
          ),

          const Divider(height: 1),

          // Navigation items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _NavItem(
                  icon: Icons.dashboard,
                  label: 'Dashboard',
                  route: AdminRoutes.dashboard,
                  isSelected: location == AdminRoutes.dashboard,
                ),
                _NavItem(
                  icon: Icons.people,
                  label: 'Users',
                  route: AdminRoutes.users,
                  isSelected: location.startsWith('/users'),
                ),
                _NavItem(
                  icon: Icons.event,
                  label: 'Events',
                  route: AdminRoutes.events,
                  isSelected: location.startsWith('/events'),
                ),
                _NavItem(
                  icon: Icons.confirmation_number,
                  label: 'Tickets',
                  route: AdminRoutes.tickets,
                  isSelected: location == AdminRoutes.tickets,
                ),
                _NavItem(
                  icon: Icons.photo_library,
                  label: 'Images',
                  route: AdminRoutes.images,
                  isSelected: location.startsWith('/images'),
                ),

                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'REVENUE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                ),
                _NavItem(
                  icon: Icons.business,
                  label: 'Customers',
                  route: AdminRoutes.customers,
                  isSelected: location.startsWith('/customers'),
                ),
                _NavItem(
                  icon: Icons.inventory_2,
                  label: 'Products',
                  route: AdminRoutes.products,
                  isSelected: location.startsWith('/products'),
                ),

                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'MODERATION',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                ),
                _NavItem(
                  icon: Icons.article,
                  label: 'Posts',
                  route: AdminRoutes.posts,
                  isSelected: location == AdminRoutes.posts,
                ),
                _NavItem(
                  icon: Icons.campaign,
                  label: 'Announcements',
                  route: AdminRoutes.announcements,
                  isSelected: location == AdminRoutes.announcements,
                ),

                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'SETTINGS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                ),
                _NavItem(
                  icon: Icons.map,
                  label: 'Markets',
                  route: AdminRoutes.markets,
                  isSelected: location == AdminRoutes.markets,
                ),
                _NavItem(
                  icon: Icons.settings,
                  label: 'Settings',
                  route: AdminRoutes.settings,
                  isSelected: location == AdminRoutes.settings,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final bool isSelected;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? colorScheme.primary : null,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? colorScheme.primary : null,
            fontWeight: isSelected ? FontWeight.w600 : null,
          ),
        ),
        selected: isSelected,
        selectedTileColor: colorScheme.primary.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        onTap: () => context.go(route),
      ),
    );
  }
}
