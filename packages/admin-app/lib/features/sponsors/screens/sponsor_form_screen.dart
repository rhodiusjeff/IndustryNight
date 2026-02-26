import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:industrynight_shared/shared.dart';
import '../../../providers/admin_state.dart';

class SponsorFormScreen extends StatefulWidget {
  final String? sponsorId;
  final Sponsor? sponsor;

  const SponsorFormScreen({super.key, this.sponsorId, this.sponsor});

  @override
  State<SponsorFormScreen> createState() => _SponsorFormScreenState();
}

class _SponsorFormScreenState extends State<SponsorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _websiteController = TextEditingController();
  String _tier = 'bronze';
  bool _isActive = true;
  bool _isSubmitting = false;

  bool get isEditing => widget.sponsorId != null;

  @override
  void initState() {
    super.initState();
    if (widget.sponsor != null) {
      _nameController.text = widget.sponsor!.name;
      _descriptionController.text = widget.sponsor!.description ?? '';
      _websiteController.text = widget.sponsor!.website ?? '';
      _tier = widget.sponsor!.tier.name;
      _isActive = widget.sponsor!.isActive;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final adminApi = context.read<AdminState>().adminApi;
    final tier = SponsorTier.values.firstWhere((t) => t.name == _tier);

    try {
      if (isEditing) {
        await adminApi.updateSponsor(
          widget.sponsorId!,
          name: _nameController.text,
          description: _descriptionController.text.isNotEmpty
              ? _descriptionController.text
              : null,
          website: _websiteController.text.isNotEmpty
              ? _websiteController.text
              : null,
          tier: tier,
          isActive: _isActive,
        );
      } else {
        await adminApi.createSponsor(
          name: _nameController.text,
          description: _descriptionController.text.isNotEmpty
              ? _descriptionController.text
              : null,
          website: _websiteController.text.isNotEmpty
              ? _websiteController.text
              : null,
          tier: tier,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing ? 'Sponsor updated successfully' : 'Sponsor created successfully',
          ),
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : 'Failed to save sponsor'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Sponsor' : 'Add Sponsor'),
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
                    decoration: const InputDecoration(
                      labelText: 'Sponsor Name *',
                    ),
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
                    decoration: const InputDecoration(
                      labelText: 'Description',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _websiteController,
                    decoration: const InputDecoration(
                      labelText: 'Website',
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: _tier,
                    decoration: const InputDecoration(
                      labelText: 'Tier',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'bronze', child: Text('Bronze')),
                      DropdownMenuItem(value: 'silver', child: Text('Silver')),
                      DropdownMenuItem(value: 'gold', child: Text('Gold')),
                      DropdownMenuItem(value: 'platinum', child: Text('Platinum')),
                    ],
                    onChanged: (value) => setState(() => _tier = value!),
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
                        onPressed: _isSubmitting ? null : () => context.pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
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
    );
  }
}
