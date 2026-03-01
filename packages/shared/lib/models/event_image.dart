import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'event_image.g.dart';

/// An image attached to an event, stored in S3
@JsonSerializable(fieldRename: FieldRename.snake)
class EventImage extends Equatable {
  final String id;
  final String eventId;
  final String url;
  final int sortOrder;
  final DateTime uploadedAt;

  /// Only present when returned from the image catalog endpoint
  final String? eventName;

  const EventImage({
    required this.id,
    required this.eventId,
    required this.url,
    required this.sortOrder,
    required this.uploadedAt,
    this.eventName,
  });

  factory EventImage.fromJson(Map<String, dynamic> json) =>
      _$EventImageFromJson(json);

  Map<String, dynamic> toJson() => _$EventImageToJson(this);

  @override
  List<Object?> get props => [id, eventId, url, sortOrder, uploadedAt, eventName];
}
