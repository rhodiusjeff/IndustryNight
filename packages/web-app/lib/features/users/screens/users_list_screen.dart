import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../config/routes.dart';

class UsersListScreen extends StatelessWidget {
  const UsersListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        actions: [
          ElevatedButton.icon(
            onPressed: () => context.push(AdminRoutes.addUser),
            icon: const Icon(Icons.add),
            label: const Text('Add User'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Column(
            children: [
              // Filters
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search users...',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    DropdownButton<String>(
                      hint: const Text('Status'),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All')),
                        DropdownMenuItem(value: 'verified', child: Text('Verified')),
                        DropdownMenuItem(value: 'pending', child: Text('Pending')),
                        DropdownMenuItem(value: 'unverified', child: Text('Unverified')),
                      ],
                      onChanged: (value) {},
                    ),
                  ],
                ),
              ),

              // Table
              Expanded(
                child: SingleChildScrollView(
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Name')),
                      DataColumn(label: Text('Phone')),
                      DataColumn(label: Text('Specialties')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Source')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: List.generate(
                      20,
                      (index) => DataRow(
                        cells: [
                          DataCell(
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  child: Text('U${index + 1}'),
                                ),
                                const SizedBox(width: 8),
                                Text('User ${index + 1}'),
                              ],
                            ),
                          ),
                          DataCell(Text('+1 555 ${100 + index}')),
                          const DataCell(Text('Photographer')),
                          DataCell(
                            Chip(
                              label: Text(
                                index % 3 == 0
                                    ? 'Verified'
                                    : index % 3 == 1
                                        ? 'Pending'
                                        : 'Unverified',
                              ),
                              backgroundColor: index % 3 == 0
                                  ? Colors.green.shade100
                                  : index % 3 == 1
                                      ? Colors.orange.shade100
                                      : Colors.grey.shade200,
                            ),
                          ),
                          DataCell(Text(index % 2 == 0 ? 'App' : 'Posh')),
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.visibility),
                              onPressed: () => context.push('/users/user_$index'),
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
