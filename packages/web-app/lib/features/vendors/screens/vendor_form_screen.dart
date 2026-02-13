import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class VendorFormScreen extends StatefulWidget {
  final String? vendorId;

  const VendorFormScreen({super.key, this.vendorId});

  @override
  State<VendorFormScreen> createState() => _VendorFormScreenState();
}

class _VendorFormScreenState extends State<VendorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _websiteController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  String _category = 'other';
  bool _isActive = true;

  bool get isEditing => widget.vendorId != null;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _websiteController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // TODO: Implement API call

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing ? 'Vendor updated successfully' : 'Vendor created successfully',
          ),
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Vendor' : 'Add Vendor'),
      ),
      body: Center(
        child: Card(
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Vendor Name *'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Name is required';
                      }
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

                  DropdownButtonFormField<String>(
                    value: _category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: const [
                      DropdownMenuItem(value: 'food', child: Text('Food')),
                      DropdownMenuItem(value: 'beverage', child: Text('Beverage')),
                      DropdownMenuItem(value: 'equipment', child: Text('Equipment')),
                      DropdownMenuItem(value: 'service', child: Text('Service')),
                      DropdownMenuItem(value: 'venue', child: Text('Venue')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (value) => setState(() => _category = value!),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _websiteController,
                    decoration: const InputDecoration(labelText: 'Website'),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Contact Email'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(labelText: 'Contact Phone'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),

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
                        onPressed: () => context.pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _submit,
                        child: Text(isEditing ? 'Update' : 'Create'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
