import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:industrynight_shared/shared.dart';
import '../../../providers/admin_state.dart';
import '../../../shared/widgets/address_autocomplete_field.dart';

/// Used for both creating a new event and editing event metadata.
/// Pass [event] to enter edit mode; omit it for create mode.
class EventFormScreen extends StatefulWidget {
  final Event? event;

  const EventFormScreen({super.key, this.event});

  bool get isEditing => event != null;

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController        = TextEditingController();
  final _venueNameController   = TextEditingController();
  final _venueAddressController= TextEditingController();
  final _descriptionController = TextEditingController();
  final _capacityController    = TextEditingController();
  final _poshEventIdController = TextEditingController();
  final _poshEventUrlController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isSubmitting = false;

  String? _selectedMarketId;
  List<Market> _markets = [];
  bool _isLoadingMarkets = true;

  @override
  void initState() {
    super.initState();
    _loadMarkets();
    final e = widget.event;
    if (e != null) {
      _nameController.text         = e.name;
      _venueNameController.text    = e.venueName ?? '';
      _venueAddressController.text = e.venueAddress ?? '';
      _descriptionController.text  = e.description ?? '';
      _capacityController.text     = e.capacity?.toString() ?? '';
      _poshEventIdController.text  = e.poshEventId ?? '';
      _poshEventUrlController.text = e.poshEventUrl ?? '';
      _startDate = e.startTime;
      _endDate = e.endTime;
      _startTime = TimeOfDay.fromDateTime(e.startTime);
      _endTime   = TimeOfDay.fromDateTime(e.endTime);
      _selectedMarketId = e.marketId;
    }
  }

