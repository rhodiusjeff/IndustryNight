import 'api_client.dart';
import '../models/user.dart';

/// Response from authentication endpoints
class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final User user;
  final bool isNewUser;

  AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
    this.isNewUser = false,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      isNewUser: json['isNewUser'] as bool? ?? false,
    );
  }
}

/// API client for authentication endpoints
class AuthApi {
  final ApiClient _client;

  AuthApi(this._client);

  /// Request an SMS verification code
  /// Returns a dev code only when API dev OTP fallback is explicitly enabled
  Future<String?> requestCode(String phone) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/auth/request-code',
      body: {'phone': phone},
      requiresAuth: false,
    );
    return response['devCode'] as String?;
  }

  /// Verify SMS code and get tokens
  Future<AuthResponse> verifyCode(String phone, String code) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/auth/verify-code',
      body: {'phone': phone, 'code': code},
      requiresAuth: false,
    );

    final authResponse = AuthResponse.fromJson(response);
    _client.setToken(authResponse.accessToken);
    return authResponse;
  }

  /// Refresh the access token
  Future<AuthResponse> refreshToken(String refreshToken) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/auth/refresh',
      body: {'refreshToken': refreshToken},
      requiresAuth: false,
    );

    final authResponse = AuthResponse.fromJson(response);
    _client.setToken(authResponse.accessToken);
    return authResponse;
  }

  /// Logout and invalidate tokens
  Future<void> logout() async {
    await _client.post('/auth/logout');
    _client.clearToken();
  }

  /// Get current user info
  Future<User> getCurrentUser() async {
    final response = await _client.get<Map<String, dynamic>>('/auth/me');
    return User.fromJson(response['user'] as Map<String, dynamic>);
  }

  /// Delete the current user's account
  Future<void> deleteAccount() async {
    await _client.delete('/auth/me');
    _client.clearToken();
  }
}
