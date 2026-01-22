import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color ink = Color(0xFF0C1B2A);
  static const Color muted = Color(0xFF4F6474);
  static const Color accent = Color(0xFF1AA7D6);
  static const Color accent2 = Color(0xFF14C2A3);
  static const Color accent3 = Color(0xFF2A67F1);
  static const Color panel = Color(0xFFF3F8FC);
  static const Color fieldBg = Color(0xFFE2EEF6);
  static const Color fieldBorder = Color(0xFFC3D6E3);

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    final colorScheme = base.colorScheme.copyWith(
      primary: accent,
      secondary: accent2,
      tertiary: accent3,
      surface: panel,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: ink,
    );

    final textTheme = GoogleFonts.soraTextTheme(base.textTheme).copyWith(
      headlineSmall: GoogleFonts.spaceGrotesk(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      titleMedium: GoogleFonts.spaceGrotesk(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFE6EFF5),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: textTheme.titleMedium,
        iconTheme: const IconThemeData(color: ink),
      ),
      cardTheme: CardThemeData(
        color: panel,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: fieldBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: fieldBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accent),
        ),
        labelStyle: const TextStyle(
          color: muted,
          letterSpacing: 0.6,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          side: const BorderSide(color: fieldBorder),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: accent3.withValues(alpha: 0.12),
        labelStyle: const TextStyle(color: Color(0xFF1D49A2)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );
  }
}
