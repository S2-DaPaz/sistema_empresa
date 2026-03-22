import 'package:flutter/material.dart';

/// Tokens visuais centrais da UI mobile.
///
/// O pack visual usa uma linguagem enterprise leve, com fundo frio,
/// gradientes azul-ciano e cartões muito arredondados. Centralizar esses
/// valores evita que cada tela replique "ajustes finos" de forma isolada.
class AppTokens {
  static const Color primaryCyan = Color(0xFF1AA7D6);
  static const Color supportTeal = Color(0xFF14C2A3);
  static const Color accentBlue = Color(0xFF2A67F1);
  static const Color accentViolet = Color(0xFF5867FF);
  static const Color bgLight = Color(0xFFF3F7FB);
  static const Color bgSoft = Color(0xFFEFF5FB);
  static const Color bgDark = Color(0xFF0E1623);
  static const Color fieldFill = Color(0xFFE8F2F8);
  static const Color fieldBorder = Color(0xFFC7D9E6);
  static const Color textStrong = Color(0xFF223146);
  static const Color textMuted = Color(0xFF738398);
  static const Color surfaceLight = Colors.white;
  static const Color success = Color(0xFF17A775);
  static const Color warning = Color(0xFFF7A531);
  static const Color danger = Color(0xFFE45757);

  static const double radiusXs = 14;
  static const double radiusSm = 18;
  static const double radiusMd = 24;
  static const double radiusLg = 30;
  static const double radiusPill = 999;

  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space7 = 28;

  static const List<BoxShadow> softShadow = [
    BoxShadow(
      color: Color(0x120F2B60),
      blurRadius: 30,
      offset: Offset(0, 12),
    ),
  ];

  static const List<BoxShadow> softShadowSm = [
    BoxShadow(
      color: Color(0x0F0F2B60),
      blurRadius: 18,
      offset: Offset(0, 8),
    ),
  ];

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF143B7B),
      Color(0xFF215FE4),
      Color(0xFF1AA7D6),
    ],
  );

  static const LinearGradient softBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFF4F8FC),
      Color(0xFFEAF2F9),
      Color(0xFFF7FBFD),
    ],
  );
}
