import 'api_client.dart';
import '../models/user.dart';
import '../models/event.dart';
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

  // Dashboard
  Future<DashboardStats> getDashboardStats() async {
    final response = await _client.get<Map<String, dynamic>>('/admin/dashboard');
    return DashboardStats.fromJson(response['stats'] as Map<String, dynamic>);
  }

  // User Management
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

  // Event Management
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

  Future<Event> createEvent({
    required String name,
    required String venueId,
    required DateTime startTime,
    required DateTime endTime,
    String? description,
    int? capacity,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/admin/events',
      body: {
        'name': name,
        'venueId': venueId,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        if (description != null) 'description': description,
        if (capacity != null) 'capacity': capacity,
      },
    );
    return Event.fromJson(response['event'] as Map<String, dynamic>);
  }

  Future<Event> updateEvent(String id, {
    String? name,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    EventStatus? status,
    int? capacity,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (description != null) body['description'] = description;
    if (startTime != null) body['startTime'] = startTime.toIso8601String();
    if (endTime != null) body['endTime'] = endTime.toIso8601String();
    if (status != null) body['status'] = status.name;
    if (capacity != null) body['capacity'] = capacity;

    final response = await _client.patch<Map<String, dynamic>>(
      '/admin/events/$id',
      body: body,
    );
    return Event.fromJson(response['event'] as Map<String, dynamic>);
  }

  // Sponsor Management
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

  // Discount Management
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

  // Vendor Management
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
}
