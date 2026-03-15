import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:industrynight_shared/shared.dart';
import '../../../providers/app_state.dart';
import '../../../shared/theme/app_theme.dart';

class EventDetailScreen extends StatefulWidget {
  final String eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  Event? _event;
  Ticket? _myTicket;
  bool _isLoading = true;
  bool _isLoadingTicket = true;
  String? _error;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadEvent();
  }

  Future<void> _loadEvent() async {
    setState(() {
      _isLoading = true;
      _isLoadingTicket = true;
      _error = null;
    });

    final eventsApi = context.read<AppState>().eventsApi;

    // Load event first — this is required for the screen to render
    try {
      final event = await eventsApi.getEvent(widget.eventId);
      if (!mounted) return;
      setState(() {
        _event = event;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Failed to load event';
        _isLoading = false;
        _isLoadingTicket = false;
      });
      return;
    }

    // Load ticket separately — a failure here shouldn't break the screen
    await _refreshTicket();
  }

  /// Refresh only the ticket without resetting the whole screen.
  Future<void> _refreshTicket() async {
    try {
      final ticket = await context.read<AppState>().eventsApi.getMyTicket(widget.eventId);
      if (!mounted) return;
      debugPrint('[EventDetail] ticket status: ${ticket?.status}');
      setState(() {
        _myTicket = ticket;
        _isLoadingTicket = false;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('[EventDetail] ticket load error: $e');
      setState(() {
        _myTicket = null;
        _isLoadingTicket = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _event == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text(_error ?? 'Event not found', style: AppTypography.bodyMedium),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadEvent, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final event = _event!;
    final images = event.images ?? [];
    final partners = event.partners ?? [];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero image with page indicator
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                event.name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              background: images.isNotEmpty
                  ? _ImageCarousel(
                      images: images,
                      currentIndex: _currentImageIndex,
                      onPageChanged: (i) => setState(() => _currentImageIndex = i),
                    )
                  : Container(
                      color: AppColors.surfaceLight,
                      child: const Icon(Icons.event, size: 80, color: AppColors.textSecondary),
                    ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Date & Time
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.calendar_today, color: AppColors.primary),
                    title: Text(formatDate(event.startTime)),
                    subtitle: Text(formatTimeRange(event.startTime, event.endTime)),
                  ),
                ),
                const SizedBox(height: 8),

                // Location
                if (event.venueName != null)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.location_on, color: AppColors.primary),
                      title: Text(event.venueName!),
                      subtitle: event.venueAddress != null ? Text(event.venueAddress!) : null,
                    ),
                  ),
                const SizedBox(height: 16),

                // Description
                if (event.description != null && event.description!.isNotEmpty) ...[
                  const Text('About', style: AppTypography.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    event.description!,
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                ],

                // Partners (sponsors + vendors)
                if (partners.isNotEmpty) ...[
                  const Text('Partners', style: AppTypography.titleLarge),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: partners.map((p) => _PartnerChip(partner: p)).toList(),
                  ),
                  const SizedBox(height: 24),
                ],

                // Capacity info
                if (event.capacity != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.people, size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        '${event.attendeeCount} / ${event.capacity} attending',
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                // Ticket section (only for published, non-past events)
                if (event.isPublished && !event.isPast) ...[
                  if (_isLoadingTicket)
                    const Center(child: CircularProgressIndicator())
                  else if (_myTicket != null)
                    _buildTicketCard(event)
                  else
                    _buildGetTicketsCard(event),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildTicketCard(Event event) {
    final ticket = _myTicket!;
    final isCheckedIn = ticket.isCheckedIn;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCheckedIn ? Icons.check_circle : Icons.confirmation_number,
                  color: isCheckedIn ? Colors.green : AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text('Your Ticket', style: AppTypography.titleMedium),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isCheckedIn ? Colors.green : AppColors.primary)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isCheckedIn ? 'Checked In' : 'Purchased',
                    style: TextStyle(
                      color: isCheckedIn ? Colors.green : AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Purchased ${formatDate(ticket.purchasedAt)}',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
            if (!isCheckedIn && event.isPublished && !event.isPast) ...[
              const SizedBox(height: 12),
              Builder(builder: (context) {
                final now = DateTime.now();
                final eventDay = DateTime(event.startTime.year,
                    event.startTime.month, event.startTime.day);
                final today = DateTime(now.year, now.month, now.day);
                final isEventDay = !eventDay.isAfter(today);

                if (!isEventDay) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.schedule,
                            size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Text(
                          'Check-in available on event day',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final appState = context.read<AppState>();
                      final result = await context.push<Ticket>(
                        '/events/${widget.eventId}/checkin',
                        extra: {
                          'eventName': event.name,
                          'eventEndTime': event.endTime.toIso8601String(),
                        },
                      );
                      if (!mounted) return;

                      if (result != null && result.isCheckedIn) {
                        // Direct update from check-in response
                        setState(() {
                          _myTicket = result;
                          if (_event != null) {
                            _event = _event!.copyWith(
                              attendeeCount: _event!.attendeeCount + 1,
                            );
                          }
                        });
                      } else {
                        // Fallback: refresh ticket from API
                        await _refreshTicket();
                      }

                      // Set active event session AFTER local state is updated,
                      // so the GoRouter refreshListenable rebuild sees correct state.
                      if (!mounted) return;
                      final currentTicket = _myTicket;
                      if (currentTicket != null && currentTicket.isCheckedIn) {
                        await appState.setActiveEvent(
                          eventId: widget.eventId,
                          name: event.name,
                          endTime: event.endTime,
                        );
                      }
                    },
                    icon: const Icon(Icons.qr_code),
                    label: const Text('Check In'),
                  ),
                );
              }),
            ],
            if (isCheckedIn) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.people, color: AppColors.primary, size: 28),
                    const SizedBox(height: 8),
                    Text(
                      'Start Connecting!',
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Builder(builder: (context) {
                      final appState = context.read<AppState>();
                      final isUnverified = appState.currentUser?.verificationStatus ==
                          VerificationStatus.unverified;
                      return Text(
                        isUnverified
                            ? 'Connect with someone to get verified'
                            : 'Open your QR code and start meeting people',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      );
                    }),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => context.go('/connect'),
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Open Connect'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGetTicketsCard(Event event) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(
              Icons.confirmation_number_outlined,
              size: 32,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 8),
            Text(
              'You need a ticket for this event',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (event.poshEventId != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final url = Uri.parse('https://posh.vip/e/${event.poshEventId}');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Get Tickets on Posh'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Horizontal image carousel with page indicator dots.
class _ImageCarousel extends StatefulWidget {
  final List<EventImage> images;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;

  const _ImageCarousel({
    required this.images,
    required this.currentIndex,
    required this.onPageChanged,
  });

  @override
  State<_ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<_ImageCarousel> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: widget.images.length,
          onPageChanged: widget.onPageChanged,
          itemBuilder: (context, index) {
            return Image.network(
              widget.images[index].url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.surfaceLight,
                child: const Icon(Icons.broken_image, size: 48, color: AppColors.textSecondary),
              ),
            );
          },
        ),
        // Page indicator dots
        if (widget.images.length > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.images.length, (i) {
                return Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == widget.currentIndex
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.4),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

/// Partner chip showing logo + name + type badge.
class _PartnerChip extends StatelessWidget {
  final EventPartner partner;

  const _PartnerChip({required this.partner});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (partner.logoUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                partner.logoUrl!,
                width: 24,
                height: 24,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.business, size: 20),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(partner.name, style: AppTypography.labelMedium.copyWith(color: AppColors.chipText)),
        ],
      ),
    );
  }
}
