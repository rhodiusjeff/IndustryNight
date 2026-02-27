import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// Exception thrown when an API request fails
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final Map<String, dynamic>? errors;

  ApiException({
    required this.statusCode,
    required this.message,
    this.errors,
  });

  @override
  String toString() => 'ApiException($statusCode): $message';

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isServerError => statusCode >= 500;
}

/// Callback that attempts to refresh the auth token.
/// Returns true if a new token was set (retry the request), false to give up.
typedef TokenRefresher = Future<bool> Function();

/// HTTP client for Industry Night API
class ApiClient {
  final String baseUrl;
  final http.Client _httpClient;
  String? _token;
  bool _isRefreshing = false;

  /// Set this to enable automatic token refresh on 401 responses.
  /// The callback should refresh the token, call [setToken] with the new value,
  /// and return true. Return false (or throw) to propagate the 401.
  TokenRefresher? onTokenExpired;

  ApiClient({
    required this.baseUrl,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// Set the authentication token
  void setToken(String token) {
    _token = token;
  }

  /// Clear the authentication token
  void clearToken() {
    _token = null;
  }

  /// Check if client has a token set
  bool get hasToken => _token != null;

  /// Build headers for requests
  Map<String, String> _buildHeaders({bool includeAuth = true}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (includeAuth && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }

    return headers;
  }

  /// Parse response and throw on error
  dynamic _handleResponse(http.Response response) {
    debugPrint('[API] ${response.request?.method} ${response.request?.url} → ${response.statusCode}');
    if (response.statusCode >= 400) {
      debugPrint('[API] Error body: ${response.body}');
    }

    final body = response.body.isNotEmpty ? jsonDecode(response.body) : null;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    throw ApiException(
      statusCode: response.statusCode,
      message: body?['message'] ?? 'Request failed',
      errors: body?['errors'] as Map<String, dynamic>?,
    );
  }

  /// Execute [request], and on 401 try [onTokenExpired] then retry once.
  Future<T> _withRetry<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on ApiException catch (e) {
      if (e.isUnauthorized && onTokenExpired != null && !_isRefreshing) {
        _isRefreshing = true;
        try {
          final refreshed = await onTokenExpired!();
          if (refreshed) {
            return await request();
          }
        } finally {
          _isRefreshing = false;
        }
      }
      rethrow;
    }
  }

  /// Make a GET request
  Future<T> get<T>(
    String path, {
    Map<String, String>? queryParams,
    bool requiresAuth = true,
  }) {
    return _withRetry(() async {
      final uri = Uri.parse('$baseUrl$path').replace(queryParameters: queryParams);
      final response = await _httpClient.get(
        uri,
        headers: _buildHeaders(includeAuth: requiresAuth),
      );
      return _handleResponse(response) as T;
    });
  }

  /// Make a POST request
  Future<T> post<T>(
    String path, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) {
    return _withRetry(() async {
      final uri = Uri.parse('$baseUrl$path');
      final response = await _httpClient.post(
        uri,
        headers: _buildHeaders(includeAuth: requiresAuth),
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(response) as T;
    });
  }

  /// Make a PUT request
  Future<T> put<T>(
    String path, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) {
    return _withRetry(() async {
      final uri = Uri.parse('$baseUrl$path');
      final response = await _httpClient.put(
        uri,
        headers: _buildHeaders(includeAuth: requiresAuth),
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(response) as T;
    });
  }

  /// Make a PATCH request
  Future<T> patch<T>(
    String path, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) {
    return _withRetry(() async {
      final uri = Uri.parse('$baseUrl$path');
      final response = await _httpClient.patch(
        uri,
        headers: _buildHeaders(includeAuth: requiresAuth),
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(response) as T;
    });
  }

  /// Make a DELETE request
  Future<void> delete(
    String path, {
    bool requiresAuth = true,
  }) {
    return _withRetry(() async {
      final uri = Uri.parse('$baseUrl$path');
      final response = await _httpClient.delete(
        uri,
        headers: _buildHeaders(includeAuth: requiresAuth),
      );
      _handleResponse(response);
    });
  }

  /// Upload a file via multipart request
  Future<T> uploadFile<T>(
    String path, {
    required String fieldName,
    required List<int> fileBytes,
    required String filename,
    String? mimeType,
    Map<String, String>? additionalFields,
  }) {
    return _withRetry(() async {
      final uri = Uri.parse('$baseUrl$path');
      final request = http.MultipartRequest('POST', uri);

      if (_token != null) {
        request.headers['Authorization'] = 'Bearer $_token';
      }

      request.files.add(http.MultipartFile.fromBytes(
        fieldName,
        fileBytes,
        filename: filename,
        contentType: _contentTypeFromArgs(mimeType, filename),
      ));

      if (additionalFields != null) {
        request.fields.addAll(additionalFields);
      }

      final streamedResponse = await _httpClient.send(request);
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response) as T;
    });
  }

  /// Detect content type from explicit mimeType or file extension fallback
  MediaType? _contentTypeFromArgs(String? mimeType, String filename) {
    if (mimeType != null) return MediaType.parse(mimeType);
    final ext = filename.split('.').last.toLowerCase();
    const types = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'webp': 'image/webp',
      'gif': 'image/gif',
    };
    final detected = types[ext];
    return detected != null ? MediaType.parse(detected) : null;
  }

  /// Close the HTTP client
  void dispose() {
    _httpClient.close();
  }
}
