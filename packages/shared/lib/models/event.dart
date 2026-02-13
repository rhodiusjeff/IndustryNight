import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'event.g.dart';

/// Status of an event
enum EventStatus {
  draft,
  published,
  cancelled,
  completed,
}

/// Event model representing an Industry Night event
@JsonSerializable()
class Event extends Equatable {
  final String id;
  final String name;
  final String? description;
  final String venueId;
  final String? venueName;
  final String? venueAddress;
  final DateTime startTime;
  final DateTime endTime;
  final String? imageUrl;
  final String? activationCode;
  final String? poshEventId;

  @JsonKey(fromJson: _eventStatusFromJson, toJson: _eventStatusToJson)
  final EventStatus status;

  final int? capacity;
  final int attendeeCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Event({
    required this.id,
    required this.name,
    this.description,
    required this.venueId,
    this.venueName,
    this.venueAddress,
    required this.startTime,
    required this.endTime,
    this.imageUrl,
    this.activationCode,
    this.poshEventId,
    this.status = EventStatus.draft,
    this.capacity,
    this.attendeeCount = 0,
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
    String? imageUrl,
    String? activationCode,
    String? poshEventId,
    EventStatus? status,
    int? capacity,
    int? attendeeCount,
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
      imageUrl: imageUrl ?? this.imageUrl,
      activationCode: activationCode ?? this.activationCode,
      poshEventId: poshEventId ?? this.poshEventId,
      status: status ?? this.status,
      capacity: capacity ?? this.capacity,
      attendeeCount: attendeeCount ?? this.attendeeCount,
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

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        venueId,
        venueName,
        venueAddress,
        startTime,
        endTime,
        imageUrl,
        activationCode,
        poshEventId,
        status,
        capacity,
        attendeeCount,
        createdAt,
        updatedAt,
      ];
}

EventStatus _eventStatusFromJson(String value) {
  return EventStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => EventStatus.draft,
  );
}

String _eventStatusToJson(EventStatus status) => status.name;
