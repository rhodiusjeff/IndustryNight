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

/// Lightweight sponsor summary embedded in event detail responses.
/// Uses manual fromJson — no build_runner needed for this type.
class EventSponsor {
  final String id;
  final String name;
  final String tier;
  final String? logoUrl;

  const EventSponsor({
    required this.id,
    required this.name,
    required this.tier,
    this.logoUrl,
  });

  factory EventSponsor.fromJson(Map<String, dynamic> json) => EventSponsor(
        id: json['id'] as String,
        name: json['name'] as String,
        tier: json['tier'] as String,
        logoUrl: json['logo_url'] as String?,
      );
}

/// Event model representing an Industry Night event
@JsonSerializable(fieldRename: FieldRename.snake)
class Event extends Equatable {
  final String id;
  final String name;
  final String? description;

  /// Legacy FK — nullable, not populated for new events (venue_name/address used instead)
  final String? venueId;
  final String? venueName;
  final String? venueAddress;

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

  /// Sponsor count — populated on list endpoints
  final int sponsorCount;

  /// Full image list — only populated on detail endpoint (GET /admin/events/:id)
  @JsonKey(fromJson: _imagesFromJson, toJson: _imagesToJson)
  final List<EventImage>? images;

  /// Sponsor summaries — only populated on detail endpoint (GET /admin/events/:id)
  @JsonKey(fromJson: _sponsorsFromJson, toJson: _sponsorsToJson)
  final List<EventSponsor>? sponsors;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Event({
    required this.id,
    required this.name,
    this.description,
    this.venueId,
    this.venueName,
    this.venueAddress,
    required this.startTime,
    required this.endTime,
    this.activationCode,
    this.poshEventId,
    this.status = EventStatus.draft,
    this.capacity,
    this.attendeeCount = 0,
    this.heroImageUrl,
    this.imageCount = 0,
    this.sponsorCount = 0,
    this.images,
    this.sponsors,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Event.fromJson(Map<String, dynamic> json) => _$EventFromJson(json);

  Map<String, dynamic> toJson() => _$EventToJson(this);

  Event copyWith({
    String? id,
    String? name,
    String? description,
    String? venueId,
    String? venueName,
    String? venueAddress,
    DateTime? startTime,
    DateTime? endTime,
    String? activationCode,
    String? poshEventId,
    EventStatus? status,
    int? capacity,
    int? attendeeCount,
    String? heroImageUrl,
    int? imageCount,
    int? sponsorCount,
    List<EventImage>? images,
    List<EventSponsor>? sponsors,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Event(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      venueId: venueId ?? this.venueId,
      venueName: venueName ?? this.venueName,
      venueAddress: venueAddress ?? this.venueAddress,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      activationCode: activationCode ?? this.activationCode,
      poshEventId: poshEventId ?? this.poshEventId,
      status: status ?? this.status,
      capacity: capacity ?? this.capacity,
      attendeeCount: attendeeCount ?? this.attendeeCount,
      heroImageUrl: heroImageUrl ?? this.heroImageUrl,
      imageCount: imageCount ?? this.imageCount,
      sponsorCount: sponsorCount ?? this.sponsorCount,
      images: images ?? this.images,
      sponsors: sponsors ?? this.sponsors,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isPublished => status == EventStatus.published;
  bool get isCancelled => status == EventStatus.cancelled;
  bool get isUpcoming => startTime.isAfter(DateTime.now());
  bool get isOngoing {
    final now = DateTime.now();
    return now.isAfter(startTime) && now.isBefore(endTime);
  }
  bool get isPast => endTime.isBefore(DateTime.now());
  bool get hasCapacity => capacity == null || attendeeCount < capacity!;

  /// Hero image URL from list endpoints, or first image from detail endpoint
  String? get primaryImageUrl => heroImageUrl ?? images?.firstOrNull?.url;

  @override
  List<Object?> get props => [
        id, name, description,
        venueId, venueName, venueAddress,
        startTime, endTime,
        activationCode, poshEventId,
        status, capacity, attendeeCount,
        heroImageUrl, imageCount, sponsorCount,
        images, sponsors,
        createdAt, updatedAt,
      ];
}

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

List<EventSponsor>? _sponsorsFromJson(dynamic value) {
  if (value == null) return null;
  return (value as List)
      .map((e) => EventSponsor.fromJson(e as Map<String, dynamic>))
      .toList();
}

dynamic _sponsorsToJson(List<EventSponsor>? sponsors) => sponsors
    ?.map((s) => {
          'id': s.id,
          'name': s.name,
          'tier': s.tier,
          'logo_url': s.logoUrl,
        })
    .toList();
