import 'package:flutter/material.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminState>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminState>(
      builder: (context, adminState, _) {
        return MaterialApp.router(
          title: 'Industry Night Admin',
          debugShowCheckedModeBanner: false,
          theme: AdminTheme.lightTheme,
          darkTheme: AdminTheme.darkTheme,
          themeMode: ThemeMode.light,
          routerConfig: AdminRouter.router(adminState),
        );
      },
    );
  }
}
