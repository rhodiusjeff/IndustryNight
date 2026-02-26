import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../config/routes.dart';

class SponsorsListScreen extends StatelessWidget {
  const SponsorsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sponsors'),
        actions: [
          ElevatedButton.icon(
            onPressed: () => context.push(AdminRoutes.addSponsor),
            icon: const Icon(Icons.add),
            label: const Text('Add Sponsor'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Sponsor')),
                      DataColumn(label: Text('Tier')),
                      DataColumn(label: Text('Discounts')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: List.generate(
                      8,
                      (index) => DataRow(
                        cells: [
                          DataCell(
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  child: Text('S${index + 1}'),
                                ),
                                const SizedBox(width: 8),
                                Text('Sponsor ${index + 1}'),
                              ],
                            ),
                          ),
                          DataCell(
                            Chip(
                              label: Text(
                                ['Bronze', 'Silver', 'Gold', 'Platinum'][index % 4],
                              ),
                            ),
                          ),
                          DataCell(Text('${2 + index % 3}')),
                          DataCell(
                            Chip(
                              label: Text(index % 5 == 0 ? 'Inactive' : 'Active'),
                              backgroundColor: index % 5 == 0
                                  ? Colors.grey.shade200
                                  : Colors.green.shade100,
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.local_offer),
                                  tooltip: 'Manage Discounts',
                                  onPressed: () =>
                                      context.push('/sponsors/sponsor_$index/discounts'),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  tooltip: 'Edit',
                                  onPressed: () =>
                                      context.push('/sponsors/sponsor_$index/edit'),
                                ),
                              ],
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
