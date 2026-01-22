import 'package:flutter/material.dart';

import '../screens/home_shell.dart';
import '../screens/login_screen.dart';
import '../services/auth_service.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    AuthService.instance.restore().whenComplete(() {
      if (mounted) {
        setState(() => _loading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return ValueListenableBuilder<AuthSession?>(
      valueListenable: AuthService.instance.session,
      builder: (context, session, _) {
        if (session == null) {
          return const LoginScreen();
        }
        return const HomeShell();
      },
    );
  }
}
