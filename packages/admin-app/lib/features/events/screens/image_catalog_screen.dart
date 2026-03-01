import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:industrynight_shared/shared.dart';
import '../../../providers/admin_state.dart';

class ImageCatalogScreen extends StatefulWidget {
  const ImageCatalogScreen({super.key});

  @override
  State<ImageCatalogScreen> createState() => _ImageCatalogScreenState();
}

class _ImageCatalogScreenState extends State<ImageCatalogScreen> {
  List<EventImage> _images = [];
  bool _isLoading = true;
  String? _error;
  final Set<String> _selectedIds = {};
  bool _isDeleting = false;

  final _dateFormat = DateFormat('MMM d, yyyy');

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final adminApi = context.read<AdminState>().adminApi;
    try {
      final images = await adminApi.getImages(limit: 200);
      if (!mounted) return;
      setState(() {
        _images = images;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Failed to load images';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteSelected() async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Images'),
        content: Text(
          'Delete $count image${count == 1 ? '' : 's'}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    final adminApi = context.read<AdminState>().adminApi;
    final toDelete = List<String>.from(_selectedIds);

    int failed = 0;
    for (final id in toDelete) {
      try {
        await adminApi.deleteImage(id);
      } catch (_) {
        failed++;
      }
    }

    if (!mounted) return;
    setState(() {
      _selectedIds.clear();
      _isDeleting = false;
    });

    if (failed > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted ${toDelete.length - failed} images; $failed failed'),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted $count image${count == 1 ? '' : 's'}')),
      );
    }

    await _loadImages();
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIds.length == _images.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(_images.map((i) => i.id));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Catalog'),
        actions: [
          if (_selectedIds.isNotEmpty) ...[
            Text(
              '${_selectedIds.length} selected',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: _isDeleting ? null : _deleteSelected,
              icon: _isDeleting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.delete, size: 18),
              label: const Text('Delete Selected'),
            ),
            const SizedBox(width: 8),
          ],
          if (_images.isNotEmpty)
            TextButton(
              onPressed: _selectAll,
              child: Text(
                _selectedIds.length == _images.length ? 'Deselect All' : 'Select All',
              ),
            ),
          const SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _buildContent(),
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
              onPressed: _loadImages,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_images.isEmpty) {
      return const Center(
        child: Text('No images uploaded yet.'),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemCount: _images.length,
      itemBuilder: (_, index) {
        final img = _images[index];
        final isSelected = _selectedIds.contains(img.id);
        return _CatalogTile(
          image: img,
          isSelected: isSelected,
          dateFormat: _dateFormat,
          onTap: () => _toggleSelection(img.id),
        );
      },
    );
  }
}

class _CatalogTile extends StatefulWidget {
  final EventImage image;
  final bool isSelected;
  final DateFormat dateFormat;
  final VoidCallback onTap;

  const _CatalogTile({
    required this.image,
    required this.isSelected,
    required this.dateFormat,
    required this.onTap,
  });

  @override
  State<_CatalogTile> createState() => _CatalogTileState();
}

class _CatalogTileState extends State<_CatalogTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isSelected
                  ? colorScheme.primary
                  : _hovering
                      ? colorScheme.outline
                      : Colors.transparent,
              width: widget.isSelected ? 3 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  widget.image.url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
                // Bottom label overlay
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    color: Colors.black54,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.image.eventName != null)
                          Text(
                            widget.image.eventName!,
                            style: const TextStyle(color: Colors.white, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          widget.dateFormat.format(widget.image.uploadedAt),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Selection checkbox
                if (widget.isSelected || _hovering)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.isSelected
                            ? colorScheme.primary
                            : Colors.black38,
                      ),
                      child: widget.isSelected
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : null,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
