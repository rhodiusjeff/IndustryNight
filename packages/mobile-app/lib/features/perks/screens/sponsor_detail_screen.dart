import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../shared/theme/app_theme.dart';

class SponsorDetailScreen extends StatelessWidget {
  final String sponsorId;

  const SponsorDetailScreen({super.key, required this.sponsorId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Sponsor Name'),
              background: Container(
                color: AppColors.primary.withOpacity(0.2),
                child: const Center(
                  child: Icon(
                    Icons.store,
                    size: 64,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Description
                Text(
                  'Premium products and services for creative professionals. '
                  'Exclusive discounts for Industry Night members.',
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 24),

                // Discounts
                Text('Available Perks', style: AppTypography.titleLarge),
                const SizedBox(height: 12),

                _buildDiscountCard(
                  title: '20% Off All Services',
                  description: 'Valid for verified members only',
                  code: 'INDUSTRY20',
                  context: context,
                ),
                const SizedBox(height: 8),
                _buildDiscountCard(
                  title: 'Free Consultation',
                  description: 'First-time customers',
                  code: 'FREECONSULT',
                  context: context,
                ),

                const SizedBox(height: 24),

                // Contact
                Text('Contact', style: AppTypography.titleLarge),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.language),
                        title: const Text('Website'),
                        subtitle: const Text('www.sponsor.com'),
                        trailing: const Icon(Icons.open_in_new),
                        onTap: () {},
                      ),
                      ListTile(
                        leading: const Icon(Icons.location_on),
                        title: const Text('Location'),
                        subtitle: const Text('Los Angeles, CA'),
                        trailing: const Icon(Icons.directions),
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountCard({
    required String title,
    required String description,
    required String code,
    required BuildContext context,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTypography.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: AppTypography.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.local_offer,
                  color: AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    code,
                    style: AppTypography.labelLarge.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copied!')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
