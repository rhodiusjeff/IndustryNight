import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:industrynight_shared/shared.dart';
import '../../../providers/app_state.dart';
import '../../../shared/theme/app_theme.dart';
import '../widgets/event_card.dart';

class EventsListScreen extends StatefulWidget {
  const EventsListScreen({super.key});

  @override
  State<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends State<EventsListScreen> {
  List<Event> _events = [];
  Map<String, TicketStatus> _ticketsByEvent = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final appState = context.read<AppState>();
      final results = await Future.wait([
        appState.eventsApi.getUpcomingEvents(),
        appState.eventsApi.getMyTickets(),
      ]);
      if (!mounted) return;

      final events = results[0] as List<Event>;
      final tickets = results[1] as List<Ticket>;

      // Build map of eventId → ticket status
      final ticketMap = <String, TicketStatus>{};
      for (final ticket in tickets) {
        ticketMap[ticket.eventId] = ticket.status;
      }

      // Sort: ticketed events first (by startTime), then non-ticketed (by startTime)
      events.sort((a, b) {
        final aHasTicket = ticketMap.containsKey(a.id);
        final bHasTicket = ticketMap.containsKey(b.id);
        if (aHasTicket && !bHasTicket) return -1;
        if (!aHasTicket && bHasTicket) return 1;
        return a.startTime.compareTo(b.startTime);
      });

      setState(() {
        _events = events;
        _ticketsByEvent = ticketMap;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Failed to load events';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text(_error!, style: AppTypography.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadEvents, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_events.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.event_busy, size: 64, color: AppColors.textTertiary),
              const SizedBox(height: 16),
              const Text(
                'No upcoming events',
                style: AppTypography.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Check back soon for new Industry Night events.',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEvents,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _events.length,
        itemBuilder: (context, index) {
          final event = _events[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: EventCard(
              event: event,
              ticketStatus: _ticketsByEvent[event.id],
              onTap: () => context.push('/events/${event.id}'),
            ),
          );
        },
      ),
    );
  }
}
