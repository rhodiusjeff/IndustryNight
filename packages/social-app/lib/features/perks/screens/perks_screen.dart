import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:industrynight_shared/shared.dart';
import '../../../providers/app_state.dart';
import '../../../shared/theme/app_theme.dart';

class PerksScreen extends StatefulWidget {
  const PerksScreen({super.key});

  @override
  State<PerksScreen> createState() => _PerksScreenState();
}

class _PerksScreenState extends State<PerksScreen> {
  List<Discount> _discounts = [];
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
      final discounts = await perksApi.getDiscounts();
      if (!mounted) return;
      setState(() { _discounts = discounts; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Failed to load perks';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perks'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
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
      );
    }

    if (_discounts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_offer, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text(
              'No perks available yet',
              style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _discounts.length,
        itemBuilder: (context, index) {
          final discount = _discounts[index];
          final isRedeemed = _redeemedIds.contains(discount.id);
          return _DiscountCard(
            discount: discount,
            isRedeemed: isRedeemed,
            onRedeem: () => _redeemDiscount(discount),
            onTapSponsor: () => context.push('/profile/perks/${discount.customerId}'),
          );
        },
      ),
    );
  }
}

class _DiscountCard extends StatelessWidget {
  final Discount discount;
  final bool isRedeemed;
  final VoidCallback onRedeem;
  final VoidCallback? onTapSponsor;

  const _DiscountCard({
    required this.discount,
    required this.isRedeemed,
    required this.onRedeem,
    this.onTapSponsor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sponsor name + discount title
            if (discount.customerName != null)
              GestureDetector(
                onTap: onTapSponsor,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.surfaceLight,
                      backgroundImage: discount.customerLogo != null
                          ? NetworkImage(discount.customerLogo!)
                          : null,
                      child: discount.customerLogo == null
                          ? Text(
                              discount.customerName!.substring(0, 1).toUpperCase(),
                              style: const TextStyle(fontSize: 12),
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      discount.customerName!,
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right,
                        size: 18, color: AppColors.textTertiary),
                  ],
                ),
              ),
            if (discount.customerName != null) const SizedBox(height: 12),

            // Discount details
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

            // Promo code
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

            // "I Used This" button
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: isRedeemed
                  ? OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.check, color: AppColors.success),
                      label: Text(
                        'Redeemed',
                        style: TextStyle(color: AppColors.success),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: onRedeem,
                      icon: const Icon(Icons.touch_app),
                      label: const Text('I Used This'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
