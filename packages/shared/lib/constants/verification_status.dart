/// Verification status for user industry credentials
enum VerificationStatus {
  /// User has not submitted verification
  unverified('Unverified'),

  /// Verification is pending review
  pending('Pending'),

  /// User is verified as industry worker
  verified('Verified'),

  /// Verification was rejected
  rejected('Rejected');

  const VerificationStatus(this.displayName);
  final String displayName;

  static VerificationStatus fromString(String value) {
    return VerificationStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => VerificationStatus.unverified,
    );
  }

  bool get isVerified => this == VerificationStatus.verified;
  bool get isPending => this == VerificationStatus.pending;
  bool get canResubmit =>
      this == VerificationStatus.unverified ||
      this == VerificationStatus.rejected;
}

/// User roles in the system
enum UserRole {
  /// Regular app user
  user('User'),

  /// Venue staff member (can check in attendees)
  venueStaff('Venue Staff'),

  /// Platform administrator (full access)
  platformAdmin('Platform Admin');

  const UserRole(this.displayName);
  final String displayName;

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (r) => r.name == value,
      orElse: () => UserRole.user,
    );
  }

  bool get isAdmin => this == UserRole.platformAdmin;
  bool get isPlatformAdmin => this == UserRole.platformAdmin;
  bool get isStaff => this == UserRole.venueStaff;
}

/// Source of user registration
enum UserSource {
  /// User registered directly via app
  app('App'),

  /// User imported from Posh ticket purchase
  posh('Posh'),

  /// User added by admin
  admin('Admin');

  const UserSource(this.displayName);
  final String displayName;

  static UserSource fromString(String value) {
    return UserSource.values.firstWhere(
      (s) => s.name == value,
      orElse: () => UserSource.app,
    );
  }
}
