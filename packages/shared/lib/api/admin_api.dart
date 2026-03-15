import 'api_client.dart';
import '../models/user.dart';
import '../models/event.dart';
import '../models/event_image.dart';
import '../models/ticket.dart';
import '../models/market.dart';
import '../models/customer.dart';
import '../models/customer_contact.dart';
import '../models/customer_media_item.dart';
import '../models/product.dart';
import '../models/customer_product.dart';
import '../models/discount.dart';
import '../models/discount_redemption.dart';
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
  // Markets
  // ----------------------------------------------------------------

  Future<List<Market>> getMarkets() async {
    final response = await _client.get<Map<String, dynamic>>('/admin/markets');
    return (response['markets'] as List)
        .map((e) => Market.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Market> createMarket({
    required String name,
    String? description,
    String? timezone,
    int sortOrder = 0,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/admin/markets',
      body: {
        'name': name,
        if (description != null) 'description': description,
        if (timezone != null) 'timezone': timezone,
        'sortOrder': sortOrder,
      },
    );
    return Market.fromJson(response['market'] as Map<String, dynamic>);
  }

  Future<Market> updateMarket(
    String id, {
    String? name,
    String? description,
    String? timezone,
    bool? isActive,
    int? sortOrder,
  }) async {
    final response = await _client.patch<Map<String, dynamic>>(
      '/admin/markets/$id',
      body: {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (timezone != null) 'timezone': timezone,
        if (isActive != null) 'isActive': isActive,
        if (sortOrder != null) 'sortOrder': sortOrder,
      },
    );
    return Market.fromJson(response['market'] as Map<String, dynamic>);
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

  /// Fetch a single event with full images[] and partners[] arrays
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
    String? marketId,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/admin/events',
      body: {
        'name': name,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        if (venueName != null) 'venueName': venueName,
        if (venueAddress != null) 'venueAddress': venueAddress,
        if (description != null) 'description': description,
        if (capacity != null) 'capacity': capacity,
        if (poshEventId != null) 'poshEventId': poshEventId,
        if (marketId != null) 'marketId': marketId,
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
    String? marketId,
  }) async {
    final body = <String, dynamic>{};
    if (name != null)         body['name'] = name;
    if (description != null)  body['description'] = description;
    if (venueName != null)    body['venueName'] = venueName;
    if (venueAddress != null) body['venueAddress'] = venueAddress;
    if (startTime != null)    body['startTime'] = startTime.toIso8601String();
    if (endTime != null)      body['endTime'] = endTime.toIso8601String();
    if (poshEventId != null)  body['poshEventId'] = poshEventId;
    if (status != null)       body['status'] = status.name;
    if (capacity != null)     body['capacity'] = capacity;
    if (marketId != null)     body['marketId'] = marketId;

    final response = await _client.patch<Map<String, dynamic>>(
      '/admin/events/$id',
      body: body,
    );
    return Event.fromJson(response['event'] as Map<String, dynamic>);
  }

  Future<void> deleteEvent(String id) async {
    await _client.delete('/admin/events/$id');
  }

  // ----------------------------------------------------------------
  // Event Images
  // ----------------------------------------------------------------

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
  // Event Partners (customer-products linked to events)
  // ----------------------------------------------------------------

  Future<void> addEventPartner(String eventId, {
    required String customerId,
    required String productId,
    int? pricePaidCents,
    String? notes,
  }) async {
    await _client.post<Map<String, dynamic>>(
      '/admin/events/$eventId/partners',
      body: {
        'customerId': customerId,
        'productId': productId,
        if (pricePaidCents != null) 'pricePaidCents': pricePaidCents,
        if (notes != null) 'notes': notes,
      },
    );
  }

  Future<void> removeEventPartner(String eventId, String customerProductId) async {
    await _client.delete('/admin/events/$eventId/partners/$customerProductId');
  }

  // ----------------------------------------------------------------
  // Customer Management
  // ----------------------------------------------------------------

  Future<List<Customer>> getCustomers({
    String? query,
    String? hasProductType,
    int limit = 50,
    int offset = 0,
  }) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (query != null) queryParams['q'] = query;
    if (hasProductType != null) queryParams['hasProductType'] = hasProductType;

    final response = await _client.get<Map<String, dynamic>>(
      '/admin/customers',
      queryParams: queryParams,
    );
    return (response['customers'] as List)
        .map((c) => Customer.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  Future<Customer> getCustomer(String id) async {
    final response = await _client.get<Map<String, dynamic>>('/admin/customers/$id');
    return Customer.fromJson(response['customer'] as Map<String, dynamic>);
  }

  Future<Customer> createCustomer({
    required String name,
    String? description,
    String? logoUrl,
    String? website,
    String? contactEmail,
    String? contactPhone,
    String? notes,
    List<String>? marketIds,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/admin/customers',
      body: {
        'name': name,
        if (description != null) 'description': description,
        if (logoUrl != null) 'logoUrl': logoUrl,
        if (website != null) 'website': website,
        if (contactEmail != null) 'contactEmail': contactEmail,
        if (contactPhone != null) 'contactPhone': contactPhone,
        if (notes != null) 'notes': notes,
        if (marketIds != null) 'marketIds': marketIds,
      },
    );
    return Customer.fromJson(response['customer'] as Map<String, dynamic>);
  }

  Future<Customer> updateCustomer(String id, {
    String? name,
    String? description,
    String? logoUrl,
    String? website,
    String? contactEmail,
    String? contactPhone,
    String? notes,
    bool? isActive,
    List<String>? marketIds,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (description != null) body['description'] = description;
    if (logoUrl != null) body['logoUrl'] = logoUrl;
    if (website != null) body['website'] = website;
    if (contactEmail != null) body['contactEmail'] = contactEmail;
    if (contactPhone != null) body['contactPhone'] = contactPhone;
    if (notes != null) body['notes'] = notes;
    if (isActive != null) body['isActive'] = isActive;
    if (marketIds != null) body['marketIds'] = marketIds;

    final response = await _client.patch<Map<String, dynamic>>(
      '/admin/customers/$id',
      body: body,
    );
    return Customer.fromJson(response['customer'] as Map<String, dynamic>);
  }

  Future<void> deleteCustomer(String id) async {
    await _client.delete('/admin/customers/$id');
  }

  // ----------------------------------------------------------------
  // Customer Contacts
  // ----------------------------------------------------------------

  Future<List<CustomerContact>> getContacts(String customerId) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/admin/customers/$customerId/contacts',
    );
    return (response['contacts'] as List)
        .map((c) => CustomerContact.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  Future<CustomerContact> addContact(String customerId, {
    required String name,
    String? email,
    String? phone,
    ContactRole role = ContactRole.other,
    String? title,
    bool isPrimary = false,
    String? notes,
  }) async {
    final roleStr = switch (role) {
      ContactRole.primary => 'primary',
      ContactRole.billing => 'billing',
      ContactRole.decisionMaker => 'decision_maker',
      ContactRole.other => 'other',
    };
    final response = await _client.post<Map<String, dynamic>>(
      '/admin/customers/$customerId/contacts',
      body: {
        'name': name,
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
        'role': roleStr,
        if (title != null) 'title': title,
        'isPrimary': isPrimary,
        if (notes != null) 'notes': notes,
      },
    );
    return CustomerContact.fromJson(response['contact'] as Map<String, dynamic>);
  }

  Future<CustomerContact> updateContact(
    String customerId,
    String contactId, {
    String? name,
    String? email,
    String? phone,
    ContactRole? role,
    String? title,
    bool? isPrimary,
    String? notes,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (email != null) body['email'] = email;
    if (phone != null) body['phone'] = phone;
    if (role != null) {
      body['role'] = switch (role) {
        ContactRole.primary => 'primary',
        ContactRole.billing => 'billing',
        ContactRole.decisionMaker => 'decision_maker',
        ContactRole.other => 'other',
      };
    }
    if (title != null) body['title'] = title;
    if (isPrimary != null) body['isPrimary'] = isPrimary;
    if (notes != null) body['notes'] = notes;

    final response = await _client.patch<Map<String, dynamic>>(
      '/admin/customers/$customerId/contacts/$contactId',
      body: body,
    );
    return CustomerContact.fromJson(response['contact'] as Map<String, dynamic>);
  }

  Future<void> deleteContact(String customerId, String contactId) async {
    await _client.delete('/admin/customers/$customerId/contacts/$contactId');
  }

  // ----------------------------------------------------------------
  // Customer Media (brand assets)
  // ----------------------------------------------------------------

  Future<CustomerMediaItem> uploadCustomerMedia(
    String customerId, {
    required List<int> fileBytes,
    required String filename,
    String? mimeType,
    String placement = 'other',
  }) async {
    final response = await _client.uploadFile<Map<String, dynamic>>(
      '/admin/customers/$customerId/media',
      fieldName: 'image',
      fileBytes: fileBytes,
      filename: filename,
      mimeType: mimeType,
      additionalFields: {'placement': placement},
    );
    return CustomerMediaItem.fromJson(response['media'] as Map<String, dynamic>);
  }

  Future<void> deleteCustomerMedia(String customerId, String mediaId) async {
    await _client.delete('/admin/customers/$customerId/media/$mediaId');
  }

  // ----------------------------------------------------------------
  // Product Catalog
  // ----------------------------------------------------------------

  Future<List<Product>> getProducts({
    ProductType? type,
    bool? isStandard,
    int limit = 50,
    int offset = 0,
  }) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (type != null) {
      switch (type) {
        case ProductType.vendorSpace:
          queryParams['type'] = 'vendor_space';
          break;
        case ProductType.dataProduct:
          queryParams['type'] = 'data_product';
          break;
        case ProductType.sponsorship:
          queryParams['type'] = 'sponsorship';
          break;
      }
    }
    if (isStandard != null) queryParams['isStandard'] = isStandard.toString();

    final response = await _client.get<Map<String, dynamic>>(
      '/admin/products',
      queryParams: queryParams,
    );
    return (response['products'] as List)
        .map((p) => Product.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  Future<Product> createProduct({
    required ProductType productType,
    required String name,
    String? description,
    int? basePriceCents,
    bool isStandard = true,
    Map<String, dynamic> config = const {},
  }) async {
    String typeStr;
    switch (productType) {
      case ProductType.vendorSpace:
        typeStr = 'vendor_space';
        break;
      case ProductType.dataProduct:
        typeStr = 'data_product';
        break;
      case ProductType.sponsorship:
        typeStr = 'sponsorship';
        break;
    }

    final response = await _client.post<Map<String, dynamic>>(
      '/admin/products',
      body: {
        'productType': typeStr,
        'name': name,
        if (description != null) 'description': description,
        if (basePriceCents != null) 'basePriceCents': basePriceCents,
        'isStandard': isStandard,
        'config': config,
      },
    );
    return Product.fromJson(response['product'] as Map<String, dynamic>);
  }

  Future<Product> updateProduct(String id, {
    String? name,
    String? description,
    int? basePriceCents,
    bool? isStandard,
    Map<String, dynamic>? config,
    bool? isActive,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (description != null) body['description'] = description;
    if (basePriceCents != null) body['basePriceCents'] = basePriceCents;
    if (isStandard != null) body['isStandard'] = isStandard;
    if (config != null) body['config'] = config;
    if (isActive != null) body['isActive'] = isActive;

    final response = await _client.patch<Map<String, dynamic>>(
      '/admin/products/$id',
      body: body,
    );
    return Product.fromJson(response['product'] as Map<String, dynamic>);
  }

  Future<void> deleteProduct(String id) async {
    await _client.delete('/admin/products/$id');
  }

  // ----------------------------------------------------------------
  // Customer Products (purchases)
  // ----------------------------------------------------------------

  Future<List<CustomerProduct>> getCustomerProducts(String customerId) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/admin/customers/$customerId/products',
    );
    return (response['products'] as List)
        .map((p) => CustomerProduct.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  Future<CustomerProduct> addCustomerProduct(String customerId, {
    required String productId,
    String? eventId,
    int? pricePaidCents,
    DateTime? startDate,
    DateTime? endDate,
    String? notes,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/admin/customers/$customerId/products',
      body: {
        'productId': productId,
        if (eventId != null) 'eventId': eventId,
        if (pricePaidCents != null) 'pricePaidCents': pricePaidCents,
        if (startDate != null) 'startDate': startDate.toIso8601String(),
        if (endDate != null) 'endDate': endDate.toIso8601String(),
        if (notes != null) 'notes': notes,
      },
    );
    return CustomerProduct.fromJson(response['customerProduct'] as Map<String, dynamic>);
  }

  Future<CustomerProduct> updateCustomerProduct(
    String customerId,
    String customerProductId, {
    CustomerProductStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    String? notes,
  }) async {
    final body = <String, dynamic>{};
    if (status != null) body['status'] = status.name;
    if (startDate != null) body['startDate'] = startDate.toIso8601String();
    if (endDate != null) body['endDate'] = endDate.toIso8601String();
    if (notes != null) body['notes'] = notes;

    final response = await _client.patch<Map<String, dynamic>>(
      '/admin/customers/$customerId/products/$customerProductId',
      body: body,
    );
    return CustomerProduct.fromJson(response['customerProduct'] as Map<String, dynamic>);
  }

  Future<void> removeCustomerProduct(String customerId, String customerProductId) async {
    await _client.delete('/admin/customers/$customerId/products/$customerProductId');
  }

  // ----------------------------------------------------------------
  // Discount Management
  // ----------------------------------------------------------------

  Future<List<Discount>> getDiscounts(String customerId) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/admin/customers/$customerId/discounts',
    );
    return (response['discounts'] as List)
        .map((d) => Discount.fromJson(d as Map<String, dynamic>))
        .toList();
  }

  Future<Discount> createDiscount({
    required String customerId,
    required String title,
    String? description,
    DiscountType type = DiscountType.percentage,
    double? value,
    String? code,
    String? terms,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/admin/customers/$customerId/discounts',
      body: {
        'title': title,
        if (description != null) 'description': description,
        'type': type.name,
        if (value != null) 'value': value,
        if (code != null) 'code': code,
        if (terms != null) 'terms': terms,
        if (startDate != null) 'startDate': startDate.toIso8601String(),
        if (endDate != null) 'endDate': endDate.toIso8601String(),
      },
    );
    return Discount.fromJson(response['discount'] as Map<String, dynamic>);
  }

  Future<Discount> updateDiscount(
    String customerId,
    String discountId, {
    String? title,
    String? description,
    DiscountType? type,
    double? value,
    String? code,
    String? terms,
    bool? isActive,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (description != null) body['description'] = description;
    if (type != null) body['type'] = type.name;
    if (value != null) body['value'] = value;
    if (code != null) body['code'] = code;
    if (terms != null) body['terms'] = terms;
    if (isActive != null) body['isActive'] = isActive;
    if (startDate != null) body['startDate'] = startDate.toIso8601String();
    if (endDate != null) body['endDate'] = endDate.toIso8601String();

    final response = await _client.patch<Map<String, dynamic>>(
      '/admin/customers/$customerId/discounts/$discountId',
      body: body,
    );
    return Discount.fromJson(response['discount'] as Map<String, dynamic>);
  }

  Future<void> deleteDiscount(String customerId, String discountId) async {
    await _client.delete('/admin/customers/$customerId/discounts/$discountId');
  }

  // ----------------------------------------------------------------
  // Discount Redemptions (admin analytics)
  // ----------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getCustomerRedemptions(String customerId) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/admin/customers/$customerId/redemptions',
    );
    return (response['redemptions'] as List).cast<Map<String, dynamic>>();
  }

  Future<List<DiscountRedemption>> getDiscountRedemptions(String discountId) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/admin/discounts/$discountId/redemptions',
    );
    return (response['redemptions'] as List)
        .map((r) => DiscountRedemption.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  // ----------------------------------------------------------------
  // Ticket Management
  // ----------------------------------------------------------------

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
