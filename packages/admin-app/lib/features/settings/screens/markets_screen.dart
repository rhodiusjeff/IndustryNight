import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:industrynight_shared/shared.dart';
import '../../../providers/admin_state.dart';

class MarketsScreen extends StatefulWidget {
  const MarketsScreen({super.key});

  @override
  State<MarketsScreen> createState() => _MarketsScreenState();
}

class _MarketsScreenState extends State<MarketsScreen> {
  List<Market> _markets = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMarkets();
  }

  Future<void> _loadMarkets() async {
    setState(() { _isLoading = true; _error = null; });

    final adminApi = context.read<AdminState>().adminApi;
    try {
      final markets = await adminApi.getMarkets();
      if (!mounted) return;
      setState(() { _markets = markets; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Failed to load markets';
        _isLoading = false;
      });
    }
  }

  Future<void> _showMarketDialog({Market? market}) async {
    final isEditing = market != null;
    final nameController = TextEditingController(text: market?.name ?? '');
    final descriptionController = TextEditingController(text: market?.description ?? '');
    String? selectedTimezone = market?.timezone;
    final sortOrderController = TextEditingController(
      text: (market?.sortOrder ?? _markets.length).toString(),
    );
    String slugPreview = market?.slug ?? '';
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    final timezones = [
      'America/New_York',
      'America/Chicago',
      'America/Denver',
      'America/Los_Angeles',
      'America/Phoenix',
      'Pacific/Honolulu',
    ];

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isEditing ? 'Edit Market' : 'Create Market'),
            content: SizedBox(
              width: 400,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Name *'),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Name is required';
                          return null;
                        },
                        onChanged: (value) {
                          if (!isEditing) {
                            setDialogState(() {
                              slugPreview = value
                                  .toLowerCase()
                                  .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
                                  .replaceAll(RegExp(r'\s+'), '-')
                                  .replaceAll(RegExp(r'-+'), '-')
                                  .trim();
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: isEditing ? market.slug : null,
                        controller: isEditing ? null : null,
                        decoration: InputDecoration(
                          labelText: 'Slug',
                          hintText: isEditing ? null : slugPreview,
                          helperText: isEditing ? 'Slug cannot be changed' : 'Auto-generated from name',
                        ),
                        enabled: false,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      if (!isEditing && slugPreview.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Preview: $slugPreview',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: descriptionController,
                        decoration: const InputDecoration(labelText: 'Description'),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: selectedTimezone,
                        decoration: const InputDecoration(labelText: 'Timezone'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('None')),
                          ...timezones.map((tz) => DropdownMenuItem(
                            value: tz,
                            child: Text(tz.split('/').last.replaceAll('_', ' ')),
                          )),
                        ],
                        onChanged: (v) => setDialogState(() => selectedTimezone = v),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: sortOrderController,
                        decoration: const InputDecoration(labelText: 'Sort Order'),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.isEmpty) return null;
                          if (int.tryParse(v) == null) return 'Must be a number';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSubmitting ? null : () async {
                  if (!formKey.currentState!.validate()) return;
                  setDialogState(() => isSubmitting = true);

                  final adminApi = context.read<AdminState>().adminApi;
                  try {
                    if (isEditing) {
                      await adminApi.updateMarket(
                        market.id,
                        name: nameController.text,
                        description: descriptionController.text.isNotEmpty
                            ? descriptionController.text : null,
                        timezone: selectedTimezone,
                        sortOrder: int.tryParse(sortOrderController.text) ?? 0,
                      );
                    } else {
                      await adminApi.createMarket(
                        name: nameController.text,
                        description: descriptionController.text.isNotEmpty
                            ? descriptionController.text : null,
                        timezone: selectedTimezone,
                        sortOrder: int.tryParse(sortOrderController.text) ?? 0,
                      );
                    }
                    if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                  } catch (e) {
                    setDialogState(() => isSubmitting = false);
                    if (dialogContext.mounted) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                          content: Text(e is ApiException ? e.message : 'Failed to save market'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: isSubmitting
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isEditing ? 'Update' : 'Create'),
              ),
            ],
          );
        },
      ),
    );

    nameController.dispose();
    descriptionController.dispose();
    sortOrderController.dispose();

    if (result == true) {
      _loadMarkets();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEditing ? 'Market updated' : 'Market created')),
        );
      }
    }
  }

  Future<void> _toggleActive(Market market) async {
    final newActive = !market.isActive;
    final action = newActive ? 'Activate' : 'Retire';

    if (!newActive) {
      // Type-to-confirm retirement (GitHub-style)
      final eventCount = market.eventCount ?? 0;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          final confirmController = TextEditingController();
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              final typedMatch = confirmController.text == market.name;
              return AlertDialog(
                title: Text('Retire ${market.name}?'),
                content: SizedBox(
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Retiring ${market.name} will prevent new events from being assigned to this market.'
                        '${eventCount > 0 ? ' $eventCount existing event${eventCount == 1 ? '' : 's'} will keep their market association.' : ''}',
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Type '${market.name}' to confirm:",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: confirmController,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: market.name,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: typedMatch
                        ? () => Navigator.pop(dialogContext, true)
                        : null,
                    style: TextButton.styleFrom(foregroundColor: Colors.orange),
                    child: const Text('Retire'),
                  ),
                ],
              );
            },
          );
        },
      );
      if (confirmed != true) return;
    }

    final adminApi = context.read<AdminState>().adminApi;
    try {
      await adminApi.updateMarket(market.id, isActive: newActive);
      if (!mounted) return;
      _loadMarkets();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${market.name} ${action.toLowerCase()}d')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : 'Failed to $action market'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Markets'),
        actions: [
          ElevatedButton.icon(
            onPressed: () => _showMarketDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Add Market'),
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
              onPressed: _loadMarkets,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_markets.isEmpty) return const Center(child: Text('No markets yet'));

    return SingleChildScrollView(
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Name')),
          DataColumn(label: Text('Slug')),
          DataColumn(label: Text('Timezone')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Events'), numeric: true),
          DataColumn(label: Text('Actions')),
        ],
        rows: _markets.map((market) {
          final isRetired = !market.isActive;
          final textStyle = isRetired
              ? TextStyle(color: Colors.grey.shade500)
              : null;

          return DataRow(
            color: isRetired
                ? WidgetStateProperty.all(Colors.grey.shade100)
                : null,
            cells: [
              DataCell(Text(market.name, style: textStyle)),
              DataCell(Text(market.slug, style: textStyle)),
              DataCell(Text(
                market.timezone?.split('/').last.replaceAll('_', ' ') ?? '—',
                style: textStyle,
              )),
              DataCell(Chip(
                label: Text(isRetired ? 'Retired' : 'Active'),
                backgroundColor: isRetired
                    ? Colors.orange.shade100 : Colors.green.shade100,
                visualDensity: VisualDensity.compact,
              )),
              DataCell(Text(
                '${market.eventCount ?? 0}',
                style: textStyle,
              )),
              DataCell(Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    tooltip: 'Edit',
                    onPressed: () => _showMarketDialog(market: market),
                  ),
                  IconButton(
                    icon: Icon(
                      isRetired ? Icons.check_circle_outline : Icons.archive_outlined,
                      size: 18,
                    ),
                    tooltip: isRetired ? 'Activate' : 'Retire',
                    onPressed: () => _toggleActive(market),
                  ),
                ],
              )),
            ],
          );
        }).toList(),
      ),
    );
  }
}
