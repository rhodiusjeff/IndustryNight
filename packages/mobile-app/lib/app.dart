import 'package:flutter/material.dart';
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
  @override
  void initState() {
    super.initState();
    // Initialize app state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return MaterialApp.router(
          title: 'Industry Night',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          routerConfig: AppRouter.router(appState),
        );
      },
    );
  }
}
