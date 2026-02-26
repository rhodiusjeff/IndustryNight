import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:industrynight_shared/shared.dart';
import '../../../config/routes.dart';
import '../../../providers/admin_state.dart';

class EventsListScreen extends StatefulWidget {
  const EventsListScreen({super.key});

  @override
  State<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends State<EventsListScreen> {
  List<Event> _events = [];
  bool _isLoading = true;
  String? _error;
  EventStatus? _statusFilter;

  final _dateFormat = DateFormat('MMM d, yyyy');

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final adminApi = context.read<AdminState>().adminApi;
    try {
      final events = await adminApi.getEvents(status: _statusFilter);
      if (!mounted) return;
      setState(() {
        _events = events;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Failed to load events';
        _isLoading = false;
      });
    }
  }

  Color _statusColor(EventStatus status) {
    switch (status) {
      case EventStatus.published:
        return Colors.green.shade100;
      case EventStatus.draft:
        return Colors.grey.shade200;
      case EventStatus.cancelled:
        return Colors.red.shade100;
      case EventStatus.completed:
        return Colors.blue.shade100;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        actions: [
          ElevatedButton.icon(
            onPressed: () => context.push(AdminRoutes.createEvent),
            icon: const Icon(Icons.add),
            label: const Text('Create Event'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Spacer(),
                    DropdownButton<String>(
                      value: _statusFilter?.name ?? 'all',
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All')),
                        DropdownMenuItem(value: 'published', child: Text('Published')),
                        DropdownMenuItem(value: 'draft', child: Text('Draft')),
                        DropdownMenuItem(value: 'completed', child: Text('Completed')),
                        DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _statusFilter = value == 'all'
                              ? null
                              : EventStatus.values.firstWhere((s) => s.name == value);
                        });
                        _loadEvents();
                      },
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
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
              onPressed: _loadEvents,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_events.isEmpty) {
      return const Center(child: Text('No events found'));
    }

    return SingleChildScrollView(
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Event')),
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Venue')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Attendees')),
          DataColumn(label: Text('Actions')),
        ],
        rows: _events.map((event) => DataRow(
          cells: [
            DataCell(Text(event.name)),
            DataCell(Text(_dateFormat.format(event.startTime))),
            DataCell(Text(event.venueName ?? '—')),
            DataCell(
              Chip(
                label: Text(event.status.name),
                backgroundColor: _statusColor(event.status),
              ),
            ),
            DataCell(Text('${event.attendeeCount}')),
            DataCell(
              IconButton(
                icon: const Icon(Icons.visibility),
                onPressed: () => context.push('/events/${event.id}', extra: event),
              ),
            ),
          ],
        )).toList(),
      ),
    );
  }
}
