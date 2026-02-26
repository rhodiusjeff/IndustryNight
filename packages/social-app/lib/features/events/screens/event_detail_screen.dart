import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/theme/app_theme.dart';

class EventDetailScreen extends StatelessWidget {
  final String eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Industry Night'),
              background: Container(
                color: AppColors.surfaceLight,
                child: const Icon(
                  Icons.event,
                  size: 80,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Date & Time
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Saturday, January 20, 2024'),
                    subtitle: const Text('7:00 PM - 11:00 PM'),
                  ),
                ),
                const SizedBox(height: 8),

                // Location
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.location_on),
                    title: const Text('The Grand Venue'),
                    subtitle: const Text('123 Main St, Los Angeles, CA'),
                    trailing: const Icon(Icons.directions),
                    onTap: () {
                      // Open maps
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Description
                Text('About', style: AppTypography.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Join us for an exclusive industry night event where creative professionals '
                  'come together to network, collaborate, and celebrate. Featuring live music, '
                  'refreshments, and opportunities to connect with like-minded individuals.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                // Check-in button
                ElevatedButton.icon(
                  onPressed: () => context.push('/events/$eventId/checkin'),
                  icon: const Icon(Icons.qr_code),
                  label: const Text('Check In'),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
