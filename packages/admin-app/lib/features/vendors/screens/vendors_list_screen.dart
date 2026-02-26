import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../config/routes.dart';

class VendorsListScreen extends StatelessWidget {
  const VendorsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendors'),
        actions: [
          ElevatedButton.icon(
            onPressed: () => context.push(AdminRoutes.addVendor),
            icon: const Icon(Icons.add),
            label: const Text('Add Vendor'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Vendor')),
              DataColumn(label: Text('Category')),
              DataColumn(label: Text('Contact')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: List.generate(
              6,
              (index) => DataRow(
                cells: [
                  DataCell(
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          child: Text('V${index + 1}'),
                        ),
                        const SizedBox(width: 8),
                        Text('Vendor ${index + 1}'),
                      ],
                    ),
                  ),
                  DataCell(Text(
                    ['Food', 'Beverage', 'Equipment', 'Service', 'Venue', 'Other'][index % 6],
                  )),
                  DataCell(Text('vendor${index + 1}@email.com')),
                  DataCell(
                    Chip(
                      label: Text(index == 2 ? 'Inactive' : 'Active'),
                      backgroundColor:
                          index == 2 ? Colors.grey.shade200 : Colors.green.shade100,
                    ),
                  ),
                  DataCell(
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => context.push('/vendors/vendor_$index/edit'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
