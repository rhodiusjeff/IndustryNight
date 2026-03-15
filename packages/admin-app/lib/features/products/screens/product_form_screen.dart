import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:industrynight_shared/shared.dart';
import '../../../providers/admin_state.dart';

class ProductFormScreen extends StatefulWidget {
  final String? productId;
  final Product? product;

  const ProductFormScreen({super.key, this.productId, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();

  ProductType _productType = ProductType.sponsorship;
  bool _isStandard = true;
  bool _isActive = true;
  bool _isSubmitting = false;

  // Sponsorship config
  String _level = 'event';
  String _tier = 'bronze';

  // Vendor config
  String _vendorCategory = 'other';

  // Data product config
  String _format = 'pdf';
  String _scope = 'single_event';
  String _frequency = 'one_time';

  bool get isEditing => widget.productId != null;

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      final p = widget.product!;
      _nameController.text = p.name;
      _descriptionController.text = p.description ?? '';
      if (p.basePriceCents != null) {
        _priceController.text = (p.basePriceCents! / 100).toStringAsFixed(2);
      }
      _productType = p.productType;
      _isStandard = p.isStandard;
      _isActive = p.isActive;

      // Load config
      _level = p.level ?? 'event';
      _tier = p.tier ?? 'bronze';
      _vendorCategory = p.vendorCategory ?? 'other';
      _format = p.format ?? 'pdf';
      _scope = p.scope ?? 'single_event';
      _frequency = p.frequency ?? 'one_time';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildConfig() {
    switch (_productType) {
      case ProductType.sponsorship:
        return {'level': _level, 'tier': _tier};
      case ProductType.vendorSpace:
        return {'category': _vendorCategory};
      case ProductType.dataProduct:
        return {'format': _format, 'scope': _scope, 'frequency': _frequency};
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final adminApi = context.read<AdminState>().adminApi;
    final priceCents = _priceController.text.isNotEmpty
        ? (double.parse(_priceController.text) * 100).round()
        : null;

    try {
      if (isEditing) {
        await adminApi.updateProduct(
          widget.productId!,
          name: _nameController.text,
          description: _descriptionController.text.isNotEmpty
              ? _descriptionController.text : null,
          basePriceCents: priceCents,
          isStandard: _isStandard,
          config: _buildConfig(),
          isActive: _isActive,
        );
      } else {
        await adminApi.createProduct(
          productType: _productType,
          name: _nameController.text,
          description: _descriptionController.text.isNotEmpty
              ? _descriptionController.text : null,
          basePriceCents: priceCents,
          isStandard: _isStandard,
          config: _buildConfig(),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEditing ? 'Product updated' : 'Product created')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : 'Failed to save product'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Product' : 'Add Product'),
      ),
      body: Center(
        child: Card(
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Product Name *'),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(labelText: 'Description'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),

                    if (!isEditing)
                      DropdownButtonFormField<ProductType>(
                        initialValue: _productType,
                        decoration: const InputDecoration(labelText: 'Product Type'),
                        items: const [
                          DropdownMenuItem(value: ProductType.sponsorship, child: Text('Sponsorship')),
                          DropdownMenuItem(value: ProductType.vendorSpace, child: Text('Vendor Space')),
                          DropdownMenuItem(value: ProductType.dataProduct, child: Text('Data Product')),
                        ],
                        onChanged: (v) => setState(() => _productType = v!),
                      ),
                    if (!isEditing) const SizedBox(height: 16),

                    TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'Base Price (\$)',
                        hintText: 'Leave empty for quote-required',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.isEmpty) return null;
                        final parsed = double.tryParse(v);
                        if (parsed == null) return 'Enter a valid number';
                        if (parsed < 0) return 'Price cannot be negative';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Dynamic config based on type
                    ..._buildConfigFields(),

                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Standard Catalog Item'),
                      subtitle: const Text('Custom items are one-off deals'),
                      value: _isStandard,
                      onChanged: (v) => setState(() => _isStandard = v),
                    ),

                    if (isEditing)
                      SwitchListTile(
                        title: const Text('Active'),
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v),
                      ),

                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _isSubmitting ? null : () => context.pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _isSubmitting ? null : _submit,
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(isEditing ? 'Update' : 'Create'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildConfigFields() {
    switch (_productType) {
      case ProductType.sponsorship:
        return [
          DropdownButtonFormField<String>(
            initialValue: _level,
            decoration: const InputDecoration(labelText: 'Level'),
            items: const [
              DropdownMenuItem(value: 'platform', child: Text('Platform (Annual)')),
              DropdownMenuItem(value: 'event', child: Text('Event')),
            ],
            onChanged: (v) => setState(() => _level = v!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _tier,
            decoration: const InputDecoration(labelText: 'Tier'),
            items: const [
              DropdownMenuItem(value: 'bronze', child: Text('Bronze')),
              DropdownMenuItem(value: 'silver', child: Text('Silver')),
              DropdownMenuItem(value: 'gold', child: Text('Gold')),
              DropdownMenuItem(value: 'platinum', child: Text('Platinum')),
            ],
            onChanged: (v) => setState(() => _tier = v!),
          ),
        ];
      case ProductType.vendorSpace:
        return [
          DropdownButtonFormField<String>(
            initialValue: _vendorCategory,
            decoration: const InputDecoration(labelText: 'Category'),
            items: const [
              DropdownMenuItem(value: 'food', child: Text('Food')),
              DropdownMenuItem(value: 'beverage', child: Text('Beverage')),
              DropdownMenuItem(value: 'equipment', child: Text('Equipment')),
              DropdownMenuItem(value: 'service', child: Text('Service')),
              DropdownMenuItem(value: 'venue', child: Text('Venue')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (v) => setState(() => _vendorCategory = v!),
          ),
        ];
      case ProductType.dataProduct:
        return [
          DropdownButtonFormField<String>(
            initialValue: _format,
            decoration: const InputDecoration(labelText: 'Format'),
            items: const [
              DropdownMenuItem(value: 'pdf', child: Text('PDF Report')),
              DropdownMenuItem(value: 'dashboard', child: Text('Dashboard Access')),
              DropdownMenuItem(value: 'csv', child: Text('CSV Export')),
            ],
            onChanged: (v) => setState(() => _format = v!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _scope,
            decoration: const InputDecoration(labelText: 'Scope'),
            items: const [
              DropdownMenuItem(value: 'single_event', child: Text('Single Event')),
              DropdownMenuItem(value: 'all_events', child: Text('All Events')),
              DropdownMenuItem(value: 'custom', child: Text('Custom Scope')),
            ],
            onChanged: (v) => setState(() => _scope = v!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _frequency,
            decoration: const InputDecoration(labelText: 'Frequency'),
            items: const [
              DropdownMenuItem(value: 'one_time', child: Text('One-Time')),
              DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
              DropdownMenuItem(value: 'quarterly', child: Text('Quarterly')),
              DropdownMenuItem(value: 'ongoing', child: Text('Ongoing')),
            ],
            onChanged: (v) => setState(() => _frequency = v!),
          ),
        ];
    }
  }
}
