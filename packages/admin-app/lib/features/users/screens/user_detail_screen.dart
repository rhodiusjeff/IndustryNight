import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:industrynight_shared/shared.dart';
import '../../../providers/admin_state.dart';

class UserDetailScreen extends StatefulWidget {
  final String userId;
  final User? user;

  const UserDetailScreen({super.key, required this.userId, this.user});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  User? _user;
  bool _isLoading = false;
  String? _error;

  final _dateFormat = DateFormat('MMMM d, yyyy');

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      _user = widget.user;
    } else {
      _isLoading = true;
      _error = 'Navigate to this page from the users list';
    }
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  Future<void> _toggleBan() async {
    final user = _user!;
    final action = user.banned ? 'unban' : 'ban';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${user.banned ? 'Unban' : 'Ban'} User?'),
        content: Text('Are you sure you want to $action ${user.name ?? 'this user'}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: user.banned ? Colors.green : Colors.red,
            ),
            child: Text(user.banned ? 'Unban' : 'Ban'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final adminApi = context.read<AdminState>().adminApi;
    try {
      final updated = await adminApi.updateUser(user.id, banned: !user.banned);
      if (!mounted) return;
      setState(() => _user = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User ${updated.banned ? 'banned' : 'unbanned'}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : 'Failed to update user'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateVerification(VerificationStatus status) async {
    final adminApi = context.read<AdminState>().adminApi;
    try {
      final updated = await adminApi.updateUser(_user!.id, verificationStatus: status);
      if (!mounted) return;
      setState(() => _user = updated);
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('User')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null && _user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('User')),
        body: Center(child: Text(_error!)),
      );
    }

    final user = _user!;

    return Scaffold(
      appBar: AppBar(
        title: Text(user.name ?? 'User'),
        actions: [
          OutlinedButton.icon(
            onPressed: _toggleBan,
            icon: Icon(
              user.banned ? Icons.check_circle : Icons.block,
              color: user.banned ? Colors.green : Colors.red,
            ),
            label: Text(user.banned ? 'Unban User' : 'Ban User'),
            style: OutlinedButton.styleFrom(
              foregroundColor: user.banned ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundImage: user.profilePhotoUrl != null
                                ? NetworkImage(user.profilePhotoUrl!)
                                : null,
                            child: user.profilePhotoUrl == null
                                ? const Icon(Icons.person, size: 40)
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name ?? 'Unnamed',
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                              Row(
                                children: [
                                  Icon(
                                    user.verificationStatus == VerificationStatus.verified
                                        ? Icons.verified
                                        : Icons.pending,
                                    color: user.verificationStatus == VerificationStatus.verified
                                        ? Colors.green
                                        : Colors.orange,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(user.verificationStatus.displayName),
                                ],
                              ),
                              if (user.banned)
                                const Chip(
                                  label: Text('BANNED'),
                                  backgroundColor: Colors.red,
                                  labelStyle: TextStyle(color: Colors.white),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildInfoRow('Phone', user.phone),
                      _buildInfoRow('Email', user.email ?? '—'),
                      _buildInfoRow('Role', user.role.displayName),
                      _buildInfoRow('Source', user.source.displayName),
                      _buildInfoRow(
                        'Specialties',
                        user.specialties.isNotEmpty
                            ? user.specialties.join(', ')
                            : '—',
                      ),
                      _buildInfoRow('Joined', _dateFormat.format(user.createdAt)),
                      _buildInfoRow(
                        'Last Login',
                        user.lastLoginAt != null
                            ? _timeAgo(user.lastLoginAt!)
                            : 'Never',
                      ),
                      if (user.bio != null && user.bio!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text('Bio', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(user.bio!),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verification',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      Text('Status: ${user.verificationStatus.displayName}'),
                      if (user.verificationStatus == VerificationStatus.pending) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _updateVerification(VerificationStatus.verified),
                              icon: const Icon(Icons.check),
                              label: const Text('Approve'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () => _updateVerification(VerificationStatus.rejected),
                              icon: const Icon(Icons.close, color: Colors.red),
                              label: const Text('Reject'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
