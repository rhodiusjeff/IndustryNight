import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:industrynight_shared/shared.dart';

/// Isolated state for the networking/connect feature.
/// Receives API clients via constructor — no dependency on AppState.
class NetworkingState extends ChangeNotifier {
  final ConnectionsApi _connectionsApi;
  final String Function() _getCurrentUserId;
  final String? Function() _getActiveEventId;

  List<Connection> _connections = [];
  bool _isLoadingConnections = false;
  String? _error;
  bool _hasFetched = false;

  // Polling for new connection detection
  Timer? _pollTimer;
  bool _isPolling = false;
  final Set<String> _knownConnectionIds = {};
  Connection? _newConnection;
  bool _wasJustVerified = false;
  VerificationStatus? _prePollVerificationStatus;

  NetworkingState({
    required ConnectionsApi connectionsApi,
    required String Function() getCurrentUserId,
    String? Function()? getActiveEventId,
  })  : _connectionsApi = connectionsApi,
        _getCurrentUserId = getCurrentUserId,
        _getActiveEventId = getActiveEventId ?? (() => null);

  // Getters
  List<Connection> get connections => _connections;
  bool get isLoadingConnections => _isLoadingConnections;
  String? get error => _error;
  String get currentUserId => _getCurrentUserId();
  bool get hasFetched => _hasFetched;

  // Polling getters
  Connection? get newConnection => _newConnection;
  bool get wasJustVerified => _wasJustVerified;
  bool get isPolling => _isPolling;

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

  /// Create a connection from QR data. Returns the result including
  /// whether the current user was just auto-verified.
  Future<ConnectionResult?> createConnection(String qrData) async {
    _error = null;
    notifyListeners();

    try {
      final result = await _connectionsApi.createConnection(
        qrData,
        eventId: _getActiveEventId(),
      );
      _connections.insert(0, result.connection);
      // Track this connection so polling doesn't re-detect it
      _knownConnectionIds.add(result.connection.id);
      notifyListeners();
      return result;
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
      _knownConnectionIds.remove(connectionId);
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

  // ── Polling ─────────────────────────────────────────────────

  /// Begin polling for new connections. Call when QR code is displayed.
  void startPolling({required VerificationStatus currentVerificationStatus}) {
    if (_isPolling) return;
    _isPolling = true;
    _prePollVerificationStatus = currentVerificationStatus;

    // Snapshot current known IDs
    _knownConnectionIds.addAll(_connections.map((c) => c.id));

    // Initial fetch to ensure known IDs are current, then poll every 4 seconds
    _pollOnce();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _pollOnce());
  }

  /// Stop polling for new connections.
  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _isPolling = false;
  }

  Future<void> _pollOnce() async {
    try {
      final recent = await _connectionsApi.getConnections(limit: 5, offset: 0);

      // Find connections we haven't seen before
      final newOnes =
          recent.where((c) => !_knownConnectionIds.contains(c.id)).toList();

      // Always track all fetched IDs
      _knownConnectionIds.addAll(recent.map((c) => c.id));

      if (newOnes.isNotEmpty) {
        // Add new connections to the main list
        for (final conn in newOnes) {
          if (!_connections.any((c) => c.id == conn.id)) {
            _connections.insert(0, conn);
          }
        }

        // Surface the most recent new connection for celebration
        _newConnection = newOnes.first;
        _wasJustVerified =
            _prePollVerificationStatus == VerificationStatus.unverified;

        // Stop polling — resume after celebration is dismissed
        stopPolling();
        notifyListeners();
      }
    } catch (e) {
      // Silently swallow polling errors — don't disrupt QR display
      debugPrint('[NetworkingState] Poll error: $e');
    }
  }

  /// Clear the new connection notification after the celebration is dismissed.
  void clearNewConnectionNotification() {
    _newConnection = null;
    _wasJustVerified = false;
    notifyListeners();
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
