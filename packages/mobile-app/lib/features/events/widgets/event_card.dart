import 'package:flutter/material.dart';
import 'package:industrynight_shared/shared.dart';
import '../../../shared/theme/app_theme.dart';

class EventCard extends StatelessWidget {
  final String eventId;
  final String name;
  final String venueName;
  final DateTime date;
  final String? imageUrl;
  final VoidCallback? onTap;

  const EventCard({
    super.key,
    required this.eventId,
    required this.name,
    required this.venueName,
    required this.date,
    this.imageUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image
            AspectRatio(
              aspectRatio: 16 / 9,
              child: imageUrl != null
                  ? Image.network(imageUrl!, fit: BoxFit.cover)
                  : Container(
                      color: AppColors.surfaceLight,
                      child: const Icon(
                        Icons.event,
                        size: 48,
                        color: AppColors.textSecondary,
                      ),
                    ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppTypography.titleLarge),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        venueName,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formatDate(date),
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
