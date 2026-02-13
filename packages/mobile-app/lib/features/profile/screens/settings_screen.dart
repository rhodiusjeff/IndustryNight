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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Account section
          _buildSectionHeader('Account'),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Edit Profile'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.phone),
            title: const Text('Phone Number'),
            subtitle: Text(
              context.read<AppState>().currentUser?.phone ?? '',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
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
            value: false, // TODO: Get from settings
            onChanged: (value) {},
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
