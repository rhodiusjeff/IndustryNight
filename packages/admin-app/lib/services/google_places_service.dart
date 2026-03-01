import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// A prediction returned by Google Places Autocomplete.
class PlacePrediction {
  final String fullText;
  final String mainText;
  final String secondaryText;
  final String placeId;

  const PlacePrediction({
    required this.fullText,
    required this.mainText,
    required this.secondaryText,
    required this.placeId,
  });
}

/// Service for Google Places Autocomplete (New) REST API.
///
/// Uses session tokens to group autocomplete requests + the eventual
/// selection into a single billing session.
class GooglePlacesService {
  static const _baseUrl =
      'https://places.googleapis.com/v1/places:autocomplete';

  final http.Client _client;
  String _sessionToken;

  GooglePlacesService({http.Client? client})
      : _client = client ?? http.Client(),
        _sessionToken = _generateSessionToken();

  static String _generateSessionToken() {
    final random = Random();
    return List.generate(32, (_) => random.nextInt(16).toRadixString(16))
        .join();
  }

  /// Reset the session token. Call after the user selects a prediction
  /// or abandons the autocomplete.
  void resetSession() {
    _sessionToken = _generateSessionToken();
  }

  /// Fetch autocomplete predictions for [input].
  ///
  /// Returns an empty list on error or if the API key is not configured.
  Future<List<PlacePrediction>> getAutocompletePredictions(String input) async {
    if (input.trim().length < 3) return [];
    if (!AppConfig.hasGooglePlaces) return [];

    try {
      final response = await _client.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': AppConfig.googlePlacesApiKey,
          'X-Goog-FieldMask': 'suggestions.placePrediction.placeId,'
              'suggestions.placePrediction.text,'
              'suggestions.placePrediction.structuredFormat',
        },
        body: jsonEncode({
          'input': input,
          'sessionToken': _sessionToken,
          'includedPrimaryTypes': [
            'street_address',
            'premise',
            'subpremise',
            'establishment',
          ],
          'includedRegionCodes': ['us'],
        }),
      );

      if (response.statusCode != 200) {
        debugPrint(
            '[GooglePlaces] Error ${response.statusCode}: ${response.body}');
        return [];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final suggestions = data['suggestions'] as List? ?? [];

      return suggestions.map((s) {
        final prediction = s['placePrediction'] as Map<String, dynamic>;
        final text = prediction['text'] as Map<String, dynamic>;
        final structured =
            prediction['structuredFormat'] as Map<String, dynamic>?;

        return PlacePrediction(
          fullText: text['text'] as String? ?? '',
          mainText: (structured?['mainText']
                  as Map<String, dynamic>?)?['text'] as String? ??
              '',
          secondaryText: (structured?['secondaryText']
                  as Map<String, dynamic>?)?['text'] as String? ??
              '',
          placeId: prediction['placeId'] as String? ?? '',
        );
      }).toList();
    } catch (e) {
      debugPrint('[GooglePlaces] Exception: $e');
      return [];
    }
  }

  void dispose() {
    _client.close();
  }
}
