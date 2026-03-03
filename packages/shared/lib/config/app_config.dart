/// Compile-time configuration passed via --dart-define.
///
/// Defaults are dev-safe. Production values are injected by deploy scripts.
///
/// Usage:
///   flutter run --dart-define=API_BASE_URL=https://api.industrynight.net
class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://dev-api.industrynight.net',
  );
}
