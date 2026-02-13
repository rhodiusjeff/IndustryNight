import 'api_client.dart';
import '../models/user.dart';

/// API client for user endpoints
class UsersApi {
  final ApiClient _client;

  UsersApi(this._client);

  /// Get user by ID
  Future<User> getUser(String id) async {
    final response = await _client.get<Map<String, dynamic>>('/users/$id');
    return User.fromJson(response['user'] as Map<String, dynamic>);
  }

  /// Update current user's profile
  Future<User> updateProfile({
    String? name,
    String? email,
    String? bio,
    List<String>? specialties,
    SocialLinks? socialLinks,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (email != null) body['email'] = email;
    if (bio != null) body['bio'] = bio;
    if (specialties != null) body['specialties'] = specialties;
    if (socialLinks != null) body['socialLinks'] = socialLinks.toJson();

    final response = await _client.patch<Map<String, dynamic>>(
      '/users/me',
      body: body,
    );
    return User.fromJson(response['user'] as Map<String, dynamic>);
  }

  /// Upload profile photo
  Future<User> uploadProfilePhoto(List<int> imageBytes, String filename) async {
    final response = await _client.uploadFile<Map<String, dynamic>>(
      '/users/me/photo',
      fieldName: 'photo',
      fileBytes: imageBytes,
      filename: filename,
    );
    return User.fromJson(response['user'] as Map<String, dynamic>);
  }

  /// Search users
  Future<List<User>> searchUsers({
    String? query,
    List<String>? specialties,
    int limit = 20,
    int offset = 0,
  }) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (query != null) queryParams['q'] = query;
    if (specialties != null && specialties.isNotEmpty) {
      queryParams['specialties'] = specialties.join(',');
    }

    final response = await _client.get<Map<String, dynamic>>(
      '/users',
      queryParams: queryParams,
    );

    final users = (response['users'] as List)
        .map((u) => User.fromJson(u as Map<String, dynamic>))
        .toList();

    return users;
  }

  /// Submit verification request
  Future<void> submitVerification({
    required List<int> documentBytes,
    required String filename,
    String? notes,
  }) async {
    await _client.uploadFile(
      '/users/me/verification',
      fieldName: 'document',
      fileBytes: documentBytes,
      filename: filename,
      additionalFields: notes != null ? {'notes': notes} : null,
    );
  }

  /// Get QR code data for networking
  Future<String> getQrCode() async {
    final response = await _client.get<Map<String, dynamic>>('/users/me/qr');
    return response['qrData'] as String;
  }
}
