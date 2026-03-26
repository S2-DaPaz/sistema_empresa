import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../screens/home_shell.dart';
import '../screens/login_screen.dart';
import '../services/auth_service.dart';
import '../theme/app_assets.dart';
import '../services/update_service.dart';
import '../theme/app_tokens.dart';
import 'brand_logo.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    AuthService.instance.restore().whenComplete(() {
      if (mounted) {
        setState(() => _carregando = false);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      UpdateService.instance.checkForUpdate(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const _SplashGate();
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

class _SplashGate extends StatelessWidget {
  const _SplashGate();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? AppGradients.darkHero
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -140,
              right: -60,
              child: _Shape(
                size: 240,
                color: isDark ? AppDarkColors.glowPrimary : Colors.white,
                opacity: isDark ? 0.38 : 0.08,
              ),
            ),
            Positioned(
              bottom: -120,
              left: -40,
              child: _Shape(
                size: 220,
                color: isDark ? const Color(0x1AF4A640) : Colors.white,
                opacity: isDark ? 0.28 : 0.07,
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: isDark ? 0.08 : 0.2,
                  child: SvgPicture.asset(
                    AppAssets.splashBackground,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const BrandLogo(
                        height: 80,
                        color: Colors.white,
                        monogram: true,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Sistema Empresa',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Uma camada única de operação para tarefas, clientes e orçamentos.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.82),
                            ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.8,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Shape extends StatelessWidget {
  const _Shape({
    required this.size,
    required this.color,
    required this.opacity,
  });

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(52),
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}
