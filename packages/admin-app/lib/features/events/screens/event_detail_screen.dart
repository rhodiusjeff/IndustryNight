import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:industrynight_shared/shared.dart';

class EventDetailScreen extends StatelessWidget {
  final String eventId;
  final Event? event;

  const EventDetailScreen({super.key, required this.eventId, this.event});

  @override
  Widget build(BuildContext context) {
    if (event == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Event')),
        body: const Center(child: Text('Navigate to this page from the events list')),
      );
    }

    final e = event!;
    final dateFormat = DateFormat('MMMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    Color statusColor;
    switch (e.status) {
      case EventStatus.published:
        statusColor = Colors.green.shade100;
        break;
      case EventStatus.draft:
        statusColor = Colors.grey.shade200;
        break;
      case EventStatus.cancelled:
        statusColor = Colors.red.shade100;
        break;
      case EventStatus.completed:
        statusColor = Colors.blue.shade100;
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(e.name),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.name,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          Chip(
                            label: Text(e.status.name),
                            backgroundColor: statusColor,
                          ),
                          const SizedBox(height: 24),
                          _buildInfoRow(Icons.calendar_today, dateFormat.format(e.startTime)),
                          _buildInfoRow(
                            Icons.access_time,
                            '${timeFormat.format(e.startTime)} - ${timeFormat.format(e.endTime)}',
                          ),
                          _buildInfoRow(
                            Icons.location_on,
                            [e.venueName, e.venueAddress]
                                .where((s) => s != null)
                                .join(', '),
                          ),
                          if (e.capacity != null)
                            _buildInfoRow(Icons.people, 'Capacity: ${e.capacity}'),
                          if (e.description != null && e.description!.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            Text(
                              'Description',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(e.description!),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (e.activationCode != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Activation Code',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
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
                                    e.activationCode!,
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
                                      Clipboard.setData(ClipboardData(text: e.activationCode!));
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
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Attendance',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      _buildStatRow('Checked In', '${e.attendeeCount}'),
                      if (e.capacity != null)
                        _buildStatRow(
                          'Available',
                          '${e.capacity! - e.attendeeCount}',
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
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
