import 'package:flutter/material.dart';
import 'package:industrynight_shared/shared.dart';
import '../../../shared/theme/app_theme.dart';

class EventCard extends StatelessWidget {
  final Event event;
  final TicketStatus? ticketStatus;
  final VoidCallback? onTap;

  const EventCard({
    super.key,
    required this.event,
    this.ticketStatus,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = event.primaryImageUrl;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero image with optional ticket badge
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl != null
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder(),
                        )
                      : _placeholder(),
                  if (ticketStatus != null)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: _TicketBadge(status: ticketStatus!),
                    ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.name, style: AppTypography.titleLarge),
                  const SizedBox(height: 4),
                  if (event.venueName != null)
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.venueName!,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
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
                        formatEventDateTime(event.startTime, event.endTime),
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

  Widget _placeholder() {
    return Container(
      color: AppColors.surfaceLight,
      child: const Icon(
        Icons.event,
        size: 48,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _TicketBadge extends StatelessWidget {
  final TicketStatus status;

  const _TicketBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isCheckedIn = status == TicketStatus.checkedIn;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (isCheckedIn ? Colors.green : AppColors.primary).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCheckedIn ? Icons.check_circle : Icons.confirmation_number,
            size: 16,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            isCheckedIn ? 'Checked In' : 'Your Ticket',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