  Future<void> _loadMarkets() async {
    final adminApi = context.read<AdminState>().adminApi;
    try {
      final markets = await adminApi.getMarkets();
      if (!mounted) return;
      setState(() {
        _markets = markets.where((m) => m.isActive).toList();
        _isLoadingMarkets = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMarkets = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _venueNameController.dispose();
    _venueAddressController.dispose();
    _descriptionController.dispose();
    _capacityController.dispose();
    _poshEventIdController.dispose();
    _poshEventUrlController.dispose();
    super.dispose();
  }

  DateTime? _combineDateTime(DateTime? date, TimeOfDay? time) {
    if (date == null || time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  DateTime _clampDate(DateTime date, DateTime min, DateTime max) {
    if (date.isBefore(min)) return min;
    if (date.isAfter(max)) return max;
    return date;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final startDateTime = _combineDateTime(_startDate, _startTime);
    final endDateTime   = _combineDateTime(_endDate, _endTime);

    if (startDateTime == null || endDateTime == null) {
      _showError('Please select start and end dates/times');
      return;
    }
    if (!endDateTime.isAfter(startDateTime)) {
      _showError('End time must be after start time');
      return;
    }

    setState(() => _isSubmitting = true);
    final adminApi = context.read<AdminState>().adminApi;

    try {
      if (widget.isEditing) {
        await adminApi.updateEvent(
          widget.event!.id,
          name:         _nameController.text.trim(),
          venueName:    _venueNameController.text.trim().isNotEmpty ? _venueNameController.text.trim() : null,
          venueAddress: _venueAddressController.text.trim().isNotEmpty ? _venueAddressController.text.trim() : null,
          description:  _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
          capacity:     _capacityController.text.trim().isNotEmpty ? int.tryParse(_capacityController.text.trim()) : null,
          poshEventId:  _poshEventIdController.text.trim().isNotEmpty ? _poshEventIdController.text.trim() : null,
          poshEventUrl: _poshEventUrlController.text.trim().isNotEmpty ? _poshEventUrlController.text.trim() : null,
          startTime:    startDateTime,
          endTime:      endDateTime,
          marketId:     _selectedMarketId,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event updated')),
        );
        context.pop();
      } else {
        final created = await adminApi.createEvent(
          name:         _nameController.text.trim(),
          startTime:    startDateTime,
          endTime:      endDateTime,
          venueName:    _venueNameController.text.trim().isNotEmpty ? _venueNameController.text.trim() : null,
          venueAddress: _venueAddressController.text.trim().isNotEmpty ? _venueAddressController.text.trim() : null,
          description:  _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
          capacity:     _capacityController.text.trim().isNotEmpty ? int.tryParse(_capacityController.text.trim()) : null,
          poshEventId:  _poshEventIdController.text.trim().isNotEmpty ? _poshEventIdController.text.trim() : null,
          poshEventUrl: _poshEventUrlController.text.trim().isNotEmpty ? _poshEventUrlController.text.trim() : null,
          marketId:     _selectedMarketId,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event created — add images and publish when ready')),
        );
        context.pop(created.id);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showError(e is ApiException ? e.message : 'Failed to save event');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isEditing ? 'Edit Event' : 'Create Event';
    final submitLabel = widget.isEditing ? 'Save Changes' : 'Create Event';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Card(
            child: Container(
              width: 640,
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Event Details', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 24),

                    // Event name
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Event Name *'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Event name is required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Venue
                    TextFormField(
                      controller: _venueNameController,
                      decoration: const InputDecoration(labelText: 'Venue Name'),
                    ),
                    const SizedBox(height: 16),
                    AddressAutocompleteField(
                      controller: _venueAddressController,
                      decoration: const InputDecoration(labelText: 'Venue Address'),
                    ),
                    const SizedBox(height: 16),

                    // Market
                    if (_isLoadingMarkets)
                      const LinearProgressIndicator()
                    else
                      DropdownButtonFormField<String>(
                        initialValue: _selectedMarketId,
                        decoration: const InputDecoration(
                          labelText: 'Market',
                          helperText: 'Required before publishing',
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('— Not assigned —'),
                          ),
                          ..._markets.map((m) => DropdownMenuItem(
                                value: m.id,
                                child: Text(m.name),
                              )),
                        ],
                        onChanged: (value) => setState(() => _selectedMarketId = value),
                      ),
                    const SizedBox(height: 16),

                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(labelText: 'Description'),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 16),

                    // Date + times
                    Row(
                      children: [
                        Expanded(child: _DateTile(
                          label: 'Start Date *',
                          value: _startDate != null
                              ? DateFormat('MMM d, yyyy').format(_startDate!)
                              : null,
                          onTap: () async {
                            final now = DateTime.now();
                            final fallbackFirstDate = _dateOnly(now).subtract(const Duration(days: 1));
                            final lastDate = _dateOnly(now).add(const Duration(days: 730));
                            final firstDate = _startDate != null && _dateOnly(_startDate!).isBefore(fallbackFirstDate)
                                ? _dateOnly(_startDate!)
                                : fallbackFirstDate;
                            final initialDate = _clampDate(
                              _dateOnly(_startDate ?? now.add(const Duration(days: 7))),
                              firstDate,
                              lastDate,
                            );
                            final d = await showDatePicker(
                              context: context,
                              initialDate: initialDate,
                              firstDate: firstDate,
                              lastDate: lastDate,
                            );
                            if (d != null) {
                              setState(() {
                                _startDate = d;
                                _endDate ??= d;
                                if (_endDate!.isBefore(d)) {
                                  _endDate = d;
                                }
                              });
                            }
                          },
                        )),
                        const SizedBox(width: 16),
                        Expanded(child: _DateTile(
                          label: 'End Date *',
                          value: _endDate != null
                              ? DateFormat('MMM d, yyyy').format(_endDate!)
                              : null,
                          onTap: () async {
                            final now = DateTime.now();
                            final fallbackFirstDate = _dateOnly(now).subtract(const Duration(days: 1));
                            final lastDate = _dateOnly(now).add(const Duration(days: 730));
                            final firstDate = _startDate != null
                                ? _dateOnly(_startDate!)
                                : fallbackFirstDate;
                            final initialDate = _clampDate(
                              _dateOnly(_endDate ?? _startDate ?? now.add(const Duration(days: 7))),
                              firstDate,
                              lastDate,
                            );
                            final d = await showDatePicker(
                              context: context,
                              initialDate: initialDate,
                              firstDate: firstDate,
                              lastDate: lastDate,
                            );
                            if (d != null) setState(() => _endDate = d);
                          },
                        )),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _TimeTile(
                          label: 'Start Time *',
                          value: _startTime?.format(context),
                          onTap: () async {
                            final t = await showTimePicker(
                              context: context,
                              initialTime: _startTime ?? const TimeOfDay(hour: 19, minute: 0),
                            );
                            if (t != null) setState(() => _startTime = t);
                          },
                        )),
                        const SizedBox(width: 16),
                        Expanded(child: _TimeTile(
                          label: 'End Time *',
                          value: _endTime?.format(context),
                          onTap: () async {
                            final t = await showTimePicker(
                              context: context,
                              initialTime: _endTime ?? const TimeOfDay(hour: 23, minute: 0),
                            );
                            if (t != null) setState(() => _endTime = t);
                          },
                        )),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Capacity
                    TextFormField(
                      controller: _capacityController,
                      decoration: const InputDecoration(labelText: 'Capacity (optional)'),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v != null && v.trim().isNotEmpty && int.tryParse(v.trim()) == null) {
                          return 'Must be a number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Posh event ID
                    TextFormField(
                      controller: _poshEventIdController,
                      decoration: const InputDecoration(
                        labelText: 'Posh Event ID',
                        hintText: 'Find this in your Posh event URL',
                        helperText: 'Required before publishing. Used for webhook order matching.',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Posh event URL
                    TextFormField(
                      controller: _poshEventUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Posh Event URL',
                        hintText: 'https://posh.vip/e/your-event',
                        helperText: 'Optional canonical URL for reference and reconciliation.',
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Actions
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
                              : Text(submitLabel),
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

class _DateTile extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onTap;
  const _DateTile({required this.label, this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(value ?? 'Select date', style: value == null
            ? TextStyle(color: Theme.of(context).hintColor)
            : null),
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onTap;
  const _TimeTile({required this.label, this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.access_time, size: 18),
        ),
        child: Text(value ?? 'Select time', style: value == null
            ? TextStyle(color: Theme.of(context).hintColor)
            : null),
      ),
    );
  }
}
