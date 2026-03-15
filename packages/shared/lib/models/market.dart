import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'market.g.dart';

/// Market model — a geographic region where events and customers operate.
@JsonSerializable(fieldRename: FieldRename.snake)
class Market extends Equatable {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? timezone;
  final bool isActive;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Only present on admin list endpoint
  final int? eventCount;

  const Market({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.timezone,
    this.isActive = true,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
    this.eventCount,
  });

  factory Market.fromJson(Map<String, dynamic> json) =>
      _$MarketFromJson(json);

  Map<String, dynamic> toJson() => _$MarketToJson(this);

  Market copyWith({
    String? id,
    String? name,
    String? slug,
    String? description,
    String? timezone,
    bool? isActive,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? eventCount,
  }) {
    return Market(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      timezone: timezone ?? this.timezone,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      eventCount: eventCount ?? this.eventCount,
    );
  }

  @override
  List<Object?> get props => [
        id, name, slug, description, timezone,
        isActive, sortOrder, createdAt, updatedAt, eventCount,
      ];
}
