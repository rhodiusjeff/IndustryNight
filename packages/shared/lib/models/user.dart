import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import '../constants/verification_status.dart';

part 'user.g.dart';

/// Profile visibility setting
enum ProfileVisibility {
  /// Profile visible to everyone
  public,
  /// Profile visible only to connections
  connections,
  /// Profile hidden from all users
  private,
}

ProfileVisibility _profileVisibilityFromJson(String value) {
  return ProfileVisibility.values.firstWhere(
    (v) => v.name == value,
    orElse: () => ProfileVisibility.connections,
  );
}

String _profileVisibilityToJson(ProfileVisibility visibility) => visibility.name;

/// Social media links for a user profile
@JsonSerializable(fieldRename: FieldRename.snake)
class SocialLinks extends Equatable {
  final String? instagram;
  final String? tiktok;
  final String? linkedin;
  final String? website;

  const SocialLinks({
    this.instagram,
    this.tiktok,
    this.linkedin,
    this.website,
  });

  factory SocialLinks.fromJson(Map<String, dynamic> json) =>
      _$SocialLinksFromJson(json);

  Map<String, dynamic> toJson() => _$SocialLinksToJson(this);

  SocialLinks copyWith({
    String? instagram,
    String? tiktok,
    String? linkedin,
    String? website,
  }) {
    return SocialLinks(
      instagram: instagram ?? this.instagram,
      tiktok: tiktok ?? this.tiktok,
      linkedin: linkedin ?? this.linkedin,
      website: website ?? this.website,
    );
  }

  @override
  List<Object?> get props => [instagram, tiktok, linkedin, website];
}

/// User model representing an Industry Night user
@JsonSerializable(fieldRename: FieldRename.snake)
class User extends Equatable {
  final String id;
  final String phone;
  final String? email;
  final String? name;
  final String? bio;
  final String? profilePhotoUrl;

  @JsonKey(fromJson: _userRoleFromJson, toJson: _userRoleToJson)
  final UserRole role;

  @JsonKey(fromJson: _userSourceFromJson, toJson: _userSourceToJson)
  final UserSource source;

  final List<String> specialties;
  final SocialLinks? socialLinks;

  @JsonKey(
      fromJson: _verificationStatusFromJson,
      toJson: _verificationStatusToJson)
  final VerificationStatus verificationStatus;

  final bool profileCompleted;
  final bool banned;

  // Privacy & consent
  final bool analyticsConsent;
  final bool marketingConsent;
  @JsonKey(fromJson: _profileVisibilityFromJson, toJson: _profileVisibilityToJson)
  final ProfileVisibility profileVisibility;
  final DateTime? consentUpdatedAt;

  // Timestamps
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  const User({
    required this.id,
    required this.phone,
    this.email,
    this.name,
    this.bio,
    this.profilePhotoUrl,
    this.role = UserRole.user,
    this.source = UserSource.app,
    this.specialties = const [],
    this.socialLinks,
    this.verificationStatus = VerificationStatus.unverified,
    this.profileCompleted = false,
    this.banned = false,
    this.analyticsConsent = false,
    this.marketingConsent = false,
    this.profileVisibility = ProfileVisibility.connections,
    this.consentUpdatedAt,
    required this.createdAt,
    this.lastLoginAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  Map<String, dynamic> toJson() => _$UserToJson(this);

  User copyWith({
    String? id,
    String? phone,
    String? email,
    String? name,
    String? bio,
    String? profilePhotoUrl,
    UserRole? role,
    UserSource? source,
    List<String>? specialties,
    SocialLinks? socialLinks,
    VerificationStatus? verificationStatus,
    bool? profileCompleted,
    bool? banned,
    bool? analyticsConsent,
    bool? marketingConsent,
    ProfileVisibility? profileVisibility,
    DateTime? consentUpdatedAt,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) {
    return User(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      name: name ?? this.name,
      bio: bio ?? this.bio,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      role: role ?? this.role,
      source: source ?? this.source,
      specialties: specialties ?? this.specialties,
      socialLinks: socialLinks ?? this.socialLinks,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      banned: banned ?? this.banned,
      analyticsConsent: analyticsConsent ?? this.analyticsConsent,
      marketingConsent: marketingConsent ?? this.marketingConsent,
      profileVisibility: profileVisibility ?? this.profileVisibility,
      consentUpdatedAt: consentUpdatedAt ?? this.consentUpdatedAt,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  bool get isVerified => verificationStatus == VerificationStatus.verified;
  bool get isAdmin => role.isAdmin;
  bool get isPlatformAdmin => role.isPlatformAdmin;

  @override
  List<Object?> get props => [
        id,
        phone,
        email,
        name,
        bio,
        profilePhotoUrl,
        role,
        source,
        specialties,
        socialLinks,
        verificationStatus,
        profileCompleted,
        banned,
        analyticsConsent,
        marketingConsent,
        profileVisibility,
        consentUpdatedAt,
        createdAt,
        lastLoginAt,
      ];
}

// JSON conversion helpers
UserRole _userRoleFromJson(String value) => UserRole.fromString(value);
String _userRoleToJson(UserRole role) => role.name;

UserSource _userSourceFromJson(String value) => UserSource.fromString(value);
String _userSourceToJson(UserSource source) => source.name;

VerificationStatus _verificationStatusFromJson(String value) =>
    VerificationStatus.fromString(value);
String _verificationStatusToJson(VerificationStatus status) => status.name;
