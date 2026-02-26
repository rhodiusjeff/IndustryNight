import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:industrynight_shared/shared.dart';
import '../../../config/routes.dart';
import '../../../providers/admin_state.dart';

class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  List<User> _users = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  VerificationStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final adminApi = context.read<AdminState>().adminApi;
    try {
      final users = await adminApi.getUsers(
        query: _searchQuery.isNotEmpty ? _searchQuery : null,
        verificationStatus: _statusFilter,
      );
      if (!mounted) return;
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Failed to load users';
        _isLoading = false;
      });
    }
  }

  Color _statusColor(VerificationStatus status) {
    switch (status) {
      case VerificationStatus.verified:
        return Colors.green.shade100;
      case VerificationStatus.pending:
        return Colors.orange.shade100;
      case VerificationStatus.rejected:
        return Colors.red.shade100;
      case VerificationStatus.unverified:
        return Colors.grey.shade200;
    }
  }

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
                        onChanged: (value) {
                          _searchQuery = value;
                        },
                        onSubmitted: (_) => _loadUsers(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    DropdownButton<String>(
                      value: _statusFilter?.name ?? 'all',
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All')),
                        DropdownMenuItem(value: 'verified', child: Text('Verified')),
                        DropdownMenuItem(value: 'pending', child: Text('Pending')),
                        DropdownMenuItem(value: 'unverified', child: Text('Unverified')),
                        DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _statusFilter = value == 'all'
                              ? null
                              : VerificationStatus.fromString(value!);
                        });
                        _loadUsers();
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _buildContent(),
              ),
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
              onPressed: _loadUsers,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_users.isEmpty) {
      return const Center(child: Text('No users found'));
    }

    return SingleChildScrollView(
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Name')),
          DataColumn(label: Text('Phone')),
          DataColumn(label: Text('Specialties')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Source')),
          DataColumn(label: Text('Actions')),
        ],
        rows: _users.map((user) => DataRow(
          cells: [
            DataCell(
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    child: Text(
                      (user.name ?? 'U').substring(0, 1).toUpperCase(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(user.name ?? 'Unnamed'),
                ],
              ),
            ),
            DataCell(Text(user.phone)),
            DataCell(Text(
              user.specialties.isNotEmpty
                  ? user.specialties.join(', ')
                  : '—',
            )),
            DataCell(
              Chip(
                label: Text(user.verificationStatus.displayName),
                backgroundColor: _statusColor(user.verificationStatus),
              ),
            ),
            DataCell(Text(user.source.displayName)),
            DataCell(
              IconButton(
                icon: const Icon(Icons.visibility),
                onPressed: () => context.push('/users/${user.id}', extra: user),
              ),
            ),
          ],
        )).toList(),
      ),
    );
  }
}
