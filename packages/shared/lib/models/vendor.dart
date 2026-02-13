import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'vendor.g.dart';

/// Vendor category
enum VendorCategory {
  food,
  beverage,
  equipment,
  service,
  venue,
  other,
}

/// Vendor model representing a service provider at events
@JsonSerializable()
class Vendor extends Equatable {
  final String id;
  final String name;
  final String? description;
  final String? logoUrl;
  final String? website;
  final String? contactEmail;
  final String? contactPhone;

  @JsonKey(fromJson: _vendorCategoryFromJson, toJson: _vendorCategoryToJson)
  final VendorCategory category;

  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Vendor({
    required this.id,
    required this.name,
    this.description,
    this.logoUrl,
    this.website,
    this.contactEmail,
    this.contactPhone,
    this.category = VendorCategory.other,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Vendor.fromJson(Map<String, dynamic> json) => _$VendorFromJson(json);

  Map<String, dynamic> toJson() => _$VendorToJson(this);

  Vendor copyWith({
    String? id,
    String? name,
    String? description,
    String? logoUrl,
    String? website,
    String? contactEmail,
    String? contactPhone,
    VendorCategory? category,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Vendor(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      logoUrl: logoUrl ?? this.logoUrl,
      website: website ?? this.website,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      category: category ?? this.category,
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
        contactEmail,
        contactPhone,
        category,
        isActive,
        createdAt,
        updatedAt,
      ];
}

VendorCategory _vendorCategoryFromJson(String value) {
  return VendorCategory.values.firstWhere(
    (c) => c.name == value,
    orElse: () => VendorCategory.other,
  );
}

String _vendorCategoryToJson(VendorCategory category) => category.name;
