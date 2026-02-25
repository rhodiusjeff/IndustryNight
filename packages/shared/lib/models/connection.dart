import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'user.dart';

part 'connection.g.dart';

/// Connection model representing a networking connection between users
/// Created instantly via QR code scan - no pending/accept flow
@JsonSerializable(fieldRename: FieldRename.snake)
class Connection extends Equatable {
  final String id;
  final String userAId;
  final String userBId;
  final String? eventId;
  final DateTime createdAt;

  /// Populated when fetching connection details
  final User? userA;
  final User? userB;

  const Connection({
    required this.id,
    required this.userAId,
    required this.userBId,
    this.eventId,
    required this.createdAt,
    this.userA,
    this.userB,
  });

  factory Connection.fromJson(Map<String, dynamic> json) =>
      _$ConnectionFromJson(json);

  Map<String, dynamic> toJson() => _$ConnectionToJson(this);

  Connection copyWith({
    String? id,
    String? userAId,
    String? userBId,
    String? eventId,
    DateTime? createdAt,
    User? userA,
    User? userB,
  }) {
    return Connection(
      id: id ?? this.id,
      userAId: userAId ?? this.userAId,
      userBId: userBId ?? this.userBId,
      eventId: eventId ?? this.eventId,
      createdAt: createdAt ?? this.createdAt,
      userA: userA ?? this.userA,
      userB: userB ?? this.userB,
    );
  }

  /// Get the other user in the connection (relative to the current user)
  User? getOtherUser(String currentUserId) {
    if (currentUserId == userAId) return userB;
    if (currentUserId == userBId) return userA;
    return null;
  }

  /// Check if a user is part of this connection
  bool involvesUser(String userId) {
    return userAId == userId || userBId == userId;
  }

  @override
  List<Object?> get props => [
        id,
        userAId,
        userBId,
        eventId,
        createdAt,
        userA,
        userB,
      ];
}
