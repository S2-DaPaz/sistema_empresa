import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import 'widgets/auth_gate.dart';
import 'services/theme_service.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.instance.mode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'RV TecnoCare',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: mode,
          home: const AuthGate(),
        );
      },
    );
  }
}
