import 'api_client.dart';
import '../models/admin_user.dart';

/// Response from admin authentication endpoints
class AdminAuthResponse {
  final String accessToken;
  final String refreshToken;
  final AdminUser admin;

  AdminAuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.admin,
  });

  factory AdminAuthResponse.fromJson(Map<String, dynamic> json) {
    return AdminAuthResponse(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      admin: AdminUser.fromJson(json['admin'] as Map<String, dynamic>),
    );
  }
}

/// API client for admin authentication endpoints
class AdminAuthApi {
  final ApiClient _client;

  AdminAuthApi(this._client);

  /// Login with email and password
  Future<AdminAuthResponse> login(String email, String password) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/admin/auth/login',
      body: {'email': email, 'password': password},
      requiresAuth: false,
    );

    final authResponse = AdminAuthResponse.fromJson(response);
    _client.setToken(authResponse.accessToken);
    return authResponse;
  }

  /// Refresh the access token
  Future<AdminAuthResponse> refreshToken(String refreshToken) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/admin/auth/refresh',
      body: {'refreshToken': refreshToken},
      requiresAuth: false,
    );

    final authResponse = AdminAuthResponse.fromJson(response);
    _client.setToken(authResponse.accessToken);
    return authResponse;
  }

  /// Get current admin user info
  Future<AdminUser> getCurrentAdmin() async {
    final response =
        await _client.get<Map<String, dynamic>>('/admin/auth/me');
    return AdminUser.fromJson(response['admin'] as Map<String, dynamic>);
  }

  /// Logout
  Future<void> logout() async {
    await _client.post('/admin/auth/logout');
    _client.clearToken();
  }
}
