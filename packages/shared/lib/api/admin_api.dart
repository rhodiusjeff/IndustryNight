import 'api_client.dart';
import '../models/user.dart';
import '../models/event.dart';
import '../models/event_image.dart';
import '../models/ticket.dart';
import '../models/sponsor.dart';
import '../models/vendor.dart';
import '../models/discount.dart';
import '../constants/verification_status.dart';

/// Dashboard statistics
class DashboardStats {
  final int totalUsers;
  final int verifiedUsers;
  final int totalEvents;
  final int upcomingEvents;
  final int totalConnections;
  final int totalPosts;

  DashboardStats({
    required this.totalUsers,
    required this.verifiedUsers,
    required this.totalEvents,
    required this.upcomingEvents,
    required this.totalConnections,
    required this.totalPosts,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalUsers: json['total_users'] as int,
      verifiedUsers: json['verified_users'] as int,
      totalEvents: json['total_events'] as int,
      upcomingEvents: json['upcoming_events'] as int,
      totalConnections: json['total_connections'] as int,
      totalPosts: json['total_posts'] as int,
    );
  }
}

/// API client for admin endpoints
class AdminApi {
  final ApiClient _client;

  AdminApi(this._client);

  // ----------------------------------------------------------------
  // Dashboard
  // ----------------------------------------------------------------

  Future<DashboardStats> getDashboardStats() async {
    final response = await _client.get<Map<String, dynamic>>('/admin/dashboard');
    return DashboardStats.fromJson(response['stats'] as Map<String, dynamic>);
  }

  // ----------------------------------------------------------------
  // User Management
  // ----------------------------------------------------------------

  Future<List<User>> getUsers({
    String? query,
    UserRole? role,
    VerificationStatus? verificationStatus,
    int limit = 50,
    int offset = 0,
  }) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (query != null) queryParams['q'] = query;
    if (role != null) queryParams['role'] = role.name;
    if (verificationStatus != null) {
      queryParams['verificationStatus'] = verificationStatus.name;
    }

    final response = await _client.get<Map<String, dynamic>>(
      '/admin/users',
      queryParams: queryParams,
    );

