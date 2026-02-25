import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:industrynight_shared/shared.dart';
import '../../../shared/theme/app_theme.dart';
import '../networking_state.dart';
import '../widgets/connection_card.dart';

/// The Network tab — shows the user's full connections list.
class ConnectionsListScreen extends StatefulWidget {
  const ConnectionsListScreen({super.key});

  @override
  State<ConnectionsListScreen> createState() => _ConnectionsListScreenState();
}

class _ConnectionsListScreenState extends State<ConnectionsListScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch connections on first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NetworkingState>().fetchConnections();
    });
  }

  Future<void> _confirmRemove(Connection connection, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Connection'),
        content: Text('Remove $name from your connections?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success =
          await context.read<NetworkingState>().removeConnection(connection.id);
      if (mounted && !success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to remove connection')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<NetworkingState>();
    final connections = state.connections;
    final currentUserId = state.currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Network'),
      ),
      body: state.isLoadingConnections && connections.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : connections.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No connections yet',
                          style: AppTypography.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Scan a QR code at an event to make your first connection',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => state.fetchConnections(force: true),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: connections.length,
                    itemBuilder: (context, index) {
                      final connection = connections[index];
                      final otherUser =
                          connection.getOtherUser(currentUserId);
                      final name = otherUser?.name ?? 'Unknown';

                      return Dismissible(
                        key: Key(connection.id),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) async {
                          await _confirmRemove(connection, name);
                          return false; // We handle removal in _confirmRemove
                        },
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: AppColors.error,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        child: ConnectionCard(
                          connection: connection,
                          currentUserId: currentUserId,
                          onTap: () {
                            if (otherUser != null) {
                              context.push('/users/${otherUser.id}');
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
