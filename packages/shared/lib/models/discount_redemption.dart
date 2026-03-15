import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'discount_redemption.g.dart';

/// How a discount was redeemed
enum RedemptionMethod {
  @JsonValue('self_reported')
  selfReported,
  @JsonValue('code_entry')
  codeEntry,
  @JsonValue('qr_scan')
  qrScan,
}

/// DiscountRedemption model — tracks when a user claims a discount/perk.
@JsonSerializable(fieldRename: FieldRename.snake)
class DiscountRedemption extends Equatable {
  final String id;
  final String discountId;
  final String userId;

  @JsonKey(fromJson: _methodFromJson, toJson: _methodToJson)
  final RedemptionMethod method;

  final DateTime redeemedAt;
  final String? notes;

  // Joined fields from admin queries
  final String? userName;
  final String? userPhone;
  final String? discountTitle;

  const DiscountRedemption({
    required this.id,
    required this.discountId,
    required this.userId,
    this.method = RedemptionMethod.selfReported,
    required this.redeemedAt,
    this.notes,
    this.userName,
    this.userPhone,
    this.discountTitle,
  });

  factory DiscountRedemption.fromJson(Map<String, dynamic> json) =>
      _$DiscountRedemptionFromJson(json);

  Map<String, dynamic> toJson() => _$DiscountRedemptionToJson(this);

  @override
  List<Object?> get props => [
        id, discountId, userId, method, redeemedAt, notes,
        userName, userPhone, discountTitle,
      ];
}

RedemptionMethod _methodFromJson(String value) {
  switch (value) {
    case 'code_entry':
      return RedemptionMethod.codeEntry;
    case 'qr_scan':
      return RedemptionMethod.qrScan;
    case 'self_reported':
    default:
      return RedemptionMethod.selfReported;
  }
}

String _methodToJson(RedemptionMethod method) {
  switch (method) {
    case RedemptionMethod.selfReported:
      return 'self_reported';
    case RedemptionMethod.codeEntry:
      return 'code_entry';
    case RedemptionMethod.qrScan:
      return 'qr_scan';
  }
}
