// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
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
  List<Sponsor> _allSponsors = [];
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
      final results = await Future.wait([
        adminApi.getEvent(widget.eventId),
        adminApi.getSponsors(limit: 200),
      ]);
      if (!mounted) return;
      setState(() {
        _event = results[0] as Event;
        _allSponsors = results[1] as List<Sponsor>;
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
          completer.complete((reader.result as ByteBuffer).asUint8List());
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

  Future<void> _addSponsor(String sponsorId) async {
    final adminApi = context.read<AdminState>().adminApi;
    try {
      await adminApi.addEventSponsor(widget.eventId, sponsorId);
      if (!mounted) return;
      await _reloadEvent();
    } catch (e) {
      if (!mounted) return;
      _showError(e is ApiException ? e.message : 'Failed to add sponsor');
    }
  }

  Future<void> _removeSponsor(String sponsorId) async {
    final adminApi = context.read<AdminState>().adminApi;
    try {
      await adminApi.removeEventSponsor(widget.eventId, sponsorId);
      if (!mounted) return;
      await _reloadEvent();
    } catch (e) {
      if (!mounted) return;
      _showError(e is ApiException ? e.message : 'Failed to remove sponsor');
    }
  }

  Future<void> _deleteEvent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Event'),
        content: const Text('Permanently delete this draft event? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
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
      context.go('/events');
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
    final addedSponsorIds = (e.sponsors ?? []).map((s) => s.id).toSet();
    final availableSponsors = _allSponsors
        .where((s) => !addedSponsorIds.contains(s.id))
        .toList();

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
            // Left column — info, images, sponsors, activation code
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
                  ),
                  const SizedBox(height: 16),
                  _SponsorsCard(
                    sponsors: e.sponsors ?? [],
                    availableSponsors: availableSponsors,
                    onAdd: _addSponsor,
                    onRemove: _removeSponsor,
                  ),
                  if (e.activationCode != null) ...[
                    const SizedBox(height: 16),
                    _ActivationCodeCard(code: e.activationCode!),
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

  const _ImagesCard({
    required this.images,
    required this.isUploading,
    required this.canUpload,
    required this.onUpload,
    required this.onDelete,
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
                    .map((img) => _ImageTile(image: img, onDelete: onDelete))
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

  const _ImageTile({required this.image, required this.onDelete});

  @override
  State<_ImageTile> createState() => _ImageTileState();
}

class _ImageTileState extends State<_ImageTile> {
  bool _hovering = false;

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
            if (_hovering)
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  icon: const Icon(Icons.delete, size: 18),
                  color: Colors.white,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    padding: const EdgeInsets.all(4),
                    minimumSize: const Size(28, 28),
                  ),
                  onPressed: () => widget.onDelete(widget.image.id),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Sponsors card
// ────────────────────────────────────────────────────────────

class _SponsorsCard extends StatelessWidget {
  final List<EventSponsor> sponsors;
  final List<Sponsor> availableSponsors;
  final void Function(String sponsorId) onAdd;
  final void Function(String sponsorId) onRemove;

  const _SponsorsCard({
    required this.sponsors,
    required this.availableSponsors,
    required this.onAdd,
    required this.onRemove,
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
                Text('Sponsors', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (availableSponsors.isNotEmpty)
                  PopupMenuButton<String>(
                    tooltip: 'Add sponsor',
                    icon: const Icon(Icons.add),
                    itemBuilder: (_) => availableSponsors
                        .map((s) => PopupMenuItem(
                              value: s.id,
                              child: Text(s.name),
                            ))
                        .toList(),
                    onSelected: onAdd,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (sponsors.isEmpty)
              Text(
                'No sponsors linked yet',
                style: TextStyle(color: Theme.of(context).hintColor),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: sponsors
                    .map((s) => Chip(
                          label: Text(s.name),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => onRemove(s.id),
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
            _StatRow('Checked In', '${event.attendeeCount}'),
            if (event.capacity != null) ...[
              _StatRow('Capacity', '${event.capacity}'),
              _StatRow(
                'Available',
                '${event.capacity! - event.attendeeCount}',
              ),
            ],
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
  final String code;

  const _ActivationCodeCard({required this.code});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Activation Code', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
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
          ],
        ),
      ),
    );
  }
}
