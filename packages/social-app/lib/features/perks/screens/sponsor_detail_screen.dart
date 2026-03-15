import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:industrynight_shared/shared.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../providers/app_state.dart';
import '../../../shared/theme/app_theme.dart';

class SponsorDetailScreen extends StatefulWidget {
  final String sponsorId;

  const SponsorDetailScreen({super.key, required this.sponsorId});

  @override
  State<SponsorDetailScreen> createState() => _SponsorDetailScreenState();
}

class _SponsorDetailScreenState extends State<SponsorDetailScreen> {
  Customer? _sponsor;
  bool _isLoading = true;
  String? _error;
  final Set<String> _redeemedIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });

    final perksApi = context.read<AppState>().perksApi;
    try {
      final sponsor = await perksApi.getSponsor(widget.sponsorId);
      if (!mounted) return;
      setState(() { _sponsor = sponsor; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Failed to load sponsor';
        _isLoading = false;
      });
    }
  }

  Future<void> _redeemDiscount(Discount discount) async {
    final perksApi = context.read<AppState>().perksApi;
    try {
      await perksApi.redeemDiscount(discount.id);
      if (!mounted) return;
      setState(() => _redeemedIds.add(discount.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marked as used!')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 409) {
        setState(() => _redeemedIds.add(discount.id));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, style: AppTypography.bodyMedium),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final sponsor = _sponsor!;
    final discounts = sponsor.discounts ?? [];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(sponsor.name),
              background: sponsor.logoUrl != null
                  ? Image.network(
                      sponsor.logoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholderBackground(),
                    )
                  : _placeholderBackground(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Description
                if (sponsor.description != null) ...[
                  Text(
                    sponsor.description!,
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Discounts
                if (discounts.isNotEmpty) ...[
                  Text('Available Perks', style: AppTypography.titleLarge),
                  const SizedBox(height: 12),
                  ...discounts.map((discount) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildDiscountCard(discount),
                      )),
                  const SizedBox(height: 16),
                ],

                if (discounts.isEmpty) ...[
                  Text('Available Perks', style: AppTypography.titleLarge),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'No perks available right now',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Contact info
                if (sponsor.website != null || sponsor.contactEmail != null) ...[
                  Text('Contact', style: AppTypography.titleLarge),
                  const SizedBox(height: 12),
                  Card(
                    child: Column(
                      children: [
                        if (sponsor.website != null)
                          ListTile(
                            leading: const Icon(Icons.language),
                            title: const Text('Website'),
                            subtitle: Text(sponsor.website!),
                            trailing: const Icon(Icons.open_in_new),
                            onTap: () => _launchUrl(sponsor.website!),
                          ),
                        if (sponsor.contactEmail != null)
                          ListTile(
                            leading: const Icon(Icons.email),
                            title: const Text('Email'),
                            subtitle: Text(sponsor.contactEmail!),
                            trailing: const Icon(Icons.open_in_new),
                            onTap: () => _launchUrl('mailto:${sponsor.contactEmail}'),
                          ),
                      ],
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderBackground() {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.2),
      child: const Center(
        child: Icon(Icons.store, size: 64, color: AppColors.primary),
      ),
    );
  }

  Widget _buildDiscountCard(Discount discount) {
    final isRedeemed = _redeemedIds.contains(discount.id);

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
                      Text(discount.title, style: AppTypography.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        discount.displayValue,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.local_offer, color: AppColors.primary),
              ],
            ),

            if (discount.terms != null) ...[
              const SizedBox(height: 8),
              Text(
                discount.terms!,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],

            if (discount.code != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      discount.code!,
                      style: AppTypography.labelLarge.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: discount.code!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copied!')),
                      );
                    },
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: isRedeemed
                  ? OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.check, color: AppColors.success),
                      label: const Text(
                        'Redeemed',
                        style: TextStyle(color: AppColors.success),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: () => _redeemDiscount(discount),
                      icon: const Icon(Icons.touch_app),
                      label: const Text('I Used This'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
