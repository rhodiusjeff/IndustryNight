import 'package:flutter/foundation.dart';
import 'package:industrynight_shared/shared.dart';

class AdminState extends ChangeNotifier {
  final ApiClient _apiClient;
  final SecureStorage _storage;

  User? _currentUser;
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

  User? get currentUser => _currentUser;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _currentUser != null;

  late final AuthApi authApi = AuthApi(_apiClient);
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
          _currentUser = await authApi.getCurrentUser();
          // Verify admin role
          if (!(_currentUser?.isAdmin ?? false)) {
            await logout();
          }
        } catch (_) {
          await _storage.clearTokens();
          _apiClient.clearToken();
        }
      }
    } finally {
      _isInitialized = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String phone, String code) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await authApi.verifyCode(normalizePhoneNumber(phone), code);

      // Check admin role
      if (!response.user.isAdmin) {
        _error = 'Access denied. Admin privileges required.';
        return false;
      }

      await _storage.saveTokens(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
      );
      _currentUser = response.user;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await authApi.logout();
    } catch (_) {}

    await _storage.clearAll();
    _apiClient.clearToken();
    _currentUser = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
