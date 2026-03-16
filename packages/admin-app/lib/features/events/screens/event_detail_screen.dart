// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:industrynight_shared/shared.dart';
import '../../../providers/admin_state.dart';

class EventDetailScreen extends StatefulWidget {
  final String eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  Event? _event;
  List<Customer> _allCustomers = [];
  List<Product> _allProducts = [];
  bool _isLoading = true;
  String? _error;
  bool _isUploadingImage = false;
  bool _isChangingStatus = false;

  final _dateFormat = DateFormat('MMMM d, yyyy');
  final _timeFormat = DateFormat('h:mm a');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final adminApi = context.read<AdminState>().adminApi;
    try {
      // Event data is required. Partner pick-list data is best-effort and
      // should not block loading the detail/edit experience.
      final event = await adminApi.getEvent(widget.eventId);

      final customersFuture = adminApi.getCustomers().catchError((_) => <Customer>[]);
      final productsFuture = adminApi.getProducts().catchError((_) => <Product>[]);
      final results = await Future.wait([customersFuture, productsFuture]);

      if (!mounted) return;
      setState(() {
        _event = event;
        _allCustomers = results[0] as List<Customer>;
        _allProducts = results[1] as List<Product>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Failed to load event';
        _isLoading = false;
      });
    }
  }

  Future<void> _reloadEvent() async {
    final adminApi = context.read<AdminState>().adminApi;
    try {
      final refreshed = await adminApi.getEvent(widget.eventId);
      if (!mounted) return;
      setState(() => _event = refreshed);
    } catch (_) {}
  }

  Future<void> _changeStatus(EventStatus status) async {
    setState(() => _isChangingStatus = true);
    final adminApi = context.read<AdminState>().adminApi;
    try {
      await adminApi.updateEvent(widget.eventId, status: status);
      if (!mounted) return;
      await _reloadEvent();
      if (!mounted) return;
      setState(() => _isChangingStatus = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Event status updated to ${status.name}')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isChangingStatus = false);
      _showError(e is ApiException ? e.message : 'Failed to update status');
    }
  }

  Future<void> _uploadImage() async {
    final bytes = await _pickImageBytes();
    if (bytes == null || !mounted) return;

    setState(() => _isUploadingImage = true);
    final adminApi = context.read<AdminState>().adminApi;
    try {
      await adminApi.uploadEventImage(
        widget.eventId,
        fileBytes: bytes,
        filename: 'upload.jpg', // backend normalizes to 800px JPEG
      );
      if (!mounted) return;
      await _reloadEvent();
      if (!mounted) return;
      setState(() => _isUploadingImage = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingImage = false);
      _showError(e is ApiException ? e.message : 'Upload failed');
    }
  }

  /// Opens the browser file picker and returns the selected image bytes,
  /// or null if the user cancelled. Uses dart:html directly because the
  /// file_picker package silently fails to open on Flutter Web.
  Future<Uint8List?> _pickImageBytes() async {
    final completer = Completer<Uint8List?>();

    final input = html.FileUploadInputElement()..accept = 'image/*';
    html.document.body!.children.add(input);

    // onChange fires when the user selects a file — this is the happy path.
    input.onChange.listen((_) {
      final files = input.files;
      if (files == null || files.isEmpty) {
        if (!completer.isCompleted) completer.complete(null);
        return;
      }
      final reader = html.FileReader()..readAsArrayBuffer(files[0]);
      reader.onLoad.listen((_) {
        if (!completer.isCompleted) {
          completer.complete(reader.result as Uint8List);
        }
      });
      reader.onError.listen((_) {
        if (!completer.isCompleted) completer.complete(null);
      });
    });

    // onFocus fires when the file dialog closes (cancel or selection). Use
    // a 1000ms delay so onChange always wins when a file was chosen — Chrome
    // fires focus before change in some versions.
    html.window.onFocus.first.then((_) {
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (!completer.isCompleted) completer.complete(null);
      });
    });

    input.click();
    final bytes = await completer.future;
    input.remove();
    return bytes;
  }

  Future<void> _setHeroImage(String imageId) async {
    final adminApi = context.read<AdminState>().adminApi;
    try {
      await adminApi.setHeroImage(widget.eventId, imageId);
      if (!mounted) return;
      await _reloadEvent();
    } catch (e) {
      if (!mounted) return;
      _showError(e is ApiException ? e.message : 'Failed to set hero image');
    }
  }

  Future<void> _deleteImage(String imageId) async {
    final adminApi = context.read<AdminState>().adminApi;
    try {
      await adminApi.deleteEventImage(widget.eventId, imageId);
      if (!mounted) return;
      await _reloadEvent();
    } catch (e) {
      if (!mounted) return;
      _showError(e is ApiException ? e.message : 'Delete failed');
    }
  }

  Future<void> _addPartner({
    required String customerId,
    required String productId,
    int? pricePaidCents,
  }) async {
    final adminApi = context.read<AdminState>().adminApi;
    try {
      await adminApi.addEventPartner(
        widget.eventId,
        customerId: customerId,
        productId: productId,
        pricePaidCents: pricePaidCents,
      );
      if (!mounted) return;
      await _reloadEvent();
    } catch (e) {
      if (!mounted) return;
      _showError(e is ApiException ? e.message : 'Failed to add partner');
    }
  }

  Future<void> _removePartner(String customerProductId) async {
    final adminApi = context.read<AdminState>().adminApi;
    try {
      await adminApi.removeEventPartner(widget.eventId, customerProductId);
      if (!mounted) return;
      await _reloadEvent();
    } catch (e) {
      if (!mounted) return;
      _showError(e is ApiException ? e.message : 'Failed to remove partner');
    }
  }

  Future<void> _deleteEvent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Event'),
        content: const Text('Permanently delete this draft event? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
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
      await adminApi.deleteEvent(widget.eventId);
      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (!mounted) return;
      _showError(e is ApiException ? e.message : 'Failed to delete event');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Event')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Event')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!),
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

    final e = _event!;

    return Scaffold(
      appBar: AppBar(
        title: Text(e.name),
        actions: [
          if (e.status == EventStatus.draft)
            TextButton.icon(
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: _deleteEvent,
            ),
          TextButton.icon(
            icon: const Icon(Icons.edit),
            label: const Text('Edit'),
            onPressed: () async {
              await context.push('/events/${widget.eventId}/edit', extra: e);
              _load();
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left column — info, images, partners, activation code
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  _InfoCard(
                    event: e,
                    dateFormat: _dateFormat,
                    timeFormat: _timeFormat,
                  ),
                  const SizedBox(height: 16),
                  _ImagesCard(
                    images: e.images ?? [],
                    isUploading: _isUploadingImage,
                    canUpload: (e.images?.length ?? 0) < 5,
                    onUpload: _uploadImage,
                    onDelete: _deleteImage,
                    onSetHero: _setHeroImage,
                  ),
                  const SizedBox(height: 16),
                  _PartnersCard(
                    partners: e.partners ?? [],
                    allCustomers: _allCustomers,
                    allProducts: _allProducts,
                    onAdd: _addPartner,
                    onRemove: _removePartner,
                  ),
                  if (e.activationCode != null) ...[
                    const SizedBox(height: 16),
                    _ActivationCodeCard(
                    eventId: e.id,
                    eventName: e.name,
                    code: e.activationCode!,
                  ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Right column — status actions, attendance
            Expanded(
              child: Column(
                children: [
                  _StatusCard(
                    event: e,
                    isChangingStatus: _isChangingStatus,
                    onChangeStatus: _changeStatus,
                  ),
                  const SizedBox(height: 16),
                  _AttendanceCard(event: e),
                  const SizedBox(height: 16),
                  _TicketsCard(
                    event: e,
                    onManage: () => context.push('/events/${widget.eventId}/tickets'),
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

// ────────────────────────────────────────────────────────────
// Info card
// ────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final Event event;
  final DateFormat dateFormat;
  final DateFormat timeFormat;

  const _InfoCard({
    required this.event,
    required this.dateFormat,
    required this.timeFormat,
  });

  @override
  Widget build(BuildContext context) {
    final e = event;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Event Details', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            _InfoRow(Icons.calendar_today, dateFormat.format(e.startTime)),
            _InfoRow(
              Icons.access_time,
              '${timeFormat.format(e.startTime)} – ${timeFormat.format(e.endTime)}',
            ),
            if (e.venueName != null || e.venueAddress != null)
              _InfoRow(
                Icons.location_on,
                [e.venueName, e.venueAddress].whereType<String>().join(', '),
              ),
            _InfoRow(
              Icons.map,
              'Market: ${e.marketName ?? 'Not assigned'}',
            ),
            if (e.capacity != null)
              _InfoRow(Icons.people, 'Capacity: ${e.capacity}'),
            if (e.poshEventId != null)
              _InfoRow(Icons.confirmation_number, 'Posh ID: ${e.poshEventId}'),
            if (e.description != null && e.description!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Description', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              Text(e.description!),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).hintColor),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Images card
// ────────────────────────────────────────────────────────────

class _ImagesCard extends StatelessWidget {
  final List<EventImage> images;
  final bool isUploading;
  final bool canUpload;
  final VoidCallback onUpload;
  final void Function(String imageId) onDelete;
  final void Function(String imageId) onSetHero;

  const _ImagesCard({
    required this.images,
    required this.isUploading,
    required this.canUpload,
    required this.onUpload,
    required this.onDelete,
    required this.onSetHero,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Images (${images.length}/5)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (canUpload)
                  ElevatedButton.icon(
                    onPressed: isUploading ? null : onUpload,
                    icon: isUploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload, size: 18),
                    label: const Text('Upload'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (images.isEmpty)
              Text(
                'No images yet. Upload at least 1 before publishing.',
                style: TextStyle(color: Theme.of(context).hintColor),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: images
                    .map((img) => _ImageTile(image: img, onDelete: onDelete, onSetHero: onSetHero))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _ImageTile extends StatefulWidget {
  final EventImage image;
  final void Function(String imageId) onDelete;
  final void Function(String imageId) onSetHero;

  const _ImageTile({required this.image, required this.onDelete, required this.onSetHero});

  @override
  State<_ImageTile> createState() => _ImageTileState();
}

class _ImageTileState extends State<_ImageTile> {
  bool _hovering = false;

  void _showImageDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  width: 400,
                  height: 300,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
                onPressed: () => Navigator.pop(dialogContext),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isHero = widget.image.sortOrder == 0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: SizedBox(
        width: 128,
        height: 96,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                widget.image.url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
            if (isHero)
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Text(
                    'HERO',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            if (_hovering) ...[
              Positioned(
                top: 4,
                right: 4,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility, size: 18),
                      color: Colors.white,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                        padding: const EdgeInsets.all(4),
                        minimumSize: const Size(28, 28),
                      ),
                      onPressed: () => _showImageDialog(context, widget.image.url),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 18),
                      color: Colors.white,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        padding: const EdgeInsets.all(4),
                        minimumSize: const Size(28, 28),
                      ),
                      onPressed: () => widget.onDelete(widget.image.id),
                    ),
                  ],
                ),
              ),
              if (!isHero)
                Positioned(
                  bottom: 4,
                  left: 4,
                  child: IconButton(
                    icon: const Icon(Icons.star_outline, size: 18),
                    tooltip: 'Set as hero image',
                    color: Colors.white,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      padding: const EdgeInsets.all(4),
                      minimumSize: const Size(28, 28),
                    ),
                    onPressed: () => widget.onSetHero(widget.image.id),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Partners card (sponsors + vendors for this event)
// ────────────────────────────────────────────────────────────

class _PartnersCard extends StatelessWidget {
  final List<EventPartner> partners;
  final List<Customer> allCustomers;
  final List<Product> allProducts;
  final void Function({
    required String customerId,
    required String productId,
    int? pricePaidCents,
  }) onAdd;
  final void Function(String customerProductId) onRemove;

  const _PartnersCard({
    required this.partners,
    required this.allCustomers,
    required this.allProducts,
    required this.onAdd,
    required this.onRemove,
  });

  void _showAddPartnerDialog(BuildContext context) {
    String? selectedCustomerId;
    String? selectedProductId;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final activeProducts = allProducts.where((p) => p.isActive).toList();

          return AlertDialog(
            title: const Text('Add Partner'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Customer *'),
                    items: allCustomers
                        .where((c) => c.isActive)
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            ))
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => selectedCustomerId = value),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Product *'),
                    items: activeProducts
                        .map((p) => DropdownMenuItem(
                              value: p.id,
                              child: Text('${p.name} (${p.productType.name})'),
                            ))
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => selectedProductId = value),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selectedCustomerId != null &&
                        selectedProductId != null
                    ? () {
                        Navigator.pop(dialogContext);
                        onAdd(
                          customerId: selectedCustomerId!,
                          productId: selectedProductId!,
                        );
                      }
                    : null,
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _typeColor(String? productType) {
    return switch (productType) {
      'sponsorship' => Colors.purple.shade100,
      'vendor_space' => Colors.blue.shade100,
      'data_product' => Colors.green.shade100,
      _ => Colors.grey.shade200,
    };
  }

  String _typeLabel(String? productType) {
    return switch (productType) {
      'sponsorship' => 'Sponsor',
      'vendor_space' => 'Vendor',
      'data_product' => 'Data',
      _ => productType ?? '',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Partners', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  tooltip: 'Add partner',
                  icon: const Icon(Icons.add),
                  onPressed: () => _showAddPartnerDialog(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (partners.isEmpty)
              Text(
                'No partners linked yet',
                style: TextStyle(color: Theme.of(context).hintColor),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: partners
                    .map((p) => Chip(
                          avatar: CircleAvatar(
                            backgroundColor: _typeColor(p.productType),
                            radius: 12,
                            child: Text(
                              _typeLabel(p.productType).substring(0, 1),
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                          label: Text('${p.name} — ${_typeLabel(p.productType)}'
                              '${p.tier != null ? ' (${p.tier})' : ''}'),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => onRemove(p.id),
                        ))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Status card
// ────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final Event event;
  final bool isChangingStatus;
  final void Function(EventStatus) onChangeStatus;

  const _StatusCard({
    required this.event,
    required this.isChangingStatus,
    required this.onChangeStatus,
  });

  Color _statusColor(EventStatus status) {
    switch (status) {
      case EventStatus.published:  return Colors.green.shade100;
      case EventStatus.draft:      return Colors.grey.shade200;
      case EventStatus.cancelled:  return Colors.red.shade100;
      case EventStatus.completed:  return Colors.blue.shade100;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = event.status;

    final List<Widget> actions;
    if (isChangingStatus) {
      actions = [const Center(child: CircularProgressIndicator())];
    } else {
      switch (status) {
        case EventStatus.draft:
          actions = [
            ElevatedButton.icon(
              onPressed: () => onChangeStatus(EventStatus.published),
              icon: const Icon(Icons.publish),
              label: const Text('Publish'),
            ),
          ];
          break;
        case EventStatus.published:
          actions = [
            ElevatedButton.icon(
              onPressed: () => onChangeStatus(EventStatus.completed),
              icon: const Icon(Icons.check_circle),
              label: const Text('Mark Complete'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => onChangeStatus(EventStatus.cancelled),
              icon: const Icon(Icons.cancel),
              label: const Text('Cancel Event'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            ),
          ];
          break;
        case EventStatus.cancelled:
        case EventStatus.completed:
          actions = [
            OutlinedButton.icon(
              onPressed: () => onChangeStatus(EventStatus.draft),
              icon: const Icon(Icons.replay),
              label: const Text('Reopen as Draft'),
            ),
          ];
          break;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Status', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Chip(
              label: Text(status.name),
              backgroundColor: _statusColor(status),
            ),
            if (event.poshEventId == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Posh Event ID required before publishing',
                  style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
                ),
              ),
            const SizedBox(height: 16),
            ...actions,
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Attendance card
// ────────────────────────────────────────────────────────────

class _AttendanceCard extends StatelessWidget {
  final Event event;

  const _AttendanceCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Attendance', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            _StatRow('Tickets Issued', '${event.ticketCount ?? 0}'),
            _StatRow('Purchased', '${event.ticketsPurchased ?? 0}'),
            _StatRow('Checked In', '${event.ticketsCheckedIn ?? event.attendeeCount}'),
            if (event.capacity != null) ...[
              const Divider(height: 16),
              _StatRow('Capacity', '${event.capacity}'),
              _StatRow(
                'Available',
                '${event.capacity! - (event.ticketsCheckedIn ?? event.attendeeCount)}',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Tickets summary card (counts + manage button)
// ────────────────────────────────────────────────────────────

class _TicketsCard extends StatelessWidget {
  final Event event;
  final VoidCallback onManage;

  const _TicketsCard({required this.event, required this.onManage});

  @override
  Widget build(BuildContext context) {
    final total = event.ticketCount ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Tickets', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (total == 0)
              Text(
                'No tickets issued yet',
                style: TextStyle(color: Colors.grey.shade600),
              )
            else
              Text('$total ticket${total == 1 ? '' : 's'} issued'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onManage,
              icon: const Icon(Icons.confirmation_number, size: 18),
              label: const Text('Manage Tickets'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Activation code card
// ────────────────────────────────────────────────────────────

class _ActivationCodeCard extends StatelessWidget {
  final String eventId;
  final String eventName;
  final String code;

  const _ActivationCodeCard({
    required this.eventId,
    required this.eventName,
    required this.code,
  });

  String get _qrData => 'industrynight://checkin/$eventId/$code';

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Activation Code',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.print, size: 18),
                  label: const Text('Print QR Code'),
                  onPressed: () => _printQrCode(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // QR Code
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data: _qrData,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Text code + copy button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    code,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontFamily: 'monospace',
                          letterSpacing: 4,
                        ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    tooltip: 'Copy code',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copied to clipboard')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Attendees scan this QR or enter the code to check in',
                style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _printQrCode(BuildContext context) {
    // Generate SVG from QR matrix for crisp print output
    final result = QrValidator.validate(
      data: _qrData,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
    );
    if (result.status != QrValidationStatus.valid || result.qrCode == null) {
      return;
    }
    final qrImage = QrImage(result.qrCode!);
    final moduleCount = qrImage.moduleCount;
    const svgSize = 400;
    final cellSize = svgSize / moduleCount;
    final svg = StringBuffer();
    svg.write('<svg xmlns="http://www.w3.org/2000/svg" '
        'width="$svgSize" height="$svgSize" viewBox="0 0 $svgSize $svgSize">');
    svg.write('<rect width="$svgSize" height="$svgSize" fill="white"/>');
    for (var y = 0; y < moduleCount; y++) {
      for (var x = 0; x < moduleCount; x++) {
        if (qrImage.isDark(y, x)) {
          final px = (x * cellSize).toStringAsFixed(2);
          final py = (y * cellSize).toStringAsFixed(2);
          final cs = cellSize.toStringAsFixed(2);
          svg.write(
              '<rect x="$px" y="$py" width="$cs" height="$cs" fill="black"/>');
        }
      }
    }
    svg.write('</svg>');

    final escapedName = eventName
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');

    final printHtml = '''<!DOCTYPE html>
<html>
<head>
<title>Check-In QR - $escapedName</title>
<style>
  @page { size: letter; margin: 0.5in; }
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    height: 100vh;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    text-align: center;
  }
  .qr { width: 5in; height: 5in; }
  .qr svg { width: 100%; height: 100%; }
  h1 { font-size: 2.5em; margin-top: 0.6em; color: #111; }
  .event-name { font-size: 1.3em; color: #555; margin-top: 0.3em; }
  .code {
    font-size: 1.8em;
    font-family: 'SF Mono', 'Fira Code', monospace;
    letter-spacing: 0.3em;
    color: #666;
    margin-top: 0.5em;
  }
</style>
</head>
<body onload="window.print()">
  <div class="qr">${svg.toString()}</div>
  <h1>Scan to Check In</h1>
  <p class="event-name">$escapedName</p>
  <p class="code">or enter code: $code</p>
</body>
</html>''';

    // Open print page via Blob URL — onload triggers print dialog
    final blob = html.Blob([printHtml], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, 'printQR');
  }
}
