import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:industrynight_shared/shared.dart';
import '../../../providers/admin_state.dart';

class CustomerFormScreen extends StatefulWidget {
  final String? customerId;
  final Customer? customer;

  const CustomerFormScreen({super.key, this.customerId, this.customer});

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _websiteController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isActive = true;
  bool _isSubmitting = false;

  List<Market> _allMarkets = [];
  Set<String> _selectedMarketIds = {};
  bool _isLoadingMarkets = true;

  bool get isEditing => widget.customerId != null;

  @override
  void initState() {
    super.initState();
    if (widget.customer != null) {
      _nameController.text = widget.customer!.name;
      _descriptionController.text = widget.customer!.description ?? '';
      _websiteController.text = widget.customer!.website ?? '';
      _notesController.text = widget.customer!.notes ?? '';
      _isActive = widget.customer!.isActive;
      _selectedMarketIds = widget.customer!.markets
              ?.map((m) => m.id)
              .toSet() ??
          {};
    }
    _loadMarkets();
  }

  Future<void> _loadMarkets() async {
    try {
      final adminApi = context.read<AdminState>().adminApi;
      final markets = await adminApi.getMarkets();
      if (!mounted) return;
      setState(() {
        _allMarkets = markets.where((m) => m.isActive).toList();
        _isLoadingMarkets = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMarkets = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _websiteController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final adminApi = context.read<AdminState>().adminApi;

    try {
      if (isEditing) {
        await adminApi.updateCustomer(
          widget.customerId!,
          name: _nameController.text,
          description: _descriptionController.text.isNotEmpty
              ? _descriptionController.text : null,
          website: _websiteController.text.isNotEmpty
              ? _websiteController.text : null,
          notes: _notesController.text.isNotEmpty
              ? _notesController.text : null,
          isActive: _isActive,
          marketIds: _selectedMarketIds.toList(),
        );
      } else {
        await adminApi.createCustomer(
          name: _nameController.text,
          description: _descriptionController.text.isNotEmpty
              ? _descriptionController.text : null,
          website: _websiteController.text.isNotEmpty
              ? _websiteController.text : null,
          notes: _notesController.text.isNotEmpty
              ? _notesController.text : null,
          marketIds: _selectedMarketIds.toList(),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing ? 'Customer updated' : 'Customer created',
          ),
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : 'Failed to save customer'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Customer' : 'Add Customer'),
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
                      decoration: const InputDecoration(labelText: 'Business Name *'),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Name is required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(labelText: 'Description'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _websiteController,
                      decoration: const InputDecoration(
                        labelText: 'Website',
                        hintText: 'https://example.com',
                      ),
                      keyboardType: TextInputType.url,
                      validator: (v) {
                        if (v == null || v.isEmpty) return null;
                        final uri = Uri.tryParse(v);
                        if (uri == null || !uri.hasScheme || !uri.host.contains('.')) {
                          return 'Enter a valid URL (e.g. https://example.com)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Markets multi-select
                    if (_isLoadingMarkets)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: LinearProgressIndicator(),
                      )
                    else if (_allMarkets.isNotEmpty) ...[
                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Markets',
                          contentPadding: EdgeInsets.fromLTRB(12, 8, 12, 8),
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: _allMarkets.map((market) {
                            final selected = _selectedMarketIds.contains(market.id);
                            return FilterChip(
                              label: Text(market.name),
                              selected: selected,
                              onSelected: (value) {
                                setState(() {
                                  if (value) {
                                    _selectedMarketIds.add(market.id);
                                  } else {
                                    _selectedMarketIds.remove(market.id);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(labelText: 'Internal Notes'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),

                    if (isEditing)
                      SwitchListTile(
                        title: const Text('Active'),
                        value: _isActive,
                        onChanged: (value) => setState(() => _isActive = value),
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
}
