import 'package:flutter/material.dart';

class DiscountsScreen extends StatelessWidget {
  final String sponsorId;

  const DiscountsScreen({super.key, required this.sponsorId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Discounts - Sponsor $sponsorId'),
        actions: [
          ElevatedButton.icon(
            onPressed: () => _showAddDiscountDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Discount'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Title')),
              DataColumn(label: Text('Type')),
              DataColumn(label: Text('Value')),
              DataColumn(label: Text('Code')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: List.generate(
              4,
              (index) => DataRow(
                cells: [
                  DataCell(Text('Discount ${index + 1}')),
                  DataCell(Text(['Percentage', 'Fixed', 'Free Item', 'BOGO'][index % 4])),
                  DataCell(Text(index % 2 == 0 ? '${15 + index * 5}%' : '\$${10 + index * 5}')),
                  DataCell(Text('CODE${index + 1}')),
                  DataCell(
                    Chip(
                      label: Text(index == 0 ? 'Inactive' : 'Active'),
                      backgroundColor:
                          index == 0 ? Colors.grey.shade200 : Colors.green.shade100,
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {},
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
    );
  }

  void _showAddDiscountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Discount'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const TextField(
                decoration: InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'percentage', child: Text('Percentage')),
                  DropdownMenuItem(value: 'fixed', child: Text('Fixed Amount')),
                  DropdownMenuItem(value: 'freeItem', child: Text('Free Item')),
                  DropdownMenuItem(value: 'bogo', child: Text('Buy One Get One')),
                ],
                onChanged: (value) {},
              ),
              const SizedBox(height: 16),
              const TextField(
                decoration: InputDecoration(labelText: 'Value'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              const TextField(
                decoration: InputDecoration(labelText: 'Promo Code'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
