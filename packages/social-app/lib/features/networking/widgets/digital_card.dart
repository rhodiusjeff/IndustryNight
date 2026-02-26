import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:industrynight_shared/shared.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/specialty_chip.dart';
import '../../../shared/widgets/verified_badge.dart';

/// Presentational widget showing a user's "digital card" with QR code.
class DigitalCard extends StatelessWidget {
  final User user;

  const DigitalCard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Profile photo
            CircleAvatar(
              radius: 36,
              backgroundImage: user.profilePhotoUrl != null
                  ? NetworkImage(user.profilePhotoUrl!)
                  : null,
              backgroundColor: AppColors.surfaceLight,
              child: user.profilePhotoUrl == null
                  ? Text(
                      getInitials(user.name),
                      style: AppTypography.headlineMedium,
                    )
                  : null,
            ),

            const SizedBox(height: 12),

            // Name + verified badge
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    user.name ?? 'Your Name',
                    style: AppTypography.titleLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                VerifiedBadge(status: user.verificationStatus, size: 18),
              ],
            ),

            const SizedBox(height: 8),

            // Specialty chips (max 3)
            if (user.specialties.isNotEmpty)
              SpecialtyChipList(
                specialties: user.specialties
                    .take(3)
                    .map((id) => Specialty.fromId(id)?.name ?? id)
                    .toList(),
                wrap: false,
              ),

            const SizedBox(height: 20),

            // QR Code
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: 'industrynight://connect/${user.id}',
                version: QrVersions.auto,
                size: 180,
                backgroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 16),

            Text(
              'Show this code to connect',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
