import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

import 'event_image.dart';

part 'event.g.dart';

/// Status of an event
enum EventStatus {
  draft,
  published,
  cancelled,
  completed,
}

/// Lightweight partner summary embedded in event detail responses.
/// A partner is a customer linked to the event via a customer_product.
/// Uses manual fromJson — no build_runner needed for this type.
class EventPartner {
  final String id; // customer_product ID
  final String customerId;
  final String name;
  final String? logoUrl;
  final String productType; // sponsorship, vendor_space, data_product
  final String? tier;
  final String? vendorCategory;

  const EventPartner({
    required this.id,
    required this.customerId,
    required this.name,
    this.logoUrl,
    required this.productType,
    this.tier,
    this.vendorCategory,
  });

  factory EventPartner.fromJson(Map<String, dynamic> json) => EventPartner(
        id: json['id'] as String,
        customerId: json['customer_id'] as String,
        name: json['name'] as String,
        logoUrl: json['logo_url'] as String?,
        productType: json['product_type'] as String? ?? 'sponsorship',
        tier: json['tier'] as String?,
        vendorCategory: json['vendor_category'] as String?,
      );

  bool get isSponsor => productType == 'sponsorship';
  bool get isVendor => productType == 'vendor_space';
}

/// Event model representing an Industry Night event
@JsonSerializable(fieldRename: FieldRename.snake)
class Event extends Equatable {
  final String id;
  final String name;
  final String? description;

  final String? venueName;
  final String? venueAddress;

  /// Market association — set via admin, required before publishing
  final String? marketId;
  final String? marketName;

  final DateTime startTime;
  final DateTime endTime;

  final String? activationCode;
  final String? poshEventId;

  @JsonKey(fromJson: _eventStatusFromJson, toJson: _eventStatusToJson)
  final EventStatus status;

  final int? capacity;
  final int attendeeCount;

  /// Hero image URL — populated on list endpoints (first image, sort_order 0)
  final String? heroImageUrl;

  /// Image count — populated on list endpoints
  final int imageCount;

  /// Partner count — populated on list endpoints (was sponsorCount)
  final int partnerCount;

  /// Full image list — only populated on detail endpoint (GET /admin/events/:id)
  @JsonKey(fromJson: _imagesFromJson, toJson: _imagesToJson)
  final List<EventImage>? images;

  /// Partner summaries — only populated on detail endpoint (GET /admin/events/:id)
  @JsonKey(fromJson: _partnersFromJson, toJson: _partnersToJson)
  final List<EventPartner>? partners;

  /// Ticket counts — only populated on admin detail endpoint
  final int? ticketCount;
  final int? ticketsPurchased;
  final int? ticketsCheckedIn;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Event({
    required this.id,
    required this.name,
    this.description,
    this.venueName,
    this.venueAddress,
    this.marketId,
    this.marketName,
    required this.startTime,
    required this.endTime,
    this.activationCode,
    this.poshEventId,
    this.status = EventStatus.draft,
    this.capacity,
    this.attendeeCount = 0,
    this.heroImageUrl,
    this.imageCount = 0,
    this.partnerCount = 0,
    this.images,
    this.partners,
    this.ticketCount,
    this.ticketsPurchased,
    this.ticketsCheckedIn,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Event.fromJson(Map<String, dynamic> json) => _$EventFromJson(json);

  Map<String, dynamic> toJson() => _$EventToJson(this);

  Event copyWith({
    String? id,
    String? name,
    String? description,
    String? venueName,
    String? venueAddress,
    String? marketId,
    String? marketName,
    DateTime? startTime,
    DateTime? endTime,
    String? activationCode,
    String? poshEventId,
    EventStatus? status,
    int? capacity,
    int? attendeeCount,
    String? heroImageUrl,
    int? imageCount,
    int? partnerCount,
    List<EventImage>? images,
    List<EventPartner>? partners,
    int? ticketCount,
    int? ticketsPurchased,
    int? ticketsCheckedIn,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Event(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      venueName: venueName ?? this.venueName,
      venueAddress: venueAddress ?? this.venueAddress,
      marketId: marketId ?? this.marketId,
      marketName: marketName ?? this.marketName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      activationCode: activationCode ?? this.activationCode,
      poshEventId: poshEventId ?? this.poshEventId,
      status: status ?? this.status,
      capacity: capacity ?? this.capacity,
      attendeeCount: attendeeCount ?? this.attendeeCount,
      heroImageUrl: heroImageUrl ?? this.heroImageUrl,
      imageCount: imageCount ?? this.imageCount,
      partnerCount: partnerCount ?? this.partnerCount,
      images: images ?? this.images,
      partners: partners ?? this.partners,
      ticketCount: ticketCount ?? this.ticketCount,
      ticketsPurchased: ticketsPurchased ?? this.ticketsPurchased,
      ticketsCheckedIn: ticketsCheckedIn ?? this.ticketsCheckedIn,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isPublished => status == EventStatus.published;
  bool get isCancelled => status == EventStatus.cancelled;
  bool get isUpcoming => _asLocal(startTime).isAfter(DateTime.now());
  bool get isOngoing {
    final now = DateTime.now();
    return now.isAfter(_asLocal(startTime)) && now.isBefore(_asLocal(endTime));
  }
  bool get isPast => _asLocal(endTime).isBefore(DateTime.now());
  bool get hasCapacity => capacity == null || attendeeCount < capacity!;

  /// Hero image URL from list endpoints, or first image from detail endpoint
  String? get primaryImageUrl => heroImageUrl ?? images?.firstOrNull?.url;

  /// Convenience: sponsors among partners
  List<EventPartner> get sponsors =>
      partners?.where((p) => p.isSponsor).toList() ?? [];

  /// Convenience: vendors among partners
  List<EventPartner> get vendors =>
      partners?.where((p) => p.isVendor).toList() ?? [];

  @override
  List<Object?> get props => [
        id, name, description,
        venueName, venueAddress,
        marketId, marketName,
        startTime, endTime,
        activationCode, poshEventId,
        status, capacity, attendeeCount,
        heroImageUrl, imageCount, partnerCount,
        images, partners,
        ticketCount, ticketsPurchased, ticketsCheckedIn,
        createdAt, updatedAt,
      ];
}

/// Admin stores local times without UTC conversion, so the DB holds
/// local-time-as-UTC. Re-interpret UTC components as local for correct
/// epoch comparison with [DateTime.now()].
DateTime _asLocal(DateTime dt) => DateTime(
      dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second, dt.millisecond);

EventStatus _eventStatusFromJson(String value) {
  return EventStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => EventStatus.draft,
  );
}

String _eventStatusToJson(EventStatus status) => status.name;

List<EventImage>? _imagesFromJson(dynamic value) {
  if (value == null) return null;
  return (value as List)
      .map((e) => EventImage.fromJson(e as Map<String, dynamic>))
      .toList();
}

dynamic _imagesToJson(List<EventImage>? images) =>
    images?.map((e) => e.toJson()).toList();

List<EventPartner>? _partnersFromJson(dynamic value) {
  if (value == null) return null;
  return (value as List)
      .map((e) => EventPartner.fromJson(e as Map<String, dynamic>))
      .toList();
}

dynamic _partnersToJson(List<EventPartner>? partners) => partners
    ?.map((p) => {
          'id': p.id,
          'customer_id': p.customerId,
          'name': p.name,
          'logo_url': p.logoUrl,
          'product_type': p.productType,
          'tier': p.tier,
          'vendor_category': p.vendorCategory,
        })
    .toList();
