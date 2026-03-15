import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

import 'customer_contact.dart';
import 'customer_media_item.dart';
import 'customer_product.dart';
import 'discount.dart';
import 'market.dart';

part 'customer.g.dart';

/// Customer model — a business with a commercial relationship with IN.
/// Replaces the separate Sponsor and Vendor models.
@JsonSerializable(fieldRename: FieldRename.snake)
class Customer extends Equatable {
  final String id;
  final String name;
  final String? description;
  final String? logoUrl;
  final String? website;
  final String? contactEmail;
  final String? contactPhone;
  final bool isActive;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Active product types — populated on list endpoints (e.g. ['sponsorship', 'vendor_space'])
  @JsonKey(fromJson: _productTypesFromJson)
  final List<String>? activeProductTypes;

  /// Products this customer has purchased — only populated on detail endpoint
  @JsonKey(fromJson: _customerProductsFromJson, toJson: _customerProductsToJson)
  final List<CustomerProduct>? products;

  /// Discounts this customer offers — only populated on detail endpoint
  @JsonKey(fromJson: _discountsFromJson, toJson: _discountsToJson)
  final List<Discount>? discounts;

  /// Contacts — populated on detail endpoint
  @JsonKey(fromJson: _contactsFromJson, toJson: _contactsToJson)
  final List<CustomerContact>? contacts;

  /// Markets the customer operates in — populated on list (names only) and detail (full)
  @JsonKey(fromJson: _marketsFromJson, toJson: _marketsToJson)
  final List<Market>? markets;

  /// Brand media assets — populated on detail endpoint
  @JsonKey(fromJson: _mediaFromJson, toJson: _mediaToJson)
  final List<CustomerMediaItem>? media;

  const Customer({
    required this.id,
    required this.name,
    this.description,
    this.logoUrl,
    this.website,
    this.contactEmail,
    this.contactPhone,
    this.isActive = true,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.activeProductTypes,
    this.products,
    this.discounts,
    this.contacts,
    this.markets,
    this.media,
  });

  factory Customer.fromJson(Map<String, dynamic> json) =>
      _$CustomerFromJson(json);

  Map<String, dynamic> toJson() => _$CustomerToJson(this);

  Customer copyWith({
    String? id,
    String? name,
    String? description,
    String? logoUrl,
    String? website,
    String? contactEmail,
    String? contactPhone,
    bool? isActive,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? activeProductTypes,
    List<CustomerProduct>? products,
    List<Discount>? discounts,
    List<CustomerContact>? contacts,
    List<Market>? markets,
    List<CustomerMediaItem>? media,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      logoUrl: logoUrl ?? this.logoUrl,
      website: website ?? this.website,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      activeProductTypes: activeProductTypes ?? this.activeProductTypes,
      products: products ?? this.products,
      discounts: discounts ?? this.discounts,
      contacts: contacts ?? this.contacts,
      markets: markets ?? this.markets,
      media: media ?? this.media,
    );
  }

  bool get hasSponsorships =>
      activeProductTypes?.contains('sponsorship') ?? false;
  bool get hasVendorSpace =>
      activeProductTypes?.contains('vendor_space') ?? false;
  bool get hasDataProducts =>
      activeProductTypes?.contains('data_product') ?? false;

  @override
  List<Object?> get props => [
        id, name, description, logoUrl, website,
        contactEmail, contactPhone, isActive, notes,
        createdAt, updatedAt, activeProductTypes,
        products, discounts, contacts, markets, media,
      ];
}

List<String>? _productTypesFromJson(dynamic value) {
  if (value == null) return null;
  if (value is List) return value.cast<String>();
  if (value is String) return value.split(',').map((s) => s.trim()).toList();
  return null;
}

List<CustomerProduct>? _customerProductsFromJson(dynamic value) {
  if (value == null) return null;
  return (value as List)
      .map((e) => CustomerProduct.fromJson(e as Map<String, dynamic>))
      .toList();
}

dynamic _customerProductsToJson(List<CustomerProduct>? products) =>
    products?.map((p) => p.toJson()).toList();

List<Discount>? _discountsFromJson(dynamic value) {
  if (value == null) return null;
  return (value as List)
      .map((e) => Discount.fromJson(e as Map<String, dynamic>))
      .toList();
}

dynamic _discountsToJson(List<Discount>? discounts) =>
    discounts?.map((d) => d.toJson()).toList();

List<CustomerContact>? _contactsFromJson(dynamic value) {
  if (value == null) return null;
  return (value as List)
      .map((e) => CustomerContact.fromJson(e as Map<String, dynamic>))
      .toList();
}

dynamic _contactsToJson(List<CustomerContact>? contacts) =>
    contacts?.map((c) => c.toJson()).toList();

List<Market>? _marketsFromJson(dynamic value) {
  if (value == null) return null;
  return (value as List)
      .map((e) => Market.fromJson(e as Map<String, dynamic>))
      .toList();
}

dynamic _marketsToJson(List<Market>? markets) =>
    markets?.map((m) => m.toJson()).toList();

List<CustomerMediaItem>? _mediaFromJson(dynamic value) {
  if (value == null) return null;
  return (value as List)
      .map((e) => CustomerMediaItem.fromJson(e as Map<String, dynamic>))
      .toList();
}

dynamic _mediaToJson(List<CustomerMediaItem>? media) =>
    media?.map((m) => m.toJson()).toList();
