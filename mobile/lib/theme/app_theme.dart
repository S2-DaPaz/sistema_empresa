import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_tokens.dart';

class AppTheme {
  static ThemeData light() => _buildTheme(Brightness.light);

  static ThemeData dark() => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final base = ThemeData(useMaterial3: true, brightness: brightness);
    final seedScheme = ColorScheme.fromSeed(
      seedColor: AppTokens.primaryBlue,
      brightness: brightness,
    );
    final scheme = seedScheme.copyWith(
      primary: AppTokens.primaryBlue,
      onPrimary: Colors.white,
      primaryContainer:
          isDark ? const Color(0xFF16305A) : const Color(0xFFE7EFFF),
      onPrimaryContainer: isDark ? Colors.white : AppTokens.primaryBlueDark,
      secondary: AppTokens.primaryCyan,
      onSecondary: Colors.white,
      secondaryContainer:
          isDark ? const Color(0xFF122A37) : const Color(0xFFE7F7FC),
      onSecondaryContainer: isDark ? Colors.white : AppTokens.textStrong,
      tertiary: AppTokens.supportTeal,
      onTertiary: Colors.white,
      tertiaryContainer:
          isDark ? const Color(0xFF103126) : AppTokens.successSoft,
      onTertiaryContainer: isDark ? Colors.white : AppTokens.supportTeal,
      error: AppTokens.danger,
      onError: Colors.white,
      errorContainer: isDark ? const Color(0xFF3C1D22) : AppTokens.dangerSoft,
      onErrorContainer: isDark ? Colors.white : AppTokens.danger,
      surface: isDark ? const Color(0xFF132034) : Colors.white,
      onSurface: isDark ? const Color(0xFFF4F7FB) : AppTokens.textStrong,
      outline: isDark ? const Color(0xFF35506F) : AppTokens.fieldBorder,
      outlineVariant:
          isDark ? const Color(0xFF24354E) : const Color(0xFFE4EBF3),
      shadow: const Color(0x16081B4D),
      scrim: Colors.black.withValues(alpha: 0.45),
      surfaceTint: Colors.transparent,
      inverseSurface: isDark ? Colors.white : AppTokens.bgDark,
      onInverseSurface: isDark ? AppTokens.bgDark : Colors.white,
      inversePrimary: AppTokens.primaryCyan,
    );

    final bodyText = GoogleFonts.manropeTextTheme(base.textTheme);
    final textTheme = bodyText.copyWith(
      displaySmall: GoogleFonts.manrope(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        height: 1.02,
        color: scheme.onSurface,
      ),
      headlineMedium: GoogleFonts.manrope(
        fontSize: 29,
        fontWeight: FontWeight.w800,
        height: 1.05,
        color: scheme.onSurface,
      ),
      headlineSmall: GoogleFonts.manrope(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        height: 1.12,
        color: scheme.onSurface,
      ),
      titleLarge: GoogleFonts.manrope(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        height: 1.15,
        color: scheme.onSurface,
      ),
      titleMedium: GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: scheme.onSurface,
      ),
      titleSmall: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: scheme.onSurface,
      ),
      bodyLarge: GoogleFonts.manrope(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.45,
        color: scheme.onSurface,
      ),
      bodyMedium: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.45,
        color: scheme.onSurface,
      ),
      bodySmall: GoogleFonts.manrope(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        height: 1.42,
        color: scheme.onSurface.withValues(alpha: 0.62),
      ),
      labelLarge: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        height: 1.1,
        color: scheme.onSurface,
      ),
      labelMedium: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        height: 1.1,
        color: scheme.onSurface.withValues(alpha: 0.78),
      ),
      labelSmall: GoogleFonts.manrope(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        height: 1.1,
        color: scheme.onSurface.withValues(alpha: 0.58),
      ),
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? AppTokens.bgDark : AppTokens.bgLight,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: Colors.white),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF15253A) : AppTokens.fieldFill,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurface.withValues(alpha: 0.42),
        ),
        labelStyle: textTheme.labelMedium,
        prefixIconColor: scheme.onSurface.withValues(alpha: 0.58),
        suffixIconColor: scheme.onSurface.withValues(alpha: 0.58),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space4,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shadowColor: Colors.transparent,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size.fromHeight(56),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.space5,
            vertical: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          elevation: 0,
          foregroundColor: scheme.onSurface,
          minimumSize: const Size.fromHeight(54),
          side: BorderSide(color: scheme.outlineVariant),
          backgroundColor: scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF17263A) : AppTokens.bgDark,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: scheme.surface,
        selectedColor: scheme.primary.withValues(alpha: 0.14),
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        ),
        labelStyle: textTheme.labelMedium,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: 0.1),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: scheme.onSurface.withValues(alpha: 0.55),
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge,
        splashFactory: NoSplash.splashFactory,
      ),
    );
  }
}
