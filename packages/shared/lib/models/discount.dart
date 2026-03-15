import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

import 'customer.dart';

part 'discount.g.dart';

/// Type of discount
enum DiscountType {
  percentage,
  fixedAmount,
  freeItem,
  buyOneGetOne,
  other,
}

/// Discount model representing a perk/discount offered by a customer
@JsonSerializable(fieldRename: FieldRename.snake)
class Discount extends Equatable {
  final String id;
  final String customerId;
  final String title;
  final String? description;

  @JsonKey(fromJson: _discountTypeFromJson, toJson: _discountTypeToJson)
  final DiscountType type;

  /// Discount value (percentage or fixed amount depending on type)
  final double? value;

  /// Promo code if applicable
  final String? code;

  /// Terms and conditions
  final String? terms;

  final bool isActive;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Populated when fetching discount details (admin views)
  final Customer? customer;

  /// Populated on list endpoints (from social API)
  final String? customerName;
  final String? customerLogo;

  /// Redemption count — populated in admin views
  final int? redemptionCount;

  const Discount({
    required this.id,
    required this.customerId,
    required this.title,
    this.description,
    this.type = DiscountType.percentage,
    this.value,
    this.code,
    this.terms,
    this.isActive = true,
    this.startDate,
    this.endDate,
    required this.createdAt,
    required this.updatedAt,
    this.customer,
    this.customerName,
    this.customerLogo,
    this.redemptionCount,
  });

  factory Discount.fromJson(Map<String, dynamic> json) =>
      _$DiscountFromJson(json);

  Map<String, dynamic> toJson() => _$DiscountToJson(this);

  Discount copyWith({
    String? id,
    String? customerId,
    String? title,
    String? description,
    DiscountType? type,
    double? value,
    String? code,
    String? terms,
    bool? isActive,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    Customer? customer,
    String? customerName,
    String? customerLogo,
    int? redemptionCount,
  }) {
    return Discount(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      value: value ?? this.value,
      code: code ?? this.code,
      terms: terms ?? this.terms,
      isActive: isActive ?? this.isActive,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      customer: customer ?? this.customer,
      customerName: customerName ?? this.customerName,
      customerLogo: customerLogo ?? this.customerLogo,
      redemptionCount: redemptionCount ?? this.redemptionCount,
    );
  }

  bool get isCurrentlyValid {
    if (!isActive) return false;
    final now = DateTime.now();
    if (startDate != null && now.isBefore(startDate!)) return false;
    if (endDate != null && now.isAfter(endDate!)) return false;
    return true;
  }

  String get displayValue {
    switch (type) {
      case DiscountType.percentage:
        return '${value?.toInt() ?? 0}% off';
      case DiscountType.fixedAmount:
        return '\$${value?.toStringAsFixed(2) ?? '0.00'} off';
      case DiscountType.freeItem:
        return 'Free item';
      case DiscountType.buyOneGetOne:
        return 'Buy one, get one';
      case DiscountType.other:
        return description ?? 'Special offer';
    }
  }

  @override
  List<Object?> get props => [
        id, customerId, title, description,
        type, value, code, terms,
        isActive, startDate, endDate,
        createdAt, updatedAt,
        customer, customerName, customerLogo,
        redemptionCount,
      ];
}

DiscountType _discountTypeFromJson(String value) {
  return DiscountType.values.firstWhere(
    (t) => t.name == value,
    orElse: () => DiscountType.other,
  );
}

String _discountTypeToJson(DiscountType type) => type.name;
