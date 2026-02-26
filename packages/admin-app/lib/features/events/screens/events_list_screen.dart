import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../config/routes.dart';

class EventsListScreen extends StatelessWidget {
  const EventsListScreen({super.key});

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
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search events...',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    DropdownButton<String>(
                      hint: const Text('Status'),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All')),
                        DropdownMenuItem(value: 'published', child: Text('Published')),
                        DropdownMenuItem(value: 'draft', child: Text('Draft')),
                        DropdownMenuItem(value: 'completed', child: Text('Completed')),
                      ],
                      onChanged: (value) {},
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Event')),
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Venue')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Attendees')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: List.generate(
                      10,
                      (index) => DataRow(
                        cells: [
                          DataCell(Text('Industry Night ${index + 1}')),
                          DataCell(Text('Jan ${20 + index}, 2024')),
                          const DataCell(Text('The Grand Venue')),
                          DataCell(
                            Chip(
                              label: Text(
                                index % 2 == 0 ? 'Published' : 'Draft',
                              ),
                              backgroundColor: index % 2 == 0
                                  ? Colors.green.shade100
                                  : Colors.grey.shade200,
                            ),
                          ),
                          DataCell(Text('${50 + index * 10}')),
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.visibility),
                              onPressed: () => context.push('/events/event_$index'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
