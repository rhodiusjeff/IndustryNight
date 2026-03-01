/// Compile-time configuration passed via --dart-define.
///
/// Usage:
///   flutter run --dart-define=GOOGLE_PLACES_API_KEY=AIza...
class AppConfig {
  static const String googlePlacesApiKey = String.fromEnvironment(
    'GOOGLE_PLACES_API_KEY',
    defaultValue: '',
  );

  static bool get hasGooglePlaces => googlePlacesApiKey.isNotEmpty;
}
