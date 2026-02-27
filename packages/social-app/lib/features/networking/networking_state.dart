import 'package:flutter/foundation.dart';
import 'package:industrynight_shared/shared.dart';

/// Isolated state for the networking/connect feature.
/// Receives API clients via constructor — no dependency on AppState.
class NetworkingState extends ChangeNotifier {
  final ConnectionsApi _connectionsApi;
  final UsersApi _usersApi;
  final String Function() _getCurrentUserId;
  final String? Function() _getActiveEventId;

  List<Connection> _connections = [];
  User? _scannedUser;
  bool _isLoadingConnections = false;
  bool _isScanning = false;
  String? _error;
  bool _hasFetched = false;

  NetworkingState({
    required ConnectionsApi connectionsApi,
    required UsersApi usersApi,
    required String Function() getCurrentUserId,
    String? Function()? getActiveEventId,
  })  : _connectionsApi = connectionsApi,
        _usersApi = usersApi,
        _getCurrentUserId = getCurrentUserId,
        _getActiveEventId = getActiveEventId ?? (() => null);

  // Getters
  List<Connection> get connections => _connections;
  User? get scannedUser => _scannedUser;
  bool get isLoadingConnections => _isLoadingConnections;
  bool get isScanning => _isScanning;
  String? get error => _error;
  String get currentUserId => _getCurrentUserId();
  bool get hasFetched => _hasFetched;

  /// Fetch connections from API. Skips if already fetched unless [force] is true.
  Future<void> fetchConnections({bool force = false}) async {
    if (_isLoadingConnections) return;
    if (_hasFetched && !force) return;

    _isLoadingConnections = true;
    _error = null;
    notifyListeners();

    try {
      _connections = await _connectionsApi.getConnections();
      _hasFetched = true;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoadingConnections = false;
      notifyListeners();
    }
  }

  /// Look up a user by ID (after scanning their QR code).
  Future<User?> lookupScannedUser(String userId) async {
    _isScanning = true;
    _scannedUser = null;
    _error = null;
    notifyListeners();

    try {
      _scannedUser = await _usersApi.getUser(userId);
      return _scannedUser;
    } on ApiException catch (e) {
      _error = e.message;
      return null;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  /// Create a connection from QR data. Returns the new connection on success.
  Future<Connection?> createConnection(String qrData) async {
    _error = null;
    notifyListeners();

    try {
      final connection = await _connectionsApi.createConnection(
        qrData,
        eventId: _getActiveEventId(),
      );
      _connections.insert(0, connection);
      notifyListeners();
      return connection;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Remove a connection by ID.
  Future<bool> removeConnection(String connectionId) async {
    _error = null;

    try {
      await _connectionsApi.removeConnection(connectionId);
      _connections.removeWhere((c) => c.id == connectionId);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Clear the scanned user (e.g. when dismissing the sheet).
  void clearScannedUser() {
    _scannedUser = null;
    notifyListeners();
  }
}
