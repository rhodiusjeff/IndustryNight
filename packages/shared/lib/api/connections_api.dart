import 'api_client.dart';
import '../models/connection.dart';

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

  /// Create a connection from QR code scan (instant connection)
  Future<Connection> createConnection(String qrData, {String? eventId}) async {
    final body = <String, dynamic>{'qrData': qrData};
    if (eventId != null) body['eventId'] = eventId;

    final response = await _client.post<Map<String, dynamic>>(
      '/connections',
      body: body,
    );
    return Connection.fromJson(response['connection'] as Map<String, dynamic>);
  }

  /// Remove a connection
  Future<void> removeConnection(String connectionId) async {
    await _client.delete('/connections/$connectionId');
  }
}
