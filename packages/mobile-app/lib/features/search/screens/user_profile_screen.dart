import 'package:flutter/material.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/specialty_chip.dart';
import '../../../shared/widgets/verified_badge.dart';
import 'package:industrynight_shared/shared.dart';

class UserProfileScreen extends StatelessWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile header
            const CircleAvatar(
              radius: 50,
              backgroundColor: AppColors.surfaceLight,
              child: Icon(Icons.person, size: 50),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('User Name', style: AppTypography.headlineMedium),
                const SizedBox(width: 4),
                const VerifiedBadge(
                  status: VerificationStatus.verified,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 8),
            const SpecialtyChipList(
              specialties: ['Photographer', 'Videographer'],
              wrap: false,
            ),
            const SizedBox(height: 16),
            Text(
              'Los Angeles based photographer and videographer. Available for bookings.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            // Social links
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.camera_alt),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.link),
                  onPressed: () {},
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Connect button
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.person_add),
              label: const Text('Connect'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),

            const SizedBox(height: 32),

            // Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStat('Events', '12'),
                _buildStat('Connections', '156'),
                _buildStat('Posts', '24'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: AppTypography.headlineMedium),
        Text(
          label,
          style: AppTypography.bodySmall,
        ),
      ],
    );
  }
}
