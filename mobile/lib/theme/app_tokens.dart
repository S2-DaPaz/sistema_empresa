import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF245BEB);
  static const Color primaryDark = Color(0xFF1B46C5);
  static const Color primarySoft = Color(0xFFEDF4FF);
  static const Color secondary = Color(0xFF14C2A3);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF7F9FC);
  static const Color backgroundAlt = Color(0xFFF2F5FA);
  static const Color ink = Color(0xFF121826);
  static const Color muted = Color(0xFF5B6475);
  static const Color border = Color(0xFFE4EAF3);
  static const Color success = Color(0xFF12B76A);
  static const Color warning = Color(0xFFF79009);
  static const Color danger = Color(0xFFF04438);
  static const Color info = Color(0xFF2E90FA);
}

class AppDarkColors {
  static const Color backgroundBase = Color(0xFF06111B);
  static const Color backgroundSecondary = Color(0xFF0A1724);
  static const Color surface1 = Color(0xFF101C2B);
  static const Color surface2 = Color(0xFF142235);
  static const Color surface3 = Color(0xFF1A2B42);
  static const Color borderSubtle = Color(0x295CA0FF);
  static const Color primary = Color(0xFF22B8FF);
  static const Color primaryPressed = Color(0xFF119FE6);
  static const Color primarySoft = Color(0xFF66D6FF);
  static const Color premium = Color(0xFFF4A640);
  static const Color textPrimary = Color(0xFFF3F8FF);
  static const Color textSecondary = Color(0xFF9CB4CC);
  static const Color textTertiary = Color(0xFF6E8398);
  static const Color success = Color(0xFF2ED19A);
  static const Color error = Color(0xFFFF5E7A);
  static const Color warning = Color(0xFFF4A640);
  static const Color overlay = Color(0xB802080F);
  static const Color glowPrimary = Color(0x3822B8FF);
}

class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
}

class AppRadius {
  static const double sm = 12;
  static const double md = 18;
  static const double lg = 24;
  static const double xl = 30;
  static const double pill = 999;
}

class AppGradients {
  static const LinearGradient darkScaffold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppDarkColors.backgroundBase,
      AppDarkColors.backgroundSecondary,
      Color(0xFF091D2D),
    ],
    stops: [0, 0.52, 1],
  );

  static const LinearGradient darkSurface = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppDarkColors.surface1,
      AppDarkColors.surface2,
    ],
  );

  static const LinearGradient darkHero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF081522),
      Color(0xFF0E2840),
      Color(0xFF123F66),
    ],
    stops: [0, 0.48, 1],
  );

  static const LinearGradient darkNavigation = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xF0122030),
      Color(0xF8152438),
    ],
  );

  static const LinearGradient darkPrimaryAction = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppDarkColors.primarySoft,
      AppDarkColors.primary,
    ],
  );
}

class AppShadows {
  static List<BoxShadow> get card => const [
        BoxShadow(
          color: Color(0x1A121826),
          blurRadius: 32,
          offset: Offset(0, 12),
        ),
      ];

  static List<BoxShadow> get darkCard => const [
        BoxShadow(
          color: Color(0x8002080F),
          blurRadius: 28,
          offset: Offset(0, 16),
        ),
        BoxShadow(
          color: AppDarkColors.glowPrimary,
          blurRadius: 24,
          spreadRadius: -12,
        ),
      ];

  static List<BoxShadow> get darkGlow => const [
        BoxShadow(
          color: AppDarkColors.glowPrimary,
          blurRadius: 22,
          spreadRadius: -6,
        ),
      ];
}
