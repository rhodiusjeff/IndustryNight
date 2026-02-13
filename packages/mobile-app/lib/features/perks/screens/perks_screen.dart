import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/theme/app_theme.dart';

class PerksScreen extends StatelessWidget {
  const PerksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perks'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Featured perks
          Text('Featured', style: AppTypography.titleLarge),
          const SizedBox(height: 12),
          _buildFeaturedPerk(context),

          const SizedBox(height: 24),

          // All perks
          Text('All Sponsors', style: AppTypography.titleLarge),
          const SizedBox(height: 12),
          ...List.generate(5, (index) => _buildSponsorCard(context, index)),
        ],
      ),
    );
  }

  Widget _buildFeaturedPerk(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/perks/sponsor_featured'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 150,
              color: AppColors.primary.withOpacity(0.2),
              child: const Center(
                child: Icon(
                  Icons.local_offer,
                  size: 48,
                  color: AppColors.primary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sponsor Name', style: AppTypography.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    '20% off all services',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSponsorCard(BuildContext context, int index) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.surfaceLight,
          child: Text('S${index + 1}'),
        ),
        title: Text('Sponsor ${index + 1}'),
        subtitle: const Text('15% off for verified members'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/perks/sponsor_$index'),
      ),
    );
  }
}
