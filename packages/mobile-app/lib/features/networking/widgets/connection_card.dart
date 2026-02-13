import 'package:flutter/material.dart';
import 'package:industrynight_shared/shared.dart';
import '../../../shared/theme/app_theme.dart';

class ConnectionCard extends StatelessWidget {
  final String userId;
  final String name;
  final String? specialty;
  final String? imageUrl;
  final VoidCallback? onTap;

  const ConnectionCard({
    super.key,
    required this.userId,
    required this.name,
    this.specialty,
    this.imageUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: imageUrl != null ? NetworkImage(imageUrl!) : null,
        backgroundColor: AppColors.surfaceLight,
        child: imageUrl == null
            ? Text(
                getInitials(name),
                style: AppTypography.labelLarge,
              )
            : null,
      ),
      title: Text(name),
      subtitle: specialty != null
          ? Text(
              specialty!,
              style: AppTypography.bodySmall,
            )
          : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
