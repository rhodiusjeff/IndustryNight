import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:industrynight_shared/shared.dart';
import '../../../providers/admin_state.dart';

class EventTicketsScreen extends StatefulWidget {
  final String eventId;

  const EventTicketsScreen({super.key, required this.eventId});

  @override
  State<EventTicketsScreen> createState() => _EventTicketsScreenState();
}

class _EventTicketsScreenState extends State<EventTicketsScreen> {
  List<Ticket> _tickets = [];
  String? _eventName;
  bool _isLoading = true;
  String? _error;
  TicketStatus? _statusFilter;

  final _dateFormat = DateFormat('MMM d, yyyy h:mm a');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final adminApi = context.read<AdminState>().adminApi;
    try {
      final results = await Future.wait([
        adminApi.getEventTickets(widget.eventId, status: _statusFilter),
        adminApi.getEvent(widget.eventId),
      ]);
      if (!mounted) return;
      setState(() {
        _tickets = results[0] as List<Ticket>;
        _eventName = (results[1] as Event).name;
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

  Future<void> _reloadTickets() async {
    final adminApi = context.read<AdminState>().adminApi;
    try {
      final tickets = await adminApi.getEventTickets(
        widget.eventId,
        status: _statusFilter,
      );
      if (!mounted) return;
      setState(() => _tickets = tickets);
    } catch (_) {}
  }

  Future<void> _issueTicket() async {
    final adminApi = context.read<AdminState>().adminApi;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _IssueTicketDialog(
        adminApi: adminApi,
        eventId: widget.eventId,
        eventName: _eventName ?? 'this event',
      ),
    );
    if (result == true) _reloadTickets();
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
      await adminApi.deleteTicket(widget.eventId, ticket.id);
      if (!mounted) return;
      _reloadTickets();
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
      await adminApi.refundTicket(widget.eventId, ticket.id);
      if (!mounted) return;
      _reloadTickets();
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
        title: Text(_eventName != null ? 'Tickets — $_eventName' : 'Tickets'),
        actions: [
          ElevatedButton.icon(
            onPressed: _issueTicket,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Issue Ticket'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Filter bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<TicketStatus?>(
                    initialValue: _statusFilter,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All')),
                      DropdownMenuItem(value: TicketStatus.purchased, child: Text('Purchased')),
                      DropdownMenuItem(value: TicketStatus.checkedIn, child: Text('Checked In')),
                      DropdownMenuItem(value: TicketStatus.cancelled, child: Text('Cancelled')),
                      DropdownMenuItem(value: TicketStatus.refunded, child: Text('Refunded')),
                    ],
                    onChanged: (value) {
                      setState(() => _statusFilter = value);
                      _reloadTickets();
                    },
                  ),
                ),
                const Spacer(),
                Text(
                  '${_tickets.length} ticket${_tickets.length == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),

          // Content
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
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
              onPressed: _load,
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
            const Text('No tickets issued yet'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _issueTicket,
              icon: const Icon(Icons.add),
              label: const Text('Issue Ticket'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: DataTable(
          dataRowMinHeight: 56,
          dataRowMaxHeight: 64,
          columns: const [
            DataColumn(label: Text('User')),
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

// ────────────────────────────────────────────────────────────
// Status chip with color coding
// ────────────────────────────────────────────────────────────

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

// ────────────────────────────────────────────────────────────
// Issue ticket dialog with user search
// ────────────────────────────────────────────────────────────

class _IssueTicketDialog extends StatefulWidget {
  final AdminApi adminApi;
  final String eventId;
  final String eventName;

  const _IssueTicketDialog({
    required this.adminApi,
    required this.eventId,
    required this.eventName,
  });

  @override
  State<_IssueTicketDialog> createState() => _IssueTicketDialogState();
}

class _IssueTicketDialogState extends State<_IssueTicketDialog> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<User> _searchResults = [];
  bool _isSearching = false;
  User? _selectedUser;
  bool _isSubmitting = false;
  String? _submitError;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(query));
  }

  Future<void> _search(String query) async {
    setState(() => _isSearching = true);
    try {
      final users = await widget.adminApi.getUsers(query: query, limit: 10);
      if (!mounted) return;
      setState(() {
        _searchResults = users;
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSearching = false);
    }
  }

  Future<void> _submit() async {
    if (_selectedUser == null) return;

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      await widget.adminApi.issueTicket(
        widget.eventId,
        userId: _selectedUser!.id,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _submitError = e is ApiException ? e.message : 'Failed to issue ticket';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Issue Ticket'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Event: ${widget.eventName}'),
            const SizedBox(height: 16),

            if (_selectedUser == null) ...[
              // Search mode
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search user by name or phone',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: _onSearchChanged,
              ),
              const SizedBox(height: 8),

              if (_isSearching)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_searchResults.isNotEmpty)
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final user = _searchResults[index];
                      return ListTile(
                        title: Text(user.name ?? 'Unnamed'),
                        subtitle: Text(formatPhoneNumber(user.phone)),
                        dense: true,
                        onTap: () => setState(() => _selectedUser = user),
                      );
                    },
                  ),
                )
              else if (_searchController.text.length >= 2)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No users found',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
            ] else ...[
              // Confirmation mode
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(_selectedUser!.name ?? 'Unnamed'),
                  subtitle: Text(formatPhoneNumber(_selectedUser!.phone)),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _selectedUser = null),
                  ),
                ),
              ),
              if (_submitError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _submitError!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        if (_selectedUser != null)
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Issue Ticket'),
          ),
      ],
    );
  }
}
