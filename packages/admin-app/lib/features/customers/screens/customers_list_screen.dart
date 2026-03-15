import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:industrynight_shared/shared.dart';
import '../../../providers/admin_state.dart';

class CustomersListScreen extends StatefulWidget {
  const CustomersListScreen({super.key});

  @override
  State<CustomersListScreen> createState() => _CustomersListScreenState();
}

class _CustomersListScreenState extends State<CustomersListScreen> {
  List<Customer> _customers = [];
  bool _isLoading = true;
  String? _error;
  String? _filterType;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final adminApi = context.read<AdminState>().adminApi;
    try {
      final customers = await adminApi.getCustomers(
        query: _searchController.text.isNotEmpty ? _searchController.text : null,
        hasProductType: _filterType,
      );
      if (!mounted) return;
      setState(() {
        _customers = customers;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Failed to load customers';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        actions: [
          ElevatedButton.icon(
            onPressed: () async {
              await context.push('/customers/add');
              _loadCustomers();
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Customer'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Filter row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search customers...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _loadCustomers(),
                  ),
                ),
                const SizedBox(width: 16),
                SegmentedButton<String?>(
                  segments: const [
                    ButtonSegment(value: null, label: Text('All')),
                    ButtonSegment(value: 'sponsorship', label: Text('Sponsors')),
                    ButtonSegment(value: 'vendor_space', label: Text('Vendors')),
                    ButtonSegment(value: 'data_product', label: Text('Data')),
                  ],
                  selected: {_filterType},
                  onSelectionChanged: (values) {
                    setState(() => _filterType = values.first);
                    _loadCustomers();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(child: _buildContent()),
            ),
          ],
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
              onPressed: _loadCustomers,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_customers.isEmpty) {
      return const Center(child: Text('No customers yet'));
    }

    return SingleChildScrollView(
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Customer')),
          DataColumn(label: Text('Markets')),
          DataColumn(label: Text('Products')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Actions')),
        ],
        rows: _customers.map((customer) => DataRow(
          cells: [
            DataCell(
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    child: Text(customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?'),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      customer.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
              onTap: () async {
                await context.push('/customers/${customer.id}');
                _loadCustomers();
              },
            ),
            DataCell(
              Wrap(
                spacing: 4,
                children: (customer.markets ?? []).map((m) => Chip(
                  label: Text(m.name, style: const TextStyle(fontSize: 12)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                )).toList(),
              ),
            ),
            DataCell(
              Wrap(
                spacing: 4,
                children: (customer.activeProductTypes ?? []).map((type) {
                  final label = switch (type) {
                    'sponsorship' => 'Sponsor',
                    'vendor_space' => 'Vendor',
                    'data_product' => 'Data',
                    _ => type,
                  };
                  final color = switch (type) {
                    'sponsorship' => Colors.purple.shade100,
                    'vendor_space' => Colors.blue.shade100,
                    'data_product' => Colors.green.shade100,
                    _ => Colors.grey.shade200,
                  };
                  return Chip(
                    label: Text(label, style: const TextStyle(fontSize: 12)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: color,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ),
            DataCell(
              Chip(
                label: Text(customer.isActive ? 'Active' : 'Inactive'),
                backgroundColor: customer.isActive
                    ? Colors.green.shade100
                    : Colors.grey.shade200,
              ),
            ),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility),
                    tooltip: 'View Detail',
                    onPressed: () async {
                      await context.push('/customers/${customer.id}');
                      _loadCustomers();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: 'Edit',
                    onPressed: () async {
                      await context.push('/customers/${customer.id}/edit', extra: customer);
                      _loadCustomers();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.local_offer),
                    tooltip: 'Manage Discounts',
                    onPressed: () async {
                      await context.push('/customers/${customer.id}/discounts');
                      _loadCustomers();
                    },
                  ),
                ],
              ),
            ),
          ],
        )).toList(),
      ),
    );
  }
}
