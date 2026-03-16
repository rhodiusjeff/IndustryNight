import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:industrynight_shared/shared.dart';
import 'app.dart';
import 'providers/app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final apiBaseUrl = AppConfig.apiBaseUrl;
  debugPrint('[Startup] API_BASE_URL: $apiBaseUrl');
  if (!kReleaseMode && apiBaseUrl == 'https://api.industrynight.net') {
    debugPrint(
      '[Startup][WARNING] Debug build is pointing to production API. '
      'Use --dart-define=API_BASE_URL=https://dev-api.industrynight.net',
    );
  }

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const IndustryNightApp(),
    ),
  );
}
