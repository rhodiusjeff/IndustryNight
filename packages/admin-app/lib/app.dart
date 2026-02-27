import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'config/routes.dart';
import 'shared/theme/admin_theme.dart';
import 'providers/admin_state.dart';

class IndustryNightAdminApp extends StatefulWidget {
  const IndustryNightAdminApp({super.key});

  @override
  State<IndustryNightAdminApp> createState() => _IndustryNightAdminAppState();
}

class _IndustryNightAdminAppState extends State<IndustryNightAdminApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final adminState = context.read<AdminState>();
    // GoRouter MUST be created once — not inside a Consumer/builder that
    // rebuilds on notifyListeners(). refreshListenable handles re-evaluation.
    _router = AdminRouter.router(adminState);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      adminState.initialize();
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
      title: 'Industry Night Admin',
      debugShowCheckedModeBanner: false,
      theme: AdminTheme.lightTheme,
      darkTheme: AdminTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: _router,
    );
  }
}
