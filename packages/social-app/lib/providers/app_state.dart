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

  // Active event session (set on check-in, persisted across restarts)
  String? _activeEventId;
  String? _activeEventName;
  DateTime? _activeEventEndTime;

  AppState({
    String? apiBaseUrl,
    ApiClient? apiClient,
    SecureStorage? storage,
  })  : _apiClient = apiClient ??
            ApiClient(baseUrl: apiBaseUrl ?? AppConfig.apiBaseUrl),
        _storage = storage ?? SecureStorage() {
    // Wire up automatic token refresh on 401 responses
    _apiClient.onTokenExpired = _refreshAccessToken;
  }

  /// Attempt to refresh the access token using the stored refresh token.
  /// Returns true if refresh succeeded (caller should retry the request).
  Future<bool> _refreshAccessToken() async {
    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null) return false;

      final response = await authApi.refreshToken(refreshToken);
      await _storage.saveTokens(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
      );
      // authApi.refreshToken already calls _apiClient.setToken
      _currentUser = response.user;
      return true;
    } catch (e) {
      debugPrint('[AppState] Token refresh failed: $e');
      // Refresh failed — clear auth state so user gets redirected to login
      await _storage.clearTokens();
      _apiClient.clearToken();
      _currentUser = null;
      notifyListeners();
      return false;
    }
  }

  // Getters
  User? get currentUser => _currentUser;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool get isLoggedIn => _currentUser != null;
  bool get isOnboarded => _currentUser?.profileCompleted ?? false;
  bool get isVerified =>
      _currentUser?.verificationStatus == VerificationStatus.verified;

  // Active event session getters
  String? get activeEventId => hasActiveEvent ? _activeEventId : null;
  String? get activeEventName => hasActiveEvent ? _activeEventName : null;
  bool get hasActiveEvent {
    if (_activeEventId == null || _activeEventEndTime == null) return false;
    // Stored times are local-as-UTC; re-interpret for correct comparison
    final dt = _activeEventEndTime!;
    final localEnd = DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute,
        dt.second, dt.millisecond);
    return localEnd.isAfter(DateTime.now());
  }

  // API instances
  late final AuthApi authApi = AuthApi(_apiClient);
  late final UsersApi usersApi = UsersApi(_apiClient);
  late final EventsApi eventsApi = EventsApi(_apiClient);
  late final ConnectionsApi connectionsApi = ConnectionsApi(_apiClient);
  late final PostsApi postsApi = PostsApi(_apiClient);
  late final PerksApi perksApi = PerksApi(_apiClient);

  /// Initialize app state on startup
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isLoading = true;
    notifyListeners();

    try {
      // Restore active event session
      final activeEvent = await _storage.getActiveEvent();
      if (activeEvent != null) {
        // Stored times are local-as-UTC; re-interpret for correct comparison
        final dt = activeEvent.endTime;
        final localEnd = DateTime(dt.year, dt.month, dt.day, dt.hour,
            dt.minute, dt.second, dt.millisecond);
        if (localEnd.isAfter(DateTime.now())) {
          _activeEventId = activeEvent.id;
          _activeEventName = activeEvent.name;
          _activeEventEndTime = activeEvent.endTime;
        } else {
          // Expired — clean up
          await _storage.clearActiveEvent();
        }
      }

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
      debugPrint('[AppState] Initialize error: $e');
      _error = e.toString();
    } finally {
      _isInitialized = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Request SMS verification code
  /// Returns a dev code only when API dev OTP fallback is explicitly enabled
  Future<String?> requestVerificationCode(String phone) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      return await authApi.requestCode(normalizePhoneNumber(phone));
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
      debugPrint('[AppState] verifyCode API error: ${e.statusCode} ${e.message}');
      _error = e.message;
      return false;
    } catch (e, stackTrace) {
      debugPrint('[AppState] verifyCode unexpected error: $e');
      debugPrint('[AppState] Stack trace: $stackTrace');
      _error = 'An unexpected error occurred: $e';
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

  /// Delete the current user's account and clear all local data
  Future<bool> deleteAccount() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await authApi.deleteAccount();
      await _storage.clearAll();
      _currentUser = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      debugPrint('[AppState] deleteAccount API error: ${e.statusCode} ${e.message}');
      _error = e.message;
      return false;
    } catch (e, stackTrace) {
      debugPrint('[AppState] deleteAccount unexpected error: $e');
      debugPrint('[AppState] Stack trace: $stackTrace');
      _error = 'An unexpected error occurred: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Set active event session (called after successful check-in)
  Future<void> setActiveEvent({
    required String eventId,
    required String name,
    required DateTime endTime,
  }) async {
    _activeEventId = eventId;
    _activeEventName = name;
    _activeEventEndTime = endTime;
    await _storage.saveActiveEvent(
      eventId: eventId,
      eventName: name,
      endTime: endTime,
    );
    notifyListeners();
  }

  /// Clear active event session
  Future<void> clearActiveEvent() async {
    _activeEventId = null;
    _activeEventName = null;
    _activeEventEndTime = null;
    await _storage.clearActiveEvent();
    notifyListeners();
  }

  /// Log out — preserves remembered phone for "Remember Me"
  Future<void> logout() async {
    try {
      await authApi.logout();
    } catch (_) {
      // Ignore logout errors
    }

    _activeEventId = null;
    _activeEventName = null;
    _activeEventEndTime = null;
    await _storage.clearAuthData();
    _apiClient.clearToken();
    _currentUser = null;
    notifyListeners();
  }

  /// Update local user to verified status (after first connection).
  void setVerified() {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(
        verificationStatus: VerificationStatus.verified,
      );
      notifyListeners();
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
