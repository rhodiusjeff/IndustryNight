import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/theme/app_theme.dart';
import '../widgets/event_card.dart';

class EventsListScreen extends StatelessWidget {
  const EventsListScreen({super.key});

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
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5, // TODO: Replace with actual data
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: EventCard(
              eventId: 'event_$index',
              name: 'Industry Night ${index + 1}',
              venueName: 'The Grand Venue',
              date: DateTime.now().add(Duration(days: index * 7)),
              imageUrl: null,
              onTap: () => context.push('/events/event_$index'),
            ),
          );
        },
      ),
    );
  }
}
