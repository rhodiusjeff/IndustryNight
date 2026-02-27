import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
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

    try {
      final eventsApi = context.read<AppState>().eventsApi;
      final results = await Future.wait([
        eventsApi.getEvent(widget.eventId),
        eventsApi.getMyTicket(widget.eventId),
      ]);
      if (!mounted) return;
      setState(() {
        _event = results[0] as Event;
        _myTicket = results[1] as Ticket?;
        _isLoading = false;
        _isLoadingTicket = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Failed to load event';
        _isLoading = false;
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
    final sponsors = event.sponsors ?? [];

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

                // Sponsors
                if (sponsors.isNotEmpty) ...[
                  const Text('Sponsors', style: AppTypography.titleLarge),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: sponsors.map((s) => _SponsorChip(sponsor: s)).toList(),
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

                // Check-in section (only for published, non-past events)
                if (event.isPublished && !event.isPast) ...[
                  if (_isLoadingTicket)
                    const Center(child: CircularProgressIndicator())
                  else if (_myTicket != null && _myTicket!.isCheckedIn)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 8),
                          Text(
                            'Checked In',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (_myTicket != null && _myTicket!.status == TicketStatus.purchased)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await context.push('/events/${widget.eventId}/checkin');
                          // Reload to update ticket status after check-in
                          _loadEvent();
                        },
                        icon: const Icon(Icons.qr_code),
                        label: const Text('Check In'),
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'You need a ticket to check in to this event.',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ]),
            ),
          ),
        ],
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

/// Sponsor chip showing logo + name.
class _SponsorChip extends StatelessWidget {
  final EventSponsor sponsor;

  const _SponsorChip({required this.sponsor});

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
          if (sponsor.logoUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                sponsor.logoUrl!,
                width: 24,
                height: 24,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.business, size: 20),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(sponsor.name, style: AppTypography.labelMedium.copyWith(color: AppColors.chipText)),
        ],
      ),
    );
  }
}
