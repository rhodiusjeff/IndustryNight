import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:industrynight_shared/shared.dart';
import '../../../providers/admin_state.dart';

class DiscountsScreen extends StatefulWidget {
  final String sponsorId;

  const DiscountsScreen({super.key, required this.sponsorId});

  @override
  State<DiscountsScreen> createState() => _DiscountsScreenState();
}

class _DiscountsScreenState extends State<DiscountsScreen> {
  List<Discount> _discounts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDiscounts();
  }

  Future<void> _loadDiscounts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final adminApi = context.read<AdminState>().adminApi;
    try {
      final discounts = await adminApi.getDiscounts(widget.sponsorId);
      if (!mounted) return;
      setState(() {
        _discounts = discounts;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Failed to load discounts';
        _isLoading = false;
      });
    }
  }

  void _showAddDiscountDialog() {
    final titleController = TextEditingController();
    final valueController = TextEditingController();
    final codeController = TextEditingController();
    String type = 'percentage';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Discount'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title *'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: 'percentage', child: Text('Percentage')),
                    DropdownMenuItem(value: 'fixedAmount', child: Text('Fixed Amount')),
                    DropdownMenuItem(value: 'freeItem', child: Text('Free Item')),
                    DropdownMenuItem(value: 'buyOneGetOne', child: Text('Buy One Get One')),
                  ],
                  onChanged: (value) => setDialogState(() => type = value!),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: valueController,
                  decoration: const InputDecoration(labelText: 'Value'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(labelText: 'Promo Code'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty) return;

                Navigator.of(ctx).pop();

                final adminApi = context.read<AdminState>().adminApi;
                final discountType = DiscountType.values.firstWhere(
                  (t) => t.name == type,
                  orElse: () => DiscountType.percentage,
                );

                try {
                  await adminApi.createDiscount(
                    sponsorId: widget.sponsorId,
                    title: titleController.text,
                    type: discountType,
                    value: valueController.text.isNotEmpty
                        ? double.tryParse(valueController.text)
                        : null,
                    code: codeController.text.isNotEmpty
                        ? codeController.text
                        : null,
                  );
                  _loadDiscounts();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        e is ApiException ? e.message : 'Failed to create discount',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Discounts — Sponsor ${widget.sponsorId.substring(0, 8)}...'),
        actions: [
          ElevatedButton.icon(
            onPressed: _showAddDiscountDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Discount'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(child: _buildContent()),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadDiscounts,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_discounts.isEmpty) {
      return const Center(child: Text('No discounts yet'));
    }

    return SingleChildScrollView(
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Title')),
          DataColumn(label: Text('Type')),
          DataColumn(label: Text('Value')),
          DataColumn(label: Text('Code')),
          DataColumn(label: Text('Status')),
        ],
        rows: _discounts.map((discount) => DataRow(
          cells: [
            DataCell(Text(discount.title)),
            DataCell(Text(discount.type.name)),
            DataCell(Text(discount.displayValue)),
            DataCell(Text(discount.code ?? '—')),
            DataCell(
              Chip(
                label: Text(discount.isActive ? 'Active' : 'Inactive'),
                backgroundColor: discount.isActive
                    ? Colors.green.shade100
                    : Colors.grey.shade200,
              ),
            ),
          ],
        )).toList(),
      ),
    );
  }
}
