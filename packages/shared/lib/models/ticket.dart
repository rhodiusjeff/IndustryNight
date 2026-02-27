import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'ticket.g.dart';

/// Ticket status
enum TicketStatus {
  purchased,
  checkedIn,
  cancelled,
  refunded,
}

/// Ticket model representing an event ticket (from Posh integration)
@JsonSerializable(fieldRename: FieldRename.snake)
class Ticket extends Equatable {
  final String id;
  final String userId;
  final String eventId;
  final String? poshTicketId;
  final String? poshOrderId;
  final String ticketType;
  final double price;

  @JsonKey(fromJson: _ticketStatusFromJson, toJson: _ticketStatusToJson)
  final TicketStatus status;

  final DateTime? checkedInAt;
  final DateTime purchasedAt;
  final DateTime createdAt;

  /// Denormalized user info — only present in admin ticket list responses
  final String? userName;
  final String? userPhone;

  /// Event name — only present in global admin ticket list responses
  final String? eventName;

  const Ticket({
    required this.id,
    required this.userId,
    required this.eventId,
    this.poshTicketId,
    this.poshOrderId,
    required this.ticketType,
    required this.price,
    this.status = TicketStatus.purchased,
    this.checkedInAt,
    required this.purchasedAt,
    required this.createdAt,
    this.userName,
    this.userPhone,
    this.eventName,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) => _$TicketFromJson(json);

  Map<String, dynamic> toJson() => _$TicketToJson(this);

  Ticket copyWith({
    String? id,
    String? userId,
    String? eventId,
    String? poshTicketId,
    String? poshOrderId,
    String? ticketType,
    double? price,
    TicketStatus? status,
    DateTime? checkedInAt,
    DateTime? purchasedAt,
    DateTime? createdAt,
    String? userName,
    String? userPhone,
    String? eventName,
  }) {
    return Ticket(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      eventId: eventId ?? this.eventId,
      poshTicketId: poshTicketId ?? this.poshTicketId,
      poshOrderId: poshOrderId ?? this.poshOrderId,
      ticketType: ticketType ?? this.ticketType,
      price: price ?? this.price,
      status: status ?? this.status,
      checkedInAt: checkedInAt ?? this.checkedInAt,
      purchasedAt: purchasedAt ?? this.purchasedAt,
      createdAt: createdAt ?? this.createdAt,
      userName: userName ?? this.userName,
      userPhone: userPhone ?? this.userPhone,
      eventName: eventName ?? this.eventName,
    );
  }

  bool get isCheckedIn => status == TicketStatus.checkedIn;
  bool get isCancelled => status == TicketStatus.cancelled;
  bool get isValid =>
      status == TicketStatus.purchased || status == TicketStatus.checkedIn;
  bool get isFromPosh => poshTicketId != null;

  @override
  List<Object?> get props => [
        id,
        userId,
        eventId,
        poshTicketId,
        poshOrderId,
        ticketType,
        price,
        status,
        checkedInAt,
        purchasedAt,
        createdAt,
        userName,
        userPhone,
        eventName,
      ];
}

TicketStatus _ticketStatusFromJson(String value) {
  return TicketStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => TicketStatus.purchased,
  );
}

String _ticketStatusToJson(TicketStatus status) => status.name;
