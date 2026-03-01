import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:industrynight_shared/shared.dart';
import '../../../providers/app_state.dart';
import '../../../shared/theme/app_theme.dart';
import '../networking_state.dart';
import '../widgets/digital_card.dart';
import '../widgets/new_connection_overlay.dart';

/// The Connect tab — shows the user's digital card and a "Scan to Connect" button
/// when checked in, or contextual guidance when not.
class ConnectTabScreen extends StatefulWidget {
  const ConnectTabScreen({super.key});

  @override
  State<ConnectTabScreen> createState() => _ConnectTabScreenState();
}

class _ConnectTabScreenState extends State<ConnectTabScreen> {
  List<Ticket> _myTickets = [];
  bool _isLoadingTickets = true;
  String? _celebratedConnectionId;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updatePolling();
  }

  @override
  void dispose() {
    try {
      context.read<NetworkingState>().stopPolling();
    } catch (_) {}
    super.dispose();
  }

  void _updatePolling() {
    final appState = context.read<AppState>();
    final networkingState = context.read<NetworkingState>();

    if (appState.hasActiveEvent) {
      networkingState.startPolling(
        currentVerificationStatus: appState.currentUser?.verificationStatus ??
            VerificationStatus.unverified,
      );
    } else {
      networkingState.stopPolling();
    }
  }

  Future<void> _loadTickets() async {
    try {
      final eventsApi = context.read<AppState>().eventsApi;
      final tickets = await eventsApi.getMyTickets();
      if (!mounted) return;
      setState(() {
        _myTickets = tickets;
        _isLoadingTickets = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingTickets = false);
    }
  }

  Future<void> _showConnectionCelebration(
    Connection connection,
    bool wasJustVerified,
  ) async {
    final networkingState = context.read<NetworkingState>();
    final appState = context.read<AppState>();
    final otherUser = connection.getOtherUser(networkingState.currentUserId);

    if (otherUser == null) {
      networkingState.clearNewConnectionNotification();
      return;
    }

    if (wasJustVerified) {
      appState.setVerified();
    }

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss celebration',
      barrierColor: Colors.transparent,
      pageBuilder: (dialogContext, _, __) {
        return NewConnectionOverlay(
          otherUser: otherUser,
          justVerified: wasJustVerified,
          onDismiss: () => Navigator.of(dialogContext).pop(),
        );
      },
    );

    if (!mounted) return;
    networkingState.clearNewConnectionNotification();

    // Resume polling to catch additional connections
    networkingState.startPolling(
      currentVerificationStatus: appState.currentUser?.verificationStatus ??
          VerificationStatus.unverified,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final networkingState = context.watch<NetworkingState>();

    // Detect new connection from polling
    final newConn = networkingState.newConnection;
    if (newConn != null && newConn.id != _celebratedConnectionId) {
      _celebratedConnectionId = newConn.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showConnectionCelebration(newConn, networkingState.wasJustVerified);
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect'),
      ),
      body: SafeArea(
        child: _isLoadingTickets
            ? const Center(child: CircularProgressIndicator())
            : appState.hasActiveEvent
                ? _buildActiveState(appState)
                : _buildInactiveState(appState),
      ),
    );
  }

  /// State 1: Checked in — full QR + scan enabled
  Widget _buildActiveState(AppState appState) {
    final user = appState.currentUser;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Event banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.event, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    appState.activeEventName ?? 'Event',
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: user != null
                    ? DigitalCard(user: user)
                    : const CircularProgressIndicator(),
              ),
            ),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/connect/scan'),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan to Connect'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// State 2 & 3: Not checked in
  Widget _buildInactiveState(AppState appState) {
    // Find the soonest upcoming purchased (not yet checked-in) ticket
    final upcomingTicket = _findUpcomingTicket();

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.qr_code,
              size: 80,
              color: AppColors.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 24),

            if (upcomingTicket != null) ...[
              // State 2: Has upcoming ticket
              Text(
                'Connections will be available at',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                upcomingTicket.eventName ?? 'your event',
                style: AppTypography.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _formatCountdown(upcomingTicket.eventStartTime),
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => context.push('/events/${upcomingTicket.eventId}'),
                icon: const Icon(Icons.event),
                label: const Text('View Event'),
              ),
            ] else ...[
              // State 3: No tickets
              Text(
                'Connections become available when checked into an Industry Night event',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => context.go('/events'),
                icon: const Icon(Icons.search),
                label: const Text('Browse Events'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Find the soonest upcoming purchased ticket (not yet checked in)
  Ticket? _findUpcomingTicket() {
    final now = DateTime.now();
    for (final ticket in _myTickets) {
      if (ticket.status == TicketStatus.purchased &&
          ticket.eventStartTime != null &&
          ticket.eventStartTime!.isAfter(now)) {
        return ticket;
      }
    }
    return null;
  }

  String _formatCountdown(DateTime? eventStart) {
    if (eventStart == null) return '';
    final diff = eventStart.difference(DateTime.now());
    if (diff.inDays > 1) return 'in ${diff.inDays} days';
    if (diff.inDays == 1) return 'Tomorrow';
    if (diff.inHours > 0) return 'in ${diff.inHours} hours';
    return 'Starting soon';
  }
}
