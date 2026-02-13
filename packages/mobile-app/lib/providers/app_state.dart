import 'package:flutter/foundation.dart';
import 'package:industrynight_shared/shared.dart';

/// Global application state
class AppState extends ChangeNotifier {
  final ApiClient _apiClient;
  final SecureStorage _storage;

  User? _currentUser;
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;

  AppState({
    String? apiBaseUrl,
    ApiClient? apiClient,
    SecureStorage? storage,
  })  : _apiClient = apiClient ??
            ApiClient(baseUrl: apiBaseUrl ?? 'https://api.industrynight.app'),
        _storage = storage ?? SecureStorage();

  // Getters
  User? get currentUser => _currentUser;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool get isLoggedIn => _currentUser != null;
  bool get isOnboarded => _currentUser?.profileCompleted ?? false;
  bool get isVerified =>
      _currentUser?.verificationStatus == VerificationStatus.verified;

  // API instances
  late final AuthApi authApi = AuthApi(_apiClient);
  late final UsersApi usersApi = UsersApi(_apiClient);
  late final EventsApi eventsApi = EventsApi(_apiClient);
  late final ConnectionsApi connectionsApi = ConnectionsApi(_apiClient);
  late final PostsApi postsApi = PostsApi(_apiClient);

  /// Initialize app state on startup
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isLoading = true;
    notifyListeners();

    try {
      // Check for existing token
      final token = await _storage.getAccessToken();
      if (token != null) {
        _apiClient.setToken(token);

        // Try to get current user
        try {
          _currentUser = await authApi.getCurrentUser();
        } catch (e) {
          // Token might be expired, try refresh
          final refreshToken = await _storage.getRefreshToken();
          if (refreshToken != null) {
            try {
              final response = await authApi.refreshToken(refreshToken);
              await _storage.saveTokens(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
              );
              _currentUser = response.user;
            } catch (_) {
              // Refresh failed, clear tokens
              await _storage.clearTokens();
              _apiClient.clearToken();
            }
          }
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isInitialized = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Request SMS verification code
  Future<void> requestVerificationCode(String phone) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await authApi.requestCode(normalizePhoneNumber(phone));
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Verify SMS code and log in
  Future<bool> verifyCode(String phone, String code) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response =
          await authApi.verifyCode(normalizePhoneNumber(phone), code);

      await _storage.saveTokens(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
      );
      await _storage.saveUserId(response.user.id);
      await _storage.saveUserPhone(response.user.phone);

      _currentUser = response.user;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update user profile
  Future<void> updateProfile({
    String? name,
    String? email,
    String? bio,
    List<String>? specialties,
    SocialLinks? socialLinks,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentUser = await usersApi.updateProfile(
        name: name,
        email: email,
        bio: bio,
        specialties: specialties,
        socialLinks: socialLinks,
      );
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Upload profile photo
  Future<void> uploadProfilePhoto(List<int> imageBytes, String filename) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentUser = await usersApi.uploadProfilePhoto(imageBytes, filename);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Log out
  Future<void> logout() async {
    try {
      await authApi.logout();
    } catch (_) {
      // Ignore logout errors
    }

    await _storage.clearAll();
    _apiClient.clearToken();
    _currentUser = null;
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
