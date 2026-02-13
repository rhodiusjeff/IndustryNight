import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'sponsor.g.dart';

/// Sponsor tier levels
enum SponsorTier {
  bronze,
  silver,
  gold,
  platinum,
}

/// Sponsor model representing a business sponsor
@JsonSerializable()
class Sponsor extends Equatable {
  final String id;
  final String name;
  final String? description;
  final String? logoUrl;
  final String? website;

  @JsonKey(fromJson: _sponsorTierFromJson, toJson: _sponsorTierToJson)
  final SponsorTier tier;

  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Sponsor({
    required this.id,
    required this.name,
    this.description,
    this.logoUrl,
    this.website,
    this.tier = SponsorTier.bronze,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Sponsor.fromJson(Map<String, dynamic> json) =>
      _$SponsorFromJson(json);

  Map<String, dynamic> toJson() => _$SponsorToJson(this);

  Sponsor copyWith({
    String? id,
    String? name,
    String? description,
    String? logoUrl,
    String? website,
    SponsorTier? tier,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Sponsor(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      logoUrl: logoUrl ?? this.logoUrl,
      website: website ?? this.website,
      tier: tier ?? this.tier,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        logoUrl,
        website,
        tier,
        isActive,
        createdAt,
        updatedAt,
      ];
}

SponsorTier _sponsorTierFromJson(String value) {
  return SponsorTier.values.firstWhere(
    (t) => t.name == value,
    orElse: () => SponsorTier.bronze,
  );
}

String _sponsorTierToJson(SponsorTier tier) => tier.name;
