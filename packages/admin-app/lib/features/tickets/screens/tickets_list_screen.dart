import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:industrynight_shared/shared.dart';
import '../../../providers/admin_state.dart';

class TicketsListScreen extends StatefulWidget {
  const TicketsListScreen({super.key});

  @override
  State<TicketsListScreen> createState() => _TicketsListScreenState();
}

class _TicketsListScreenState extends State<TicketsListScreen> {
  List<Ticket> _tickets = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  TicketStatus? _statusFilter;
  List<Event> _events = [];
  String? _eventFilter;

  final _dateFormat = DateFormat('MMM d, yyyy h:mm a');

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final adminApi = context.read<AdminState>().adminApi;
    try {
      final results = await Future.wait([
        adminApi.getAllTickets(),
        adminApi.getEvents(),
      ]);
      if (!mounted) return;
      setState(() {
        _tickets = results[0] as List<Ticket>;
        _events = results[1] as List<Event>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Failed to load tickets';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTickets() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final adminApi = context.read<AdminState>().adminApi;
    try {
      final tickets = await adminApi.getAllTickets(
        status: _statusFilter,
        eventId: _eventFilter,
        query: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
      if (!mounted) return;
      setState(() {
        _tickets = tickets;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Failed to load tickets';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteTicket(Ticket ticket) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Ticket'),
        content: Text(
          'Delete ticket for ${ticket.userName ?? ticket.userId}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final adminApi = context.read<AdminState>().adminApi;
    try {
      await adminApi.deleteTicket(ticket.eventId, ticket.id);
      if (!mounted) return;
      _loadTickets();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ticket deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : 'Failed to delete ticket'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _refundTicket(Ticket ticket) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Refund Ticket'),
        content: const Text(
          'Mark this ticket as refunded?\n\n'
          'Note: No payment refund will be processed — this only changes the ticket status.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Refund'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final adminApi = context.read<AdminState>().adminApi;
    try {
      await adminApi.refundTicket(ticket.eventId, ticket.id);
      if (!mounted) return;
      _loadTickets();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ticket marked as refunded')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : 'Failed to refund ticket'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tickets'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Column(
            children: [
              // Filter bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Search
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search by name or phone...',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (value) => _searchQuery = value,
                        onSubmitted: (_) => _loadTickets(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Event filter
                    SizedBox(
                      width: 220,
                      child: DropdownButton<String>(
                        value: _eventFilter ?? 'all',
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem(value: 'all', child: Text('All Events')),
                          ..._events.map((e) => DropdownMenuItem(
                            value: e.id,
                            child: Text(e.name, overflow: TextOverflow.ellipsis),
                          )),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _eventFilter = value == 'all' ? null : value;
                          });
                          _loadTickets();
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Status filter
                    DropdownButton<String>(
                      value: _statusFilter?.name ?? 'all',
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                        DropdownMenuItem(value: 'purchased', child: Text('Purchased')),
                        DropdownMenuItem(value: 'checkedIn', child: Text('Checked In')),
                        DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                        DropdownMenuItem(value: 'refunded', child: Text('Refunded')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _statusFilter = value == 'all'
                              ? null
                              : TicketStatus.values.firstWhere((s) => s.name == value);
                        });
                        _loadTickets();
                      },
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildContent()),
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
              onPressed: _loadTickets,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_tickets.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.confirmation_number_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('No tickets found'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: SizedBox(
        width: double.infinity,
        child: DataTable(
          dataRowMinHeight: 56,
          dataRowMaxHeight: 64,
          columns: const [
            DataColumn(label: Text('User')),
            DataColumn(label: Text('Event')),
            DataColumn(label: Text('Type')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Purchased')),
            DataColumn(label: Text('Checked In')),
            DataColumn(label: Text('Actions')),
          ],
          rows: _tickets.map((ticket) {
            return DataRow(cells: [
              // User
              DataCell(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      ticket.userName ?? 'Unknown',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    if (ticket.userPhone != null)
                      Text(
                        formatPhoneNumber(ticket.userPhone!),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                  ],
                ),
                onTap: () => context.push('/users/${ticket.userId}'),
              ),
              // Event
              DataCell(
                Text(
                  ticket.eventName ?? ticket.eventId,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
                onTap: () => context.push('/events/${ticket.eventId}'),
              ),
              // Type
              DataCell(Chip(
                label: Text(ticket.ticketType, style: const TextStyle(fontSize: 12)),
                visualDensity: VisualDensity.compact,
              )),
              // Status
              DataCell(_StatusChip(status: ticket.status)),
              // Purchased
              DataCell(Text(_dateFormat.format(ticket.purchasedAt.toLocal()))),
              // Checked In
              DataCell(Text(
                ticket.checkedInAt != null
                    ? _dateFormat.format(ticket.checkedInAt!.toLocal())
                    : '—',
              )),
              // Actions
              DataCell(Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (ticket.status == TicketStatus.purchased ||
                      ticket.status == TicketStatus.checkedIn)
                    IconButton(
                      icon: const Icon(Icons.money_off, size: 18),
                      tooltip: 'Refund',
                      onPressed: () => _refundTicket(ticket),
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    tooltip: 'Delete',
                    color: Colors.red,
                    onPressed: () => _deleteTicket(ticket),
                  ),
                ],
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final TicketStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (status) {
      TicketStatus.purchased => (Colors.blue.shade50, Colors.blue.shade800),
      TicketStatus.checkedIn => (Colors.green.shade50, Colors.green.shade800),
      TicketStatus.cancelled => (Colors.grey.shade200, Colors.grey.shade700),
      TicketStatus.refunded => (Colors.orange.shade50, Colors.orange.shade800),
    };

    return Chip(
      label: Text(
        status.name,
        style: TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.w500),
      ),
      backgroundColor: bg,
      visualDensity: VisualDensity.compact,
      side: BorderSide.none,
    );
  }
}
