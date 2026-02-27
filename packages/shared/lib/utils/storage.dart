import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keys for secure storage
class StorageKeys {
  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String userId = 'user_id';
  static const String userPhone = 'user_phone';
  static const String onboardingComplete = 'onboarding_complete';
  static const String activeEventId = 'active_event_id';
  static const String activeEventName = 'active_event_name';
  static const String activeEventEndTime = 'active_event_end_time';
}

/// Secure storage wrapper for auth tokens and sensitive data
class SecureStorage {
  final FlutterSecureStorage _storage;

  SecureStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  // Token management
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _storage.write(key: StorageKeys.accessToken, value: accessToken),
      _storage.write(key: StorageKeys.refreshToken, value: refreshToken),
    ]);
  }

  Future<String?> getAccessToken() async {
    return _storage.read(key: StorageKeys.accessToken);
  }

  Future<String?> getRefreshToken() async {
    return _storage.read(key: StorageKeys.refreshToken);
  }

  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: StorageKeys.accessToken),
      _storage.delete(key: StorageKeys.refreshToken),
    ]);
  }

  // User info
  Future<void> saveUserId(String userId) async {
    await _storage.write(key: StorageKeys.userId, value: userId);
  }

  Future<String?> getUserId() async {
    return _storage.read(key: StorageKeys.userId);
  }

  Future<void> saveUserPhone(String phone) async {
    await _storage.write(key: StorageKeys.userPhone, value: phone);
  }

  Future<String?> getUserPhone() async {
    return _storage.read(key: StorageKeys.userPhone);
  }

  // Onboarding
  Future<void> setOnboardingComplete(bool complete) async {
    await _storage.write(
      key: StorageKeys.onboardingComplete,
      value: complete.toString(),
    );
  }

  Future<bool> isOnboardingComplete() async {
    final value = await _storage.read(key: StorageKeys.onboardingComplete);
    return value == 'true';
  }

  // Active event session (persists check-in state across app restarts)
  Future<void> saveActiveEvent({
    required String eventId,
    required String eventName,
    required DateTime endTime,
  }) async {
    await Future.wait([
      _storage.write(key: StorageKeys.activeEventId, value: eventId),
      _storage.write(key: StorageKeys.activeEventName, value: eventName),
      _storage.write(
        key: StorageKeys.activeEventEndTime,
        value: endTime.toIso8601String(),
      ),
    ]);
  }

  Future<({String id, String name, DateTime endTime})?> getActiveEvent() async {
    final results = await Future.wait([
      _storage.read(key: StorageKeys.activeEventId),
      _storage.read(key: StorageKeys.activeEventName),
      _storage.read(key: StorageKeys.activeEventEndTime),
    ]);

    final id = results[0];
    final name = results[1];
    final endTimeStr = results[2];

    if (id == null || name == null || endTimeStr == null) return null;

    return (
      id: id,
      name: name,
      endTime: DateTime.parse(endTimeStr),
    );
  }

  Future<void> clearActiveEvent() async {
    await Future.wait([
      _storage.delete(key: StorageKeys.activeEventId),
      _storage.delete(key: StorageKeys.activeEventName),
      _storage.delete(key: StorageKeys.activeEventEndTime),
    ]);
  }

  // Generic methods
  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  Future<String?> read(String key) async {
    return _storage.read(key: key);
  }

  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  Future<bool> hasToken() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}
