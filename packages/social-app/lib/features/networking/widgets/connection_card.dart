import 'package:flutter/material.dart';
import 'package:industrynight_shared/shared.dart';
import '../../../shared/theme/app_theme.dart';

class ConnectionCard extends StatelessWidget {
  final Connection connection;
  final String currentUserId;
  final VoidCallback? onTap;

  const ConnectionCard({
    super.key,
    required this.connection,
    required this.currentUserId,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final otherUser = connection.getOtherUser(currentUserId);
    final name = otherUser?.name ?? 'Unknown';
    final imageUrl = otherUser?.profilePhotoUrl;
    final specialties = otherUser?.specialties ?? [];
    final specialtyDisplay = specialties
        .take(2)
        .map((id) => Specialty.fromId(id)?.name ?? id)
        .join(' · ');

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
        backgroundColor: AppColors.surfaceLight,
        child: imageUrl == null
            ? Text(
                getInitials(name),
                style: AppTypography.labelLarge,
              )
            : null,
      ),
      title: Text(name),
      subtitle: specialtyDisplay.isNotEmpty
          ? Text(
              specialtyDisplay,
              style: AppTypography.bodySmall,
            )
          : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
