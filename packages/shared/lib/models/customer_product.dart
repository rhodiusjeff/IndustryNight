import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'customer_product.g.dart';

/// Status of a customer's product purchase
enum CustomerProductStatus {
  active,
  expired,
  cancelled,
  pending,
}

/// CustomerProduct model — an instance of a purchase linking customer + product + optional event.
@JsonSerializable(fieldRename: FieldRename.snake)
class CustomerProduct extends Equatable {
  final String id;
  final String customerId;
  final String productId;
  final String? eventId;
  final int? pricePaidCents;

  @JsonKey(fromJson: _statusFromJson, toJson: _statusToJson)
  final CustomerProductStatus status;

  final DateTime? startDate;
  final DateTime? endDate;
  final Map<String, dynamic> configOverrides;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined fields from detail queries
  final String? customerName;
  final String? productName;
  final String? eventName;
  final String? productType;
  final String? tier;
  final String? vendorCategory;
  final Map<String, dynamic>? productConfig;

  const CustomerProduct({
    required this.id,
    required this.customerId,
    required this.productId,
    this.eventId,
    this.pricePaidCents,
    this.status = CustomerProductStatus.active,
    this.startDate,
    this.endDate,
    this.configOverrides = const {},
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.customerName,
    this.productName,
    this.eventName,
    this.productType,
    this.tier,
    this.vendorCategory,
    this.productConfig,
  });

  factory CustomerProduct.fromJson(Map<String, dynamic> json) =>
      _$CustomerProductFromJson(json);

  Map<String, dynamic> toJson() => _$CustomerProductToJson(this);

  CustomerProduct copyWith({
    String? id,
    String? customerId,
    String? productId,
    String? eventId,
    int? pricePaidCents,
    CustomerProductStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    Map<String, dynamic>? configOverrides,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? customerName,
    String? productName,
    String? eventName,
    String? productType,
    String? tier,
    String? vendorCategory,
    Map<String, dynamic>? productConfig,
  }) {
    return CustomerProduct(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      productId: productId ?? this.productId,
      eventId: eventId ?? this.eventId,
      pricePaidCents: pricePaidCents ?? this.pricePaidCents,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      configOverrides: configOverrides ?? this.configOverrides,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      customerName: customerName ?? this.customerName,
      productName: productName ?? this.productName,
      eventName: eventName ?? this.eventName,
      productType: productType ?? this.productType,
      tier: tier ?? this.tier,
      vendorCategory: vendorCategory ?? this.vendorCategory,
      productConfig: productConfig ?? this.productConfig,
    );
  }

  String get displayPrice {
    if (pricePaidCents == null) return 'N/A';
    final dollars = pricePaidCents! / 100;
    return '\$${dollars.toStringAsFixed(2)}';
  }

  @override
  List<Object?> get props => [
        id, customerId, productId, eventId, pricePaidCents,
        status, startDate, endDate, configOverrides, notes,
        createdAt, updatedAt, customerName, productName,
        eventName, productType, tier, vendorCategory, productConfig,
      ];
}

CustomerProductStatus _statusFromJson(String value) {
  return CustomerProductStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => CustomerProductStatus.active,
  );
}

String _statusToJson(CustomerProductStatus status) => status.name;
