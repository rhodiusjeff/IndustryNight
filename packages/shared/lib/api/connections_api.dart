import 'api_client.dart';
import '../models/connection.dart';

/// Result of creating a connection, including whether the user was just verified.
class ConnectionResult {
  final Connection connection;
  final bool justVerified;

  const ConnectionResult({required this.connection, this.justVerified = false});
}

/// API client for connection/networking endpoints
class ConnectionsApi {
  final ApiClient _client;

  ConnectionsApi(this._client);

  /// Get user's connections
  Future<List<Connection>> getConnections({
    int limit = 50,
    int offset = 0,
  }) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };

    final response = await _client.get<Map<String, dynamic>>(
      '/connections',
      queryParams: queryParams,
    );

    return (response['connections'] as List)
        .map((c) => Connection.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  /// Create a connection from QR code scan (instant connection).
  /// Returns a [ConnectionResult] which includes whether the current user
  /// was just auto-verified (first connection).
  Future<ConnectionResult> createConnection(String qrData, {String? eventId}) async {
    final body = <String, dynamic>{'qrData': qrData};
    if (eventId != null) body['eventId'] = eventId;

    final response = await _client.post<Map<String, dynamic>>(
      '/connections',
      body: body,
    );
    return ConnectionResult(
      connection: Connection.fromJson(response['connection'] as Map<String, dynamic>),
      justVerified: response['justVerified'] == true,
    );
  }

  /// Remove a connection
  Future<void> removeConnection(String connectionId) async {
    await _client.delete('/connections/$connectionId');
  }
}
