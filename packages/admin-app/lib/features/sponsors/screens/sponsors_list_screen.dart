import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:industrynight_shared/shared.dart';
import '../../../config/routes.dart';
import '../../../providers/admin_state.dart';

class SponsorsListScreen extends StatefulWidget {
  const SponsorsListScreen({super.key});

  @override
  State<SponsorsListScreen> createState() => _SponsorsListScreenState();
}

class _SponsorsListScreenState extends State<SponsorsListScreen> {
  List<Sponsor> _sponsors = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSponsors();
  }

  Future<void> _loadSponsors() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final adminApi = context.read<AdminState>().adminApi;
    try {
      final sponsors = await adminApi.getSponsors();
      if (!mounted) return;
      setState(() {
        _sponsors = sponsors;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Failed to load sponsors';
        _isLoading = false;
      });
    }
  }

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
          child: _buildContent(),
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
              onPressed: _loadSponsors,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_sponsors.isEmpty) {
      return const Center(child: Text('No sponsors yet'));
    }

    return SingleChildScrollView(
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Sponsor')),
          DataColumn(label: Text('Tier')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Actions')),
        ],
        rows: _sponsors.map((sponsor) => DataRow(
          cells: [
            DataCell(
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    child: Text(sponsor.name.substring(0, 1).toUpperCase()),
                  ),
                  const SizedBox(width: 8),
                  Text(sponsor.name),
                ],
              ),
            ),
            DataCell(Chip(label: Text(sponsor.tier.name))),
            DataCell(
              Chip(
                label: Text(sponsor.isActive ? 'Active' : 'Inactive'),
                backgroundColor: sponsor.isActive
                    ? Colors.green.shade100
                    : Colors.grey.shade200,
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
                        context.push('/sponsors/${sponsor.id}/discounts'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: 'Edit',
                    onPressed: () =>
                        context.push('/sponsors/${sponsor.id}/edit', extra: sponsor),
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
