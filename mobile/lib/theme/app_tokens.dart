import 'package:flutter/material.dart';

/// Tokens visuais centrais da UI mobile.
///
/// A nova base segue as referências mobile: header azul profundo,
/// superfícies brancas suaves e feedback cromático claro para operação.
class AppTokens {
  static const Color primaryBlue = Color(0xFF0D57D8);
  static const Color primaryBlueDark = Color(0xFF08398D);
  static const Color primaryCyan = Color(0xFF25B9E5);
  static const Color supportTeal = Color(0xFF1FB57A);
  static const Color accentBlue = Color(0xFF2E6BFF);
  static const Color accentViolet = Color(0xFF5067F8);
  static const Color bgLight = Color(0xFFF4F7FB);
  static const Color bgSoft = Color(0xFFEAF2FB);
  static const Color bgDark = Color(0xFF0E1623);
  static const Color fieldFill = Color(0xFFF7FAFD);
  static const Color fieldBorder = Color(0xFFD8E3EE);
  static const Color fieldTint = Color(0xFFEDF4FB);
  static const Color textStrong = Color(0xFF17263C);
  static const Color textMuted = Color(0xFF6D7E94);
  static const Color surfaceLight = Colors.white;
  static const Color success = Color(0xFF19AA6E);
  static const Color successSoft = Color(0xFFE7F8F0);
  static const Color warning = Color(0xFFF2B64C);
  static const Color warningSoft = Color(0xFFFFF5DE);
  static const Color danger = Color(0xFFE05858);
  static const Color dangerSoft = Color(0xFFFFECEC);
  static const Color neutralSoft = Color(0xFFF1F5F9);

  static const double radiusXs = 12;
  static const double radiusSm = 18;
  static const double radiusMd = 24;
  static const double radiusLg = 30;
  static const double radiusXl = 38;
  static const double radiusPill = 999;

  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space7 = 28;
  static const double space8 = 32;

  static const List<BoxShadow> softShadow = [
    BoxShadow(
      color: Color(0x14081B4D),
      blurRadius: 34,
      offset: Offset(0, 16),
    ),
  ];

  static const List<BoxShadow> softShadowSm = [
    BoxShadow(
      color: Color(0x10081B4D),
      blurRadius: 20,
      offset: Offset(0, 10),
    ),
  ];

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      primaryBlueDark,
      primaryBlue,
      primaryCyan,
    ],
  );

  static const LinearGradient warmGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF59E39),
      Color(0xFFF7C76B),
      Color(0xFFFCE6B6),
    ],
  );

  static const LinearGradient softBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFF6F9FC),
      Color(0xFFF1F5FA),
      Color(0xFFF8FBFE),
    ],
  );
}
