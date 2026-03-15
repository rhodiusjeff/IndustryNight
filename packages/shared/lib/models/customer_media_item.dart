import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'customer_media_item.g.dart';

enum MediaPlacement {
  @JsonValue('app_banner')
  appBanner,
  @JsonValue('web_banner')
  webBanner,
  @JsonValue('social_media')
  socialMedia,
  logo,
  other,
}

/// Customer media item — brand assets (logo, banners) associated with a customer.
@JsonSerializable(fieldRename: FieldRename.snake)
class CustomerMediaItem extends Equatable {
  final String id;
  final String customerId;
  final String url;
  final MediaPlacement placement;
  final int? width;
  final int? height;
  final String? altText;
  final int sortOrder;
  final DateTime uploadedAt;

  const CustomerMediaItem({
    required this.id,
    required this.customerId,
    required this.url,
    this.placement = MediaPlacement.other,
    this.width,
    this.height,
    this.altText,
    this.sortOrder = 0,
    required this.uploadedAt,
  });

  factory CustomerMediaItem.fromJson(Map<String, dynamic> json) =>
      _$CustomerMediaItemFromJson(json);

  Map<String, dynamic> toJson() => _$CustomerMediaItemToJson(this);

  CustomerMediaItem copyWith({
    String? id,
    String? customerId,
    String? url,
    MediaPlacement? placement,
    int? width,
    int? height,
    String? altText,
    int? sortOrder,
    DateTime? uploadedAt,
  }) {
    return CustomerMediaItem(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      url: url ?? this.url,
      placement: placement ?? this.placement,
      width: width ?? this.width,
      height: height ?? this.height,
      altText: altText ?? this.altText,
      sortOrder: sortOrder ?? this.sortOrder,
      uploadedAt: uploadedAt ?? this.uploadedAt,
    );
  }

  @override
  List<Object?> get props => [
        id, customerId, url, placement,
        width, height, altText, sortOrder, uploadedAt,
      ];
}
