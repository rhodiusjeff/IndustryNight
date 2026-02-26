import 'package:flutter/material.dart';
import 'package:industrynight_shared/shared.dart';
import '../theme/app_theme.dart';

/// Verification badge widget
class VerifiedBadge extends StatelessWidget {
  final VerificationStatus status;
  final double size;
  final bool showLabel;

  const VerifiedBadge({
    super.key,
    required this.status,
    this.size = 16,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    if (status == VerificationStatus.unverified) {
      return const SizedBox.shrink();
    }

    final icon = _getIcon();
    final color = _getColor();

    if (!showLabel) {
      return Icon(icon, size: size, color: color);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: size, color: color),
        const SizedBox(width: 4),
        Text(
          status.displayName,
          style: AppTypography.labelMedium.copyWith(color: color),
        ),
      ],
    );
  }

  IconData _getIcon() {
    switch (status) {
      case VerificationStatus.verified:
        return Icons.verified;
      case VerificationStatus.pending:
        return Icons.pending;
      case VerificationStatus.rejected:
        return Icons.cancel;
      case VerificationStatus.unverified:
        return Icons.help_outline;
    }
  }

  Color _getColor() {
    switch (status) {
      case VerificationStatus.verified:
        return AppColors.verified;
      case VerificationStatus.pending:
        return AppColors.pending;
      case VerificationStatus.rejected:
        return AppColors.error;
      case VerificationStatus.unverified:
        return AppColors.textTertiary;
    }
  }
}
