import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'customer_contact.g.dart';

enum ContactRole {
  primary,
  billing,
  @JsonValue('decision_maker')
  decisionMaker,
  other,
}

/// Customer contact — a person associated with a customer business.
@JsonSerializable(fieldRename: FieldRename.snake)
class CustomerContact extends Equatable {
  final String id;
  final String customerId;
  final String name;
  final String? email;
  final String? phone;
  final ContactRole role;
  final String? title;
  final bool isPrimary;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CustomerContact({
    required this.id,
    required this.customerId,
    required this.name,
    this.email,
    this.phone,
    this.role = ContactRole.other,
    this.title,
    this.isPrimary = false,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CustomerContact.fromJson(Map<String, dynamic> json) =>
      _$CustomerContactFromJson(json);

  Map<String, dynamic> toJson() => _$CustomerContactToJson(this);

  CustomerContact copyWith({
    String? id,
    String? customerId,
    String? name,
    String? email,
    String? phone,
    ContactRole? role,
    String? title,
    bool? isPrimary,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomerContact(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      title: title ?? this.title,
      isPrimary: isPrimary ?? this.isPrimary,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id, customerId, name, email, phone,
        role, title, isPrimary, notes,
        createdAt, updatedAt,
      ];
}
