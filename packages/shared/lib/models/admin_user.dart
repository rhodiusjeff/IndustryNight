import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'admin_user.g.dart';

/// Admin role enum
enum AdminRole {
  @JsonValue('platformAdmin')
  platformAdmin;

  static AdminRole fromString(String value) {
    return AdminRole.values.firstWhere(
      (v) => v.name == value,
      orElse: () => AdminRole.platformAdmin,
    );
  }
}

AdminRole _adminRoleFromJson(String value) => AdminRole.fromString(value);
String _adminRoleToJson(AdminRole role) => role.name;

/// Admin user model for the admin dashboard
@JsonSerializable()
class AdminUser extends Equatable {
  final String id;
  final String email;
  final String name;

  @JsonKey(fromJson: _adminRoleFromJson, toJson: _adminRoleToJson)
  final AdminRole role;

  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  const AdminUser({
    required this.id,
    required this.email,
    required this.name,
    this.role = AdminRole.platformAdmin,
    this.isActive = true,
    required this.createdAt,
    this.lastLoginAt,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) =>
      _$AdminUserFromJson(json);

  Map<String, dynamic> toJson() => _$AdminUserToJson(this);

  @override
  List<Object?> get props => [
        id,
        email,
        name,
        role,
        isActive,
        createdAt,
        lastLoginAt,
      ];
}
