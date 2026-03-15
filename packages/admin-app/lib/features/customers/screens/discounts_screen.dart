import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:industrynight_shared/shared.dart';
import '../../../providers/admin_state.dart';

class DiscountsScreen extends StatefulWidget {
  final String customerId;

  const DiscountsScreen({super.key, required this.customerId});

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
    setState(() { _isLoading = true; _error = null; });

    final adminApi = context.read<AdminState>().adminApi;
    try {
      final discounts = await adminApi.getDiscounts(widget.customerId);
      if (!mounted) return;
      setState(() { _discounts = discounts; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Failed to load discounts';
        _isLoading = false;
      });
    }
  }

  void _showDiscountDialog({Discount? existing}) {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final valueController = TextEditingController(
      text: existing?.value != null ? existing!.value.toString() : '',
    );
    final codeController = TextEditingController(text: existing?.code ?? '');
    final descriptionController = TextEditingController(text: existing?.description ?? '');
    final termsController = TextEditingController(text: existing?.terms ?? '');
    String type = existing?.type.name ?? 'percentage';
    bool isActive = existing?.isActive ?? true;
    String? validationError;

    final isEditing = existing != null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Edit Discount' : 'Add Discount'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (validationError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        validationError!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Title *'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: DiscountType.values
                        .map((t) => DropdownMenuItem(
                              value: t.name,
                              child: Text(switch (t) {
                                DiscountType.percentage => 'Percentage',
                                DiscountType.fixedAmount => 'Fixed Amount',
                                DiscountType.freeItem => 'Free Item',
                                DiscountType.buyOneGetOne => 'Buy One Get One',
                                DiscountType.other => 'Other',
                              }),
                            ))
                        .toList(),
                    onChanged: (value) => setDialogState(() => type = value!),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: valueController,
                    decoration: InputDecoration(
                      labelText: 'Value',
                      hintText: type == 'percentage' ? 'e.g. 20 for 20%' : 'e.g. 50 for \$50',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: codeController,
                    decoration: const InputDecoration(labelText: 'Promo Code'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: termsController,
                    decoration: const InputDecoration(labelText: 'Terms & Conditions'),
                    maxLines: 2,
                  ),
                  if (isEditing) ...[
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Active'),
                      value: isActive,
                      onChanged: (v) => setDialogState(() => isActive = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) {
                  setDialogState(() => validationError = 'Title is required');
                  return;
                }
                if (valueController.text.isNotEmpty) {
                  final parsed = double.tryParse(valueController.text);
                  if (parsed == null || parsed < 0) {
                    setDialogState(() => validationError = 'Value must be a positive number');
                    return;
                  }
                }

                Navigator.of(ctx).pop();

                if (!mounted) return;
                final adminApi = context.read<AdminState>().adminApi;
                final discountType = DiscountType.values.firstWhere(
                  (t) => t.name == type,
                  orElse: () => DiscountType.percentage,
                );

                try {
                  if (isEditing) {
                    await adminApi.updateDiscount(
                      widget.customerId,
                      existing.id,
                      title: titleController.text.trim(),
                      description: descriptionController.text.trim().isNotEmpty
                          ? descriptionController.text.trim() : null,
                      type: discountType,
                      value: valueController.text.isNotEmpty
                          ? double.tryParse(valueController.text) : null,
                      code: codeController.text.trim().isNotEmpty
                          ? codeController.text.trim() : null,
                      terms: termsController.text.trim().isNotEmpty
                          ? termsController.text.trim() : null,
                      isActive: isActive,
                    );
                  } else {
                    await adminApi.createDiscount(
                      customerId: widget.customerId,
                      title: titleController.text.trim(),
                      description: descriptionController.text.trim().isNotEmpty
                          ? descriptionController.text.trim() : null,
                      type: discountType,
                      value: valueController.text.isNotEmpty
                          ? double.tryParse(valueController.text) : null,
                      code: codeController.text.trim().isNotEmpty
                          ? codeController.text.trim() : null,
                      terms: termsController.text.trim().isNotEmpty
                          ? termsController.text.trim() : null,
                    );
                  }
                  if (!mounted) return;
                  _loadDiscounts();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        e is ApiException ? e.message : 'Failed to save discount',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text(isEditing ? 'Update' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteDiscount(Discount discount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Discount'),
        content: Text('Delete "${discount.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final adminApi = context.read<AdminState>().adminApi;
    try {
      await adminApi.deleteDiscount(widget.customerId, discount.id);
      if (!mounted) return;
      _loadDiscounts();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : 'Failed to delete discount'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discounts'),
        actions: [
          ElevatedButton.icon(
            onPressed: () => _showDiscountDialog(),
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
    if (_isLoading) return const Center(child: CircularProgressIndicator());

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

    if (_discounts.isEmpty) return const Center(child: Text('No discounts yet'));

    return SingleChildScrollView(
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Title')),
          DataColumn(label: Text('Type')),
          DataColumn(label: Text('Value')),
          DataColumn(label: Text('Code')),
          DataColumn(label: Text('Redemptions')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Actions')),
        ],
        rows: _discounts.map((discount) => DataRow(
          cells: [
            DataCell(Text(discount.title)),
            DataCell(Text(switch (discount.type) {
              DiscountType.percentage => 'Percentage',
              DiscountType.fixedAmount => 'Fixed Amount',
              DiscountType.freeItem => 'Free Item',
              DiscountType.buyOneGetOne => 'BOGO',
              DiscountType.other => 'Other',
            })),
            DataCell(Text(discount.displayValue)),
            DataCell(Text(discount.code ?? '—')),
            DataCell(Text('${discount.redemptionCount ?? 0}')),
            DataCell(
              Chip(
                label: Text(discount.isActive ? 'Active' : 'Inactive'),
                backgroundColor: discount.isActive
                    ? Colors.green.shade100 : Colors.grey.shade200,
              ),
            ),
            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  tooltip: 'Edit',
                  onPressed: () => _showDiscountDialog(existing: discount),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  tooltip: 'Delete',
                  onPressed: () => _deleteDiscount(discount),
                ),
              ],
            )),
          ],
        )).toList(),
      ),
    );
  }
}
