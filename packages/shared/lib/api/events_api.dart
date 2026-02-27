import 'api_client.dart';
import '../models/event.dart';
import '../models/ticket.dart';

/// API client for event endpoints
class EventsApi {
  final ApiClient _client;

  EventsApi(this._client);

  /// Get upcoming events
  Future<List<Event>> getUpcomingEvents({
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/events',
      queryParams: {
        'status': 'published',
        'upcoming': 'true',
        'limit': limit.toString(),
        'offset': offset.toString(),
      },
    );

    return (response['events'] as List)
        .map((e) => Event.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get event by ID
  Future<Event> getEvent(String id) async {
    final response = await _client.get<Map<String, dynamic>>('/events/$id');
    return Event.fromJson(response['event'] as Map<String, dynamic>);
  }

  /// Get user's tickets for an event
  Future<List<Ticket>> getEventTickets(String eventId) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/events/$eventId/tickets',
    );

    return (response['tickets'] as List)
        .map((t) => Ticket.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  /// Check if current user has a valid ticket for this event.
  /// Returns the ticket, or null if no valid ticket exists.
  Future<Ticket?> getMyTicket(String eventId) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/events/$eventId/my-ticket',
      );
      return Ticket.fromJson(response['ticket'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  /// Check in to an event with activation code
  Future<Ticket> checkIn(String eventId, String activationCode) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/events/$eventId/checkin',
      body: {'activationCode': activationCode},
    );
    return Ticket.fromJson(response['ticket'] as Map<String, dynamic>);
  }

  /// Get user's event history
  Future<List<Event>> getEventHistory({
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/users/me/events',
      queryParams: {
        'limit': limit.toString(),
        'offset': offset.toString(),
      },
    );

    return (response['events'] as List)
        .map((e) => Event.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
