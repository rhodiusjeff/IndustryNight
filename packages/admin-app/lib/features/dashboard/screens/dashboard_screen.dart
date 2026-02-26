import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:industrynight_shared/shared.dart';
import '../../../providers/admin_state.dart';
import '../../../shared/widgets/stat_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardStats? _stats;
  List<User> _recentUsers = [];
  List<User> _pendingUsers = [];
  bool _isLoading = true;
  String? _error;

  final _numberFormat = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final adminApi = context.read<AdminState>().adminApi;

    try {
      final results = await Future.wait([
        adminApi.getDashboardStats(),
        adminApi.getUsers(limit: 5),
        adminApi.getUsers(verificationStatus: VerificationStatus.pending, limit: 5),
      ]);

      if (!mounted) return;
      setState(() {
        _stats = results[0] as DashboardStats;
        _recentUsers = results[1] as List<User>;
        _pendingUsers = results[2] as List<User>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Failed to load dashboard data';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateVerification(String userId, VerificationStatus status) async {
    final adminApi = context.read<AdminState>().adminApi;
    try {
      await adminApi.updateUser(userId, verificationStatus: status);
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : 'Failed to update verification'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dashboard')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dashboard')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final stats = _stats!;
    final verificationRate = stats.totalUsers > 0
        ? (stats.verifiedUsers / stats.totalUsers * 100).toStringAsFixed(0)
        : '0';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats row
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'Total Users',
                    value: _numberFormat.format(stats.totalUsers),
                    icon: Icons.people,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'Verified Users',
                    value: _numberFormat.format(stats.verifiedUsers),
                    icon: Icons.verified_user,
                    color: Colors.green,
                    subtitle: '$verificationRate% verification rate',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'Upcoming Events',
                    value: _numberFormat.format(stats.upcomingEvents),
                    icon: Icons.event,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'Total Connections',
                    value: _numberFormat.format(stats.totalConnections),
                    icon: Icons.connect_without_contact,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Recent activity
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Recent users
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recent Users',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          if (_recentUsers.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text(
                                  'No users yet',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            )
                          else
                            ..._recentUsers.map((user) => ListTile(
                              leading: CircleAvatar(
                                child: Text(
                                  (user.name ?? 'U').substring(0, 1).toUpperCase(),
                                ),
                              ),
                              title: Text(user.name ?? 'Unnamed'),
                              subtitle: Text('Joined ${_timeAgo(user.createdAt)}'),
                            )),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Pending verifications
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pending Verifications',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          if (_pendingUsers.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text(
                                  'No pending verifications',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            )
                          else
                            ..._pendingUsers.map((user) => ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.orange.shade100,
                                child: const Icon(
                                  Icons.pending,
                                  color: Colors.orange,
                                ),
                              ),
                              title: Text(user.name ?? 'Unnamed'),
                              subtitle: Text('Submitted ${_timeAgo(user.createdAt)}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.check, color: Colors.green),
                                    tooltip: 'Approve',
                                    onPressed: () => _updateVerification(
                                      user.id,
                                      VerificationStatus.verified,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.red),
                                    tooltip: 'Reject',
                                    onPressed: () => _updateVerification(
                                      user.id,
                                      VerificationStatus.rejected,
                                    ),
                                  ),
                                ],
                              ),
                            )),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
