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
  static const double pill = 999;
}

class AppShadows {
  static List<BoxShadow> get card => const [
        BoxShadow(
          color: Color(0x1A121826),
          blurRadius: 32,
          offset: Offset(0, 12),
        ),
      ];
}
