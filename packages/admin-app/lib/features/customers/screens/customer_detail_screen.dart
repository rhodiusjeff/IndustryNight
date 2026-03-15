import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:industrynight_shared/shared.dart';
import '../../../providers/admin_state.dart';

// Web-only file reading
import 'dart:html' as html;

class CustomerDetailScreen extends StatefulWidget {
  final String customerId;

  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  Customer? _customer;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCustomer();
  }

  Future<void> _loadCustomer() async {
    setState(() { _isLoading = true; _error = null; });

    final adminApi = context.read<AdminState>().adminApi;
    try {
      final customer = await adminApi.getCustomer(widget.customerId);
      if (!mounted) return;
      setState(() { _customer = customer; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Failed to load customer';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteCustomer() async {
    final customer = _customer;
    if (customer == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Customer'),
        content: Text(
          'Permanently delete "${customer.name}" and all their products and discounts? This cannot be undone.',
        ),
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
      await adminApi.deleteCustomer(customer.id);
      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : 'Failed to delete customer'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null || _customer == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Customer')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? 'Customer not found'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadCustomer,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final customer = _customer!;

    return Scaffold(
      appBar: AppBar(
        title: Text(customer.name),
        actions: [
          ElevatedButton.icon(
            onPressed: () async {
              await context.push('/customers/${customer.id}/edit', extra: customer);
              if (!mounted) return;
              _loadCustomer();
            },
            icon: const Icon(Icons.edit),
            label: const Text('Edit'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () async {
              await context.push('/customers/${customer.id}/discounts');
              if (!mounted) return;
              _loadCustomer();
            },
            icon: const Icon(Icons.local_offer),
            label: const Text('Discounts'),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _deleteCustomer,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Delete'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left column: info + contacts
            SizedBox(
              width: 380,
              child: Column(
                children: [
                  _InfoCard(customer: customer),
                  const SizedBox(height: 24),
                  _ContactsCard(
                    contacts: customer.contacts ?? [],
                    customerId: customer.id,
                    onRefresh: _loadCustomer,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            // Right column: media + products + discounts
            Expanded(
              child: Column(
                children: [
                  _MediaCard(
                    media: customer.media ?? [],
                    customerId: customer.id,
                    onRefresh: _loadCustomer,
                  ),
                  const SizedBox(height: 24),
                  _ProductsCard(
                    products: customer.products ?? [],
                    customerId: customer.id,
                    onRefresh: _loadCustomer,
                  ),
                  const SizedBox(height: 24),
                  _DiscountsCard(
                    discounts: customer.discounts ?? [],
                    customerId: customer.id,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// INFO CARD
// ================================================================

class _InfoCard extends StatelessWidget {
  final Customer customer;
  const _InfoCard({required this.customer});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  child: Text(
                    customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(customer.name,
                          style: Theme.of(context).textTheme.titleLarge),
                      Chip(
                        label: Text(customer.isActive ? 'Active' : 'Inactive'),
                        backgroundColor: customer.isActive
                            ? Colors.green.shade100 : Colors.grey.shade200,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (customer.description != null) ...[
              const SizedBox(height: 16),
              Text(customer.description!),
            ],

            // Markets
            if (customer.markets != null && customer.markets!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Markets', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: customer.markets!.map((m) => Chip(
                  label: Text(m.name),
                  visualDensity: VisualDensity.compact,
                )).toList(),
              ),
            ],

            const Divider(height: 32),
            if (customer.website != null)
              _DetailRow('Website', customer.website!),
            if (customer.notes != null) ...[
              const SizedBox(height: 8),
              Text('Notes', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 4),
              Text(customer.notes!, style: const TextStyle(fontStyle: FontStyle.italic)),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: Theme.of(context).textTheme.labelSmall),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

// ================================================================
// CONTACTS CARD
// ================================================================

class _ContactsCard extends StatefulWidget {
  final List<CustomerContact> contacts;
  final String customerId;
  final VoidCallback onRefresh;

  const _ContactsCard({
    required this.contacts,
    required this.customerId,
    required this.onRefresh,
  });

  @override
  State<_ContactsCard> createState() => _ContactsCardState();
}

class _ContactsCardState extends State<_ContactsCard> {
  Future<void> _showContactDialog({CustomerContact? contact}) async {
    final nameController = TextEditingController(text: contact?.name ?? '');
    final emailController = TextEditingController(text: contact?.email ?? '');
    final phoneController = TextEditingController(text: contact?.phone ?? '');
    final titleController = TextEditingController(text: contact?.title ?? '');
    final notesController = TextEditingController(text: contact?.notes ?? '');
    ContactRole selectedRole = contact?.role ?? ContactRole.other;
    bool isPrimary = contact?.isPrimary ?? false;
    final isEditing = contact != null;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Edit Contact' : 'Add Contact'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Phone'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. Marketing Director'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ContactRole>(
                    decoration: const InputDecoration(labelText: 'Role'),
                    initialValue: selectedRole,
                    items: ContactRole.values.map((r) => DropdownMenuItem(
                      value: r,
                      child: Text(switch (r) {
                        ContactRole.primary => 'Primary',
                        ContactRole.billing => 'Billing',
                        ContactRole.decisionMaker => 'Decision Maker',
                        ContactRole.other => 'Other',
                      }),
                    )).toList(),
                    onChanged: (v) => setDialogState(() { if (v != null) selectedRole = v; }),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    title: const Text('Primary Contact'),
                    value: isPrimary,
                    onChanged: (v) => setDialogState(() => isPrimary = v ?? false),
                    contentPadding: EdgeInsets.zero,
                  ),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(labelText: 'Notes'),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: nameController.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: Text(isEditing ? 'Update' : 'Add'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    final adminApi = context.read<AdminState>().adminApi;
    try {
      if (isEditing) {
        await adminApi.updateContact(
          widget.customerId,
          contact.id,
          name: nameController.text.trim(),
          email: emailController.text.trim().isNotEmpty ? emailController.text.trim() : null,
          phone: phoneController.text.trim().isNotEmpty ? phoneController.text.trim() : null,
          role: selectedRole,
          title: titleController.text.trim().isNotEmpty ? titleController.text.trim() : null,
          isPrimary: isPrimary,
          notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
        );
      } else {
        await adminApi.addContact(
          widget.customerId,
          name: nameController.text.trim(),
          email: emailController.text.trim().isNotEmpty ? emailController.text.trim() : null,
          phone: phoneController.text.trim().isNotEmpty ? phoneController.text.trim() : null,
          role: selectedRole,
          title: titleController.text.trim().isNotEmpty ? titleController.text.trim() : null,
          isPrimary: isPrimary,
          notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
        );
      }
      widget.onRefresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : 'Failed to save contact'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteContact(CustomerContact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Contact'),
        content: Text('Remove "${contact.name}" from this customer?'),
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
      await adminApi.deleteContact(widget.customerId, contact.id);
      widget.onRefresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : 'Failed to delete contact'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Contacts', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _showContactDialog(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Contact'),
                ),
              ],
            ),
            const Divider(),
            if (widget.contacts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No contacts yet'),
              )
            else
              ...widget.contacts.map((c) => ListTile(
                leading: CircleAvatar(
                  radius: 18,
                  child: Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : '?'),
                ),
                title: Row(
                  children: [
                    Text(c.name),
                    if (c.isPrimary) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.star, size: 16, color: Colors.amber.shade700),
                    ],
                  ],
                ),
                subtitle: Text([
                  if (c.title != null) c.title!,
                  if (c.email != null) c.email!,
                  if (c.phone != null) c.phone!,
                ].join(' \u00b7 ')),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Chip(
                      label: Text(switch (c.role) {
                        ContactRole.primary => 'Primary',
                        ContactRole.billing => 'Billing',
                        ContactRole.decisionMaker => 'Decision Maker',
                        ContactRole.other => 'Other',
                      }),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      tooltip: 'Edit',
                      onPressed: () => _showContactDialog(contact: c),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      tooltip: 'Delete',
                      onPressed: () => _deleteContact(c),
                    ),
                  ],
                ),
              )),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// MEDIA CARD (brand assets)
// ================================================================

class _MediaCard extends StatefulWidget {
  final List<CustomerMediaItem> media;
  final String customerId;
  final VoidCallback onRefresh;

  const _MediaCard({
    required this.media,
    required this.customerId,
    required this.onRefresh,
  });

  @override
  State<_MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<_MediaCard> {
  bool _isUploading = false;

  Future<void> _uploadMedia() async {
    // Pick placement first
    String? placement = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Select Placement'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, 'logo'),
            child: const Text('Logo'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, 'app_banner'),
            child: const Text('App Banner'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, 'web_banner'),
            child: const Text('Web Banner'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, 'social_media'),
            child: const Text('Social Media'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, 'other'),
            child: const Text('Other'),
          ),
        ],
      ),
    );

    if (placement == null || !mounted) return;

    // Web file picker
    final uploadInput = html.FileUploadInputElement()..accept = 'image/*';
    uploadInput.click();

    await uploadInput.onChange.first;
    if (uploadInput.files == null || uploadInput.files!.isEmpty) return;

    final file = uploadInput.files!.first;
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoadEnd.first;

    if (!mounted) return;

    final bytes = reader.result as Uint8List;
    setState(() => _isUploading = true);

    final adminApi = context.read<AdminState>().adminApi;
    try {
      await adminApi.uploadCustomerMedia(
        widget.customerId,
        fileBytes: bytes,
        filename: file.name,
        placement: placement,
      );
      if (!mounted) return;
      setState(() => _isUploading = false);
      widget.onRefresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : 'Failed to upload media'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteMedia(CustomerMediaItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Media'),
        content: const Text('Delete this image? This cannot be undone.'),
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
      await adminApi.deleteCustomerMedia(widget.customerId, item.id);
      widget.onRefresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : 'Failed to delete media'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Brand Assets', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (_isUploading)
                  const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  ElevatedButton.icon(
                    onPressed: _uploadMedia,
                    icon: const Icon(Icons.upload, size: 18),
                    label: const Text('Upload'),
                  ),
              ],
            ),
            const Divider(),
            if (widget.media.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No brand assets yet'),
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: widget.media.map((item) => _MediaTile(
                  item: item,
                  onDelete: () => _deleteMedia(item),
                )).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  final CustomerMediaItem item;
  final VoidCallback onDelete;

  const _MediaTile({required this.item, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final placementLabel = switch (item.placement) {
      MediaPlacement.logo => 'Logo',
      MediaPlacement.appBanner => 'App Banner',
      MediaPlacement.webBanner => 'Web Banner',
      MediaPlacement.socialMedia => 'Social Media',
      MediaPlacement.other => 'Other',
    };

    return SizedBox(
      width: 160,
      child: Column(
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  item.url,
                  width: 160,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 160,
                    height: 120,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.broken_image),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  icon: Icon(Icons.delete, color: Colors.red.shade300, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    padding: const EdgeInsets.all(4),
                    minimumSize: const Size(28, 28),
                  ),
                  onPressed: onDelete,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(placementLabel, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

// ================================================================
// PRODUCTS CARD
// ================================================================

class _ProductsCard extends StatefulWidget {
  final List<CustomerProduct> products;
  final String customerId;
  final VoidCallback onRefresh;

  const _ProductsCard({
    required this.products,
    required this.customerId,
    required this.onRefresh,
  });

  @override
  State<_ProductsCard> createState() => _ProductsCardState();
}

class _ProductsCardState extends State<_ProductsCard> {
  void _showAddProductDialog() async {
    final adminApi = context.read<AdminState>().adminApi;

    List<Product> catalogProducts = [];
    List<Event> events = [];
    try {
      final results = await Future.wait([
        adminApi.getProducts(),
        adminApi.getEvents(),
      ]);
      catalogProducts = results[0] as List<Product>;
      events = results[1] as List<Event>;
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load products/events'), backgroundColor: Colors.red),
      );
      return;
    }

    if (!mounted) return;

    Product? selectedProduct;
    Event? selectedEvent;
    final priceController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Add Product'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<Product>(
                  decoration: const InputDecoration(labelText: 'Product *'),
                  items: catalogProducts
                      .where((p) => p.isActive)
                      .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                      .toList(),
                  onChanged: (v) => setDialogState(() {
                    selectedProduct = v;
                    if (v?.basePriceCents != null) {
                      priceController.text = (v!.basePriceCents! / 100).toStringAsFixed(2);
                    }
                  }),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<Event?>(
                  decoration: const InputDecoration(
                    labelText: 'Event (optional)',
                    hintText: 'For event-specific purchases',
                  ),
                  items: [
                    const DropdownMenuItem<Event?>(value: null, child: Text('\u2014 None \u2014')),
                    ...events.map((e) => DropdownMenuItem<Event?>(value: e, child: Text(e.name))),
                  ],
                  onChanged: (v) => setDialogState(() => selectedEvent = v),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(
                    labelText: 'Price Paid (\$)',
                    hintText: 'Leave empty if TBD',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedProduct == null
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || selectedProduct == null || !mounted) return;

    final priceCents = priceController.text.isNotEmpty
        ? ((double.tryParse(priceController.text) ?? 0) * 100).round()
        : null;

    try {
      await adminApi.addCustomerProduct(
        widget.customerId,
        productId: selectedProduct!.id,
        eventId: selectedEvent?.id,
        pricePaidCents: priceCents,
      );
      widget.onRefresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : 'Failed to add product'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _removeProduct(CustomerProduct cp) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Product'),
        content: Text('Remove "${cp.productName}" from this customer?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final adminApi = context.read<AdminState>().adminApi;
    try {
      await adminApi.removeCustomerProduct(widget.customerId, cp.id);
      widget.onRefresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : 'Failed to remove product'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Products',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Text('${widget.products.length} purchased',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _showAddProductDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Product'),
                ),
              ],
            ),
            const Divider(),
            if (widget.products.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No products yet'),
              )
            else
              DataTable(
                columns: const [
                  DataColumn(label: Text('Product')),
                  DataColumn(label: Text('Type')),
                  DataColumn(label: Text('Event')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Price')),
                  DataColumn(label: Text('')),
                ],
                rows: widget.products.map((cp) {
                  final typeLabel = switch (cp.productType) {
                    'sponsorship' => 'Sponsor',
                    'vendor_space' => 'Vendor',
                    'data_product' => 'Data',
                    _ => cp.productType ?? '\u2014',
                  };
                  return DataRow(cells: [
                    DataCell(Text(cp.productName ?? '\u2014')),
                    DataCell(Text(typeLabel)),
                    DataCell(Text(cp.eventName ?? '\u2014')),
                    DataCell(Chip(
                      label: Text(cp.status.name),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: cp.status == CustomerProductStatus.active
                          ? Colors.green.shade100 : Colors.grey.shade200,
                    )),
                    DataCell(Text(cp.displayPrice)),
                    DataCell(IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      tooltip: 'Remove',
                      onPressed: () => _removeProduct(cp),
                    )),
                  ]);
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// DISCOUNTS CARD
// ================================================================

class _DiscountsCard extends StatelessWidget {
  final List<Discount> discounts;
  final String customerId;

  const _DiscountsCard({
    required this.discounts,
    required this.customerId,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Discounts / Perks',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => context.push('/customers/$customerId/discounts'),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Manage'),
                ),
              ],
            ),
            const Divider(),
            if (discounts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No discounts yet'),
              )
            else
              DataTable(
                columns: const [
                  DataColumn(label: Text('Title')),
                  DataColumn(label: Text('Value')),
                  DataColumn(label: Text('Code')),
                  DataColumn(label: Text('Redemptions')),
                  DataColumn(label: Text('Status')),
                ],
                rows: discounts.map((d) => DataRow(cells: [
                  DataCell(Text(d.title)),
                  DataCell(Text(d.displayValue)),
                  DataCell(Text(d.code ?? '\u2014')),
                  DataCell(Text('${d.redemptionCount ?? 0}')),
                  DataCell(Chip(
                    label: Text(d.isActive ? 'Active' : 'Inactive'),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: d.isActive
                        ? Colors.green.shade100 : Colors.grey.shade200,
                  )),
                ])).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
