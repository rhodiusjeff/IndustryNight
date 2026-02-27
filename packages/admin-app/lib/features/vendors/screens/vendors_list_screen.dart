import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:industrynight_shared/shared.dart';
import '../../../config/routes.dart';
import '../../../providers/admin_state.dart';

class VendorsListScreen extends StatefulWidget {
  const VendorsListScreen({super.key});

  @override
  State<VendorsListScreen> createState() => _VendorsListScreenState();
}

class _VendorsListScreenState extends State<VendorsListScreen> {
  List<Vendor> _vendors = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVendors();
  }

  Future<void> _loadVendors() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final adminApi = context.read<AdminState>().adminApi;
    try {
      final vendors = await adminApi.getVendors();
      if (!mounted) return;
      setState(() {
        _vendors = vendors;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Failed to load vendors';
        _isLoading = false;
      });
    }
  }

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
        child: Card(child: _buildContent()),
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
              onPressed: _loadVendors,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_vendors.isEmpty) {
      return const Center(child: Text('No vendors yet'));
    }

    return SingleChildScrollView(
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Vendor')),
          DataColumn(label: Text('Category')),
          DataColumn(label: Text('Contact')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Actions')),
        ],
        rows: _vendors.map((vendor) => DataRow(
          cells: [
            DataCell(
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    child: Text(vendor.name.substring(0, 1).toUpperCase()),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      vendor.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
              onTap: () => context.push('/vendors/${vendor.id}/edit', extra: vendor),
            ),
            DataCell(Text(vendor.category.name)),
            DataCell(Text(vendor.contactEmail ?? '—')),
            DataCell(
              Chip(
                label: Text(vendor.isActive ? 'Active' : 'Inactive'),
                backgroundColor: vendor.isActive
                    ? Colors.green.shade100
                    : Colors.grey.shade200,
              ),
            ),
            DataCell(
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () =>
                    context.push('/vendors/${vendor.id}/edit', extra: vendor),
              ),
            ),
          ],
        )).toList(),
      ),
    );
  }
}
