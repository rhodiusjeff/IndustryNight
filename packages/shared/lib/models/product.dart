import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'product.g.dart';

/// Product type — what IN sells
enum ProductType {
  sponsorship,
  @JsonValue('vendor_space')
  vendorSpace,
  @JsonValue('data_product')
  dataProduct,
}

/// Product model — a catalog item representing what IN sells.
@JsonSerializable(fieldRename: FieldRename.snake)
class Product extends Equatable {
  final String id;

  @JsonKey(fromJson: _productTypeFromJson, toJson: _productTypeToJson)
  final ProductType productType;

  final String name;
  final String? description;
  final int? basePriceCents;
  final bool isStandard;
  final Map<String, dynamic> config;
  final bool isActive;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Product({
    required this.id,
    required this.productType,
    required this.name,
    this.description,
    this.basePriceCents,
    this.isStandard = true,
    this.config = const {},
    this.isActive = true,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) =>
      _$ProductFromJson(json);

  Map<String, dynamic> toJson() => _$ProductToJson(this);

  Product copyWith({
    String? id,
    ProductType? productType,
    String? name,
    String? description,
    int? basePriceCents,
    bool? isStandard,
    Map<String, dynamic>? config,
    bool? isActive,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      productType: productType ?? this.productType,
      name: name ?? this.name,
      description: description ?? this.description,
      basePriceCents: basePriceCents ?? this.basePriceCents,
      isStandard: isStandard ?? this.isStandard,
      config: config ?? this.config,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Config helpers
  String? get tier => config['tier'] as String?;
  String? get level => config['level'] as String?;
  String? get vendorCategory => config['category'] as String?;
  String? get boothSize => config['booth_size'] as String?;
  String? get format => config['format'] as String?;
  String? get scope => config['scope'] as String?;
  String? get frequency => config['frequency'] as String?;

  String get displayPrice {
    if (basePriceCents == null) return 'Quote required';
    final dollars = basePriceCents! / 100;
    if (dollars >= 1000) {
      return '\$${(dollars / 1000).toStringAsFixed(dollars % 1000 == 0 ? 0 : 1)}K';
    }
    return '\$${dollars.toStringAsFixed(dollars == dollars.roundToDouble() ? 0 : 2)}';
  }

  @override
  List<Object?> get props => [
        id, productType, name, description, basePriceCents,
        isStandard, config, isActive, sortOrder,
        createdAt, updatedAt,
      ];
}

ProductType _productTypeFromJson(String value) {
  switch (value) {
    case 'vendor_space':
      return ProductType.vendorSpace;
    case 'data_product':
      return ProductType.dataProduct;
    case 'sponsorship':
    default:
      return ProductType.sponsorship;
  }
}

String _productTypeToJson(ProductType type) {
  switch (type) {
    case ProductType.vendorSpace:
      return 'vendor_space';
    case ProductType.dataProduct:
      return 'data_product';
    case ProductType.sponsorship:
      return 'sponsorship';
  }
}
