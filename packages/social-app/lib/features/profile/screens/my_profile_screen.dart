import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:industrynight_shared/shared.dart';
import '../../../providers/app_state.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/specialty_chip.dart';
import '../../../shared/widgets/verified_badge.dart';

class MyProfileScreen extends StatelessWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/profile/settings'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile photo
            Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage: user?.profilePhotoUrl != null
                      ? NetworkImage(user!.profilePhotoUrl!)
                      : null,
                  backgroundColor: AppColors.surfaceLight,
                  child: user?.profilePhotoUrl == null
                      ? Text(
                          getInitials(user?.name),
                          style: AppTypography.headlineLarge,
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primary,
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt, size: 16),
                      onPressed: () => context.push('/profile/edit'),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Name and verification
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  user?.name ?? 'Your Name',
                  style: AppTypography.headlineMedium,
                ),
                if (user != null) ...[
                  const SizedBox(width: 4),
                  VerifiedBadge(
                    status: user.verificationStatus,
                    size: 20,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // Specialties
            if (user?.specialties.isNotEmpty ?? false)
              SpecialtyChipList(
                specialties: user!.specialties
                    .map((id) => Specialty.fromId(id)?.name ?? id)
                    .toList(),
                wrap: false,
              ),

            const SizedBox(height: 16),

            // Bio
            if (user?.bio != null)
              Text(
                user!.bio!,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),

            const SizedBox(height: 24),

            // Edit profile button
            OutlinedButton(
              onPressed: () => context.push('/profile/edit'),
              child: const Text('Edit Profile'),
            ),

            const SizedBox(height: 32),

            // Verification card (if not verified)
            if (user?.verificationStatus != VerificationStatus.verified)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.verified_user,
                        size: 40,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Get Verified',
                        style: AppTypography.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Verify your industry status to unlock exclusive perks',
                        style: AppTypography.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          // TODO: Navigate to verification
                        },
                        child: const Text('Start Verification'),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Menu items
            _buildMenuItem(
              context,
              icon: Icons.event,
              title: 'My Events',
              onTap: () {},
            ),
            _buildMenuItem(
              context,
              icon: Icons.people,
              title: 'My Connections',
              onTap: () => context.go('/network'),
            ),
            _buildMenuItem(
              context,
              icon: Icons.local_offer,
              title: 'Perks & Discounts',
              onTap: () => context.push('/profile/perks'),
            ),
            _buildMenuItem(
              context,
              icon: Icons.bookmark,
              title: 'Saved Posts',
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
