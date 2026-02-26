import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'config/routes.dart';
import 'shared/theme/app_theme.dart';
import 'providers/app_state.dart';

class IndustryNightApp extends StatefulWidget {
  const IndustryNightApp({super.key});

  @override
  State<IndustryNightApp> createState() => _IndustryNightAppState();
}

class _IndustryNightAppState extends State<IndustryNightApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    _router = AppRouter.router(appState);
    // Initialize app state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appState.initialize();
    });
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Industry Night',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: _router,
    );
  }
}