    return (response['users'] as List)
        .map((u) => User.fromJson(u as Map<String, dynamic>))
        .toList();
  }

  Future<User> updateUser(String id, {
    UserRole? role,
    bool? banned,
    VerificationStatus? verificationStatus,
  }) async {
    final body = <String, dynamic>{};
    if (role != null) body['role'] = role.name;
    if (banned != null) body['banned'] = banned;
    if (verificationStatus != null) {
      body['verificationStatus'] = verificationStatus.name;
    }

    final response = await _client.patch<Map<String, dynamic>>(
      '/admin/users/$id',
      body: body,
    );
    return User.fromJson(response['user'] as Map<String, dynamic>);
  }

  Future<User> addUser({
    required String phone,
    String? name,
    String? email,
    UserRole role = UserRole.user,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/admin/users',
      body: {
        'phone': phone,
        if (name != null) 'name': name,
        if (email != null) 'email': email,
        'role': role.name,
      },
    );
    return User.fromJson(response['user'] as Map<String, dynamic>);
  }

  // ----------------------------------------------------------------
  // Event Management
  // ----------------------------------------------------------------

  Future<List<Event>> getEvents({
    EventStatus? status,
    int limit = 50,
    int offset = 0,
  }) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (status != null) queryParams['status'] = status.name;

    final response = await _client.get<Map<String, dynamic>>(
      '/admin/events',
      queryParams: queryParams,
    );

    return (response['events'] as List)
        .map((e) => Event.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetch a single event with full images[] and sponsors[] arrays
  Future<Event> getEvent(String id) async {
    final response = await _client.get<Map<String, dynamic>>('/admin/events/$id');
    return Event.fromJson(response['event'] as Map<String, dynamic>);
  }

  Future<Event> createEvent({
    required String name,
    required DateTime startTime,
    required DateTime endTime,
    String? venueName,
    String? venueAddress,
    String? description,
    int? capacity,
    String? poshEventId,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/admin/events',
      body: {
        'name': name,
        'startTime': startTime.toUtc().toIso8601String(),
        'endTime': endTime.toUtc().toIso8601String(),
        if (venueName != null) 'venueName': venueName,
        if (venueAddress != null) 'venueAddress': venueAddress,
        if (description != null) 'description': description,
        if (capacity != null) 'capacity': capacity,
        if (poshEventId != null) 'poshEventId': poshEventId,
      },
    );
    return Event.fromJson(response['event'] as Map<String, dynamic>);
  }

  Future<Event> updateEvent(String id, {
    String? name,
    String? description,
    String? venueName,
    String? venueAddress,
    DateTime? startTime,
    DateTime? endTime,
    String? poshEventId,
    EventStatus? status,
    int? capacity,
  }) async {
    final body = <String, dynamic>{};
    if (name != null)         body['name'] = name;
    if (description != null)  body['description'] = description;
    if (venueName != null)    body['venueName'] = venueName;
    if (venueAddress != null) body['venueAddress'] = venueAddress;
    if (startTime != null)    body['startTime'] = startTime.toUtc().toIso8601String();
    if (endTime != null)      body['endTime'] = endTime.toUtc().toIso8601String();
    if (poshEventId != null)  body['poshEventId'] = poshEventId;
    if (status != null)       body['status'] = status.name;
    if (capacity != null)     body['capacity'] = capacity;

    final response = await _client.patch<Map<String, dynamic>>(
      '/admin/events/$id',
      body: body,
    );
    return Event.fromJson(response['event'] as Map<String, dynamic>);
  }

  /// Permanently deletes a draft event. Throws [ApiException] if the event
  /// is not in draft status.
  Future<void> deleteEvent(String id) async {
    await _client.delete('/admin/events/$id');
  }

  // ----------------------------------------------------------------
  // Event Images
  // ----------------------------------------------------------------

  /// Upload an image for an event. [fileBytes] is the raw file data,
  /// [filename] is used for content-type detection (e.g. "photo.jpg").
  Future<EventImage> uploadEventImage(
    String eventId, {
    required List<int> fileBytes,
    required String filename,
    String? mimeType,
  }) async {
    final response = await _client.uploadFile<Map<String, dynamic>>(
      '/admin/events/$eventId/images',
      fieldName: 'image',
      fileBytes: fileBytes,
      filename: filename,
      mimeType: mimeType,
    );
    return EventImage.fromJson(response['image'] as Map<String, dynamic>);
  }

  Future<void> setHeroImage(String eventId, String imageId) async {
    await _client.patch<Map<String, dynamic>>(
      '/admin/events/$eventId/images/$imageId/hero',
    );
  }

  Future<void> deleteEventImage(String eventId, String imageId) async {
    await _client.delete('/admin/events/$eventId/images/$imageId');
  }

  // ----------------------------------------------------------------
  // Image Catalog
  // ----------------------------------------------------------------

  Future<List<EventImage>> getImages({int limit = 50, int offset = 0}) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/admin/images',
      queryParams: {
        'limit': limit.toString(),
        'offset': offset.toString(),
      },
    );
    return (response['images'] as List)
        .map((i) => EventImage.fromJson(i as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteImage(String imageId) async {
    await _client.delete('/admin/images/$imageId');
  }

  // ----------------------------------------------------------------
  // Event Sponsors
  // ----------------------------------------------------------------

  Future<void> addEventSponsor(String eventId, String sponsorId) async {
    await _client.post<Map<String, dynamic>>(
      '/admin/events/$eventId/sponsors',
      body: {'sponsorId': sponsorId},
    );
  }

  Future<void> removeEventSponsor(String eventId, String sponsorId) async {
    await _client.delete('/admin/events/$eventId/sponsors/$sponsorId');
  }

  // ----------------------------------------------------------------
  // Sponsor Management
  // ----------------------------------------------------------------

  Future<List<Sponsor>> getSponsors({int limit = 50, int offset = 0}) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/admin/sponsors',
      queryParams: {
        'limit': limit.toString(),
        'offset': offset.toString(),
      },
    );

    return (response['sponsors'] as List)
        .map((s) => Sponsor.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  Future<Sponsor> createSponsor({
    required String name,
    String? description,
    String? website,
    SponsorTier tier = SponsorTier.bronze,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/admin/sponsors',
      body: {
        'name': name,
        if (description != null) 'description': description,
        if (website != null) 'website': website,
        'tier': tier.name,
      },
    );
    return Sponsor.fromJson(response['sponsor'] as Map<String, dynamic>);
  }

  Future<Sponsor> updateSponsor(String id, {
    String? name,
    String? description,
    String? website,
    SponsorTier? tier,
    bool? isActive,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (description != null) body['description'] = description;
    if (website != null) body['website'] = website;
    if (tier != null) body['tier'] = tier.name;
    if (isActive != null) body['isActive'] = isActive;

    final response = await _client.patch<Map<String, dynamic>>(
      '/admin/sponsors/$id',
      body: body,
    );
    return Sponsor.fromJson(response['sponsor'] as Map<String, dynamic>);
  }

  // ----------------------------------------------------------------
  // Discount Management
  // ----------------------------------------------------------------

  Future<List<Discount>> getDiscounts(String sponsorId) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/admin/sponsors/$sponsorId/discounts',
    );

    return (response['discounts'] as List)
        .map((d) => Discount.fromJson(d as Map<String, dynamic>))
        .toList();
  }

  Future<Discount> createDiscount({
    required String sponsorId,
    required String title,
    String? description,
    DiscountType type = DiscountType.percentage,
    double? value,
    String? code,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/admin/sponsors/$sponsorId/discounts',
      body: {
        'title': title,
        if (description != null) 'description': description,
        'type': type.name,
        if (value != null) 'value': value,
        if (code != null) 'code': code,
        if (startDate != null) 'startDate': startDate.toIso8601String(),
        if (endDate != null) 'endDate': endDate.toIso8601String(),
      },
    );
    return Discount.fromJson(response['discount'] as Map<String, dynamic>);
  }

  // ----------------------------------------------------------------
  // Vendor Management
  // ----------------------------------------------------------------

  Future<List<Vendor>> getVendors({int limit = 50, int offset = 0}) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/admin/vendors',
      queryParams: {
        'limit': limit.toString(),
        'offset': offset.toString(),
      },
    );

    return (response['vendors'] as List)
        .map((v) => Vendor.fromJson(v as Map<String, dynamic>))
        .toList();
  }

  Future<Vendor> createVendor({
    required String name,
    String? description,
    String? website,
    String? contactEmail,
    VendorCategory category = VendorCategory.other,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/admin/vendors',
      body: {
        'name': name,
        if (description != null) 'description': description,
        if (website != null) 'website': website,
        if (contactEmail != null) 'contactEmail': contactEmail,
        'category': category.name,
      },
    );
    return Vendor.fromJson(response['vendor'] as Map<String, dynamic>);
  }

  Future<Vendor> updateVendor(String id, {
    String? name,
    String? description,
    String? website,
    String? contactEmail,
    VendorCategory? category,
    bool? isActive,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (description != null) body['description'] = description;
    if (website != null) body['website'] = website;
    if (contactEmail != null) body['contactEmail'] = contactEmail;
    if (category != null) body['category'] = category.name;
    if (isActive != null) body['isActive'] = isActive;

    final response = await _client.patch<Map<String, dynamic>>(
      '/admin/vendors/$id',
      body: body,
    );
    return Vendor.fromJson(response['vendor'] as Map<String, dynamic>);
  }

  // ----------------------------------------------------------------
  // Ticket Management
  // ----------------------------------------------------------------

  /// Get all tickets across all events with optional filters.
  Future<List<Ticket>> getAllTickets({
    TicketStatus? status,
    String? eventId,
    String? userId,
    String? query,
    int limit = 50,
    int offset = 0,
  }) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (status != null) queryParams['status'] = status.name;
    if (eventId != null) queryParams['eventId'] = eventId;
    if (userId != null) queryParams['userId'] = userId;
    if (query != null) queryParams['q'] = query;

    final response = await _client.get<Map<String, dynamic>>(
      '/admin/tickets',
      queryParams: queryParams,
    );
    return (response['tickets'] as List)
        .map((t) => Ticket.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  Future<List<Ticket>> getEventTickets(String eventId, {
    TicketStatus? status,
    int limit = 50,
    int offset = 0,
  }) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (status != null) queryParams['status'] = status.name;

    final response = await _client.get<Map<String, dynamic>>(
      '/admin/events/$eventId/tickets',
      queryParams: queryParams,
    );
    return (response['tickets'] as List)
        .map((t) => Ticket.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  Future<Ticket> issueTicket(String eventId, {
    required String userId,
    String ticketType = 'admin',
    double price = 0,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/admin/events/$eventId/tickets',
      body: {
        'userId': userId,
        'ticketType': ticketType,
        'price': price,
      },
    );
    return Ticket.fromJson(response['ticket'] as Map<String, dynamic>);
  }

  Future<void> deleteTicket(String eventId, String ticketId) async {
    await _client.delete('/admin/events/$eventId/tickets/$ticketId');
  }

  Future<Ticket> refundTicket(String eventId, String ticketId) async {
    final response = await _client.patch<Map<String, dynamic>>(
      '/admin/events/$eventId/tickets/$ticketId/refund',
    );
    return Ticket.fromJson(response['ticket'] as Map<String, dynamic>);
  }
}
