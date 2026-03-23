import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../config/routes.dart';
import '../../../providers/app_state.dart';
import '../../../shared/theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final user = appState.currentUser;
    final hasEmail = user?.email != null && user!.email!.isNotEmpty;
    final isAuthenticated = appState.isLoggedIn;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Account section
          _buildSectionHeader('Account'),
          ListTile(
            leading: const Icon(Icons.phone),
            title: const Text('Phone Number'),
            subtitle: Text(
              user?.phone ?? '',
            ),
          ),

          const Divider(),

          // Notifications
          _buildSectionHeader('Notifications'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications),
            title: const Text('Push Notifications'),
            value: true, // TODO: Get from settings
            onChanged: (value) {},
          ),
          SwitchListTile(
            secondary: const Icon(Icons.email),
            title: const Text('Email Notifications'),
            subtitle: hasEmail
                ? null
                : Text(
                    'Add an email in Edit Profile to enable',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
            value: false, // TODO: Get from settings
            onChanged: hasEmail ? (value) {} : null,
          ),

          const Divider(),

          // Support
          _buildSectionHeader('Support'),
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('Help Center'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('Terms of Service'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),

          const Divider(),

          if (isAuthenticated) ...[
            _buildSectionHeader('Danger Zone'),
            ListTile(
              leading: Icon(
                Icons.delete_forever,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Delete Account',
                style: AppTypography.bodyLarge.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Delete Account'),
                    content: const Text(
                      'Are you sure? This permanently deletes your account and all your data. '
                      'This cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor:
                              Theme.of(dialogContext).colorScheme.error,
                        ),
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('Delete Account'),
                      ),
                    ],
                  ),
                );

                if (confirmed != true || !context.mounted) return;

                final success = await context.read<AppState>().deleteAccount();
                if (!context.mounted) return;

                if (success) {
                  context.go(Routes.phoneEntry);
                  return;
                }

                final message = context.read<AppState>().error ??
                    'Failed to delete account. Please try again.';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message),
                    backgroundColor: AppColors.error,
                  ),
                );
              },
            ),
            const Divider(),
          ],

          // Logout
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title: Text(
              'Log Out',
              style: AppTypography.bodyLarge.copyWith(color: AppColors.error),
            ),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Log Out'),
                  content: const Text('Are you sure you want to log out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Log Out'),
                    ),
                  ],
                ),
              );

              if (confirmed == true && context.mounted) {
                await context.read<AppState>().logout();
                context.go(Routes.phoneEntry);
              }
            },
          ),

          const SizedBox(height: 32),

          // Version
          Center(
            child: Text(
              'Version 1.0.0',
              style: AppTypography.bodySmall,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: AppTypography.labelMedium.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
