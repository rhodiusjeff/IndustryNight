import 'package:flutter/foundation.dart';
import 'package:industrynight_shared/shared.dart';

class AdminState extends ChangeNotifier {
  final ApiClient _apiClient;
  final SecureStorage _storage;

  AdminUser? _currentAdmin;
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;

  AdminState({
    String? apiBaseUrl,
    ApiClient? apiClient,
    SecureStorage? storage,
  })  : _apiClient = apiClient ??
            ApiClient(baseUrl: apiBaseUrl ?? 'https://api.industrynight.net'),
        _storage = storage ?? SecureStorage();

  AdminUser? get currentAdmin => _currentAdmin;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _currentAdmin != null;

  late final AdminAuthApi adminAuthApi = AdminAuthApi(_apiClient);
  late final AdminApi adminApi = AdminApi(_apiClient);

  Future<void> initialize() async {
    if (_isInitialized) return;

    _isLoading = true;
    notifyListeners();

    try {
      final token = await _storage.getAccessToken();
      if (token != null) {
        _apiClient.setToken(token);
        try {
          _currentAdmin = await adminAuthApi.getCurrentAdmin();
        } catch (_) {
          // Token expired or invalid — try refresh
          final refreshToken = await _storage.getRefreshToken();
          if (refreshToken != null) {
            try {
              final response = await adminAuthApi.refreshToken(refreshToken);
              await _storage.saveTokens(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
              );
              _currentAdmin = response.admin;
            } catch (_) {
              await _storage.clearTokens();
              _apiClient.clearToken();
            }
          } else {
            await _storage.clearTokens();
            _apiClient.clearToken();
          }
        }
      }
    } finally {
      _isInitialized = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await adminAuthApi.login(email, password);

      await _storage.saveTokens(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
      );
      _currentAdmin = response.admin;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      debugPrint('[AdminState] ApiException: ${e.message}');
      return false;
    } catch (e) {
      _error = e.toString();
      debugPrint('[AdminState] Unexpected error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await adminAuthApi.logout();
    } catch (_) {}

    await _storage.clearAll();
    _apiClient.clearToken();
    _currentAdmin = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
