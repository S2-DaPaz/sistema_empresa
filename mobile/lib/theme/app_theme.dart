import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_tokens.dart';

class AppTheme {
  static ThemeData light() => _buildTheme(Brightness.light);

  static ThemeData dark() => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
    );

    final scheme = ColorScheme.fromSeed(
      seedColor: isDark ? AppDarkColors.primary : AppColors.primary,
      brightness: brightness,
    ).copyWith(
      primary: isDark ? AppDarkColors.primary : AppColors.primary,
      onPrimary: isDark ? AppDarkColors.backgroundBase : Colors.white,
      primaryContainer: isDark ? AppDarkColors.surface3 : AppColors.primarySoft,
      onPrimaryContainer:
          isDark ? AppDarkColors.textPrimary : AppColors.primaryDark,
      secondary: isDark ? AppDarkColors.primarySoft : AppColors.secondary,
      onSecondary: isDark ? AppDarkColors.backgroundBase : Colors.white,
      secondaryContainer:
          isDark ? const Color(0xFF113049) : const Color(0xFFE8F7F4),
      onSecondaryContainer:
          isDark ? AppDarkColors.textPrimary : const Color(0xFF0D6F5D),
      tertiary: isDark ? AppDarkColors.premium : AppColors.success,
      onTertiary: isDark ? AppDarkColors.backgroundBase : Colors.white,
      tertiaryContainer:
          isDark ? const Color(0xFF3A2911) : const Color(0xFFFFF4DE),
      onTertiaryContainer:
          isDark ? const Color(0xFFFFE6BC) : const Color(0xFF8C5C05),
      error: isDark ? AppDarkColors.error : AppColors.danger,
      onError: isDark ? AppDarkColors.backgroundBase : Colors.white,
      errorContainer:
          isDark ? const Color(0xFF3C1520) : const Color(0xFFFFECEC),
      onErrorContainer:
          isDark ? const Color(0xFFFFD5DD) : const Color(0xFF9D1C1C),
      surface: isDark ? AppDarkColors.surface1 : AppColors.surface,
      onSurface: isDark ? AppDarkColors.textPrimary : AppColors.ink,
      onSurfaceVariant:
          isDark ? AppDarkColors.textSecondary : AppColors.muted,
      outline: isDark ? AppDarkColors.borderSubtle : AppColors.border,
      outlineVariant:
          isDark ? const Color(0xFF1F344A) : const Color(0xFFD7E0EC),
      shadow: isDark ? const Color(0xFF02080F) : const Color(0x1A121826),
      scrim: isDark ? AppDarkColors.overlay : Colors.black54,
      surfaceTint: isDark ? AppDarkColors.primary : AppColors.primary,
    );

    final bodyText = GoogleFonts.soraTextTheme(base.textTheme);
    final textTheme = bodyText.copyWith(
      headlineLarge: GoogleFonts.spaceGrotesk(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        height: 1.1,
        color: scheme.onSurface,
      ),
      headlineMedium: GoogleFonts.spaceGrotesk(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        height: 1.15,
        color: scheme.onSurface,
      ),
      headlineSmall: GoogleFonts.spaceGrotesk(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        height: 1.2,
        color: scheme.onSurface,
      ),
      titleLarge: GoogleFonts.spaceGrotesk(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: scheme.onSurface,
      ),
      titleMedium: GoogleFonts.spaceGrotesk(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: scheme.onSurface,
      ),
      titleSmall: bodyText.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      bodyLarge: bodyText.bodyLarge?.copyWith(
        fontSize: 16,
        height: 1.5,
        color: scheme.onSurface,
      ),
      bodyMedium: bodyText.bodyMedium?.copyWith(
        fontSize: 14,
        height: 1.5,
        color: scheme.onSurface,
      ),
      bodySmall: bodyText.bodySmall?.copyWith(
        fontSize: 12,
        height: 1.45,
        color: isDark ? AppDarkColors.textSecondary : AppColors.muted,
      ),
      labelLarge: bodyText.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      labelMedium: bodyText.labelMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: isDark ? AppDarkColors.textSecondary : AppColors.muted,
      ),
      labelSmall: bodyText.labelSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: isDark ? AppDarkColors.textSecondary : AppColors.muted,
      ),
    );

    final inputFill =
        isDark ? AppDarkColors.surface2 : const Color(0xFFF7F9FD);
    final disabledForeground = isDark
        ? AppDarkColors.textTertiary.withValues(alpha: 0.88)
        : AppColors.muted.withValues(alpha: 0.82);
    final buttonForegroundOnDark = isDark ? AppDarkColors.backgroundBase : null;

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor:
          isDark ? AppDarkColors.backgroundBase : AppColors.background,
      canvasColor: isDark ? AppDarkColors.backgroundSecondary : AppColors.surface,
      shadowColor: isDark ? const Color(0xFF02080F) : const Color(0x1A121826),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(
          color: isDark ? AppDarkColors.textPrimary : scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shadowColor: isDark
            ? const Color(0xFF02080F).withValues(alpha: 0.5)
            : Colors.black.withValues(alpha: 0.06),
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: BorderSide(
            color: scheme.outline.withValues(alpha: isDark ? 0.92 : 0.72),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outline.withValues(alpha: isDark ? 0.5 : 0.8),
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: textTheme.bodySmall?.color,
        ),
        labelStyle: textTheme.labelMedium,
        helperStyle: textTheme.bodySmall,
        errorStyle: textTheme.bodySmall?.copyWith(
          color: scheme.error,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 54)),
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return scheme.surface;
            }
            if (states.contains(WidgetState.pressed) && isDark) {
              return AppDarkColors.primaryPressed;
            }
            return scheme.primary;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return disabledForeground;
            }
            return buttonForegroundOnDark ?? scheme.onPrimary;
          }),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return scheme.onPrimary.withValues(alpha: isDark ? 0.08 : 0.06);
            }
            return null;
          }),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
          side: WidgetStateProperty.resolveWith((states) {
            if (!isDark || states.contains(WidgetState.disabled)) {
              return BorderSide.none;
            }
            return BorderSide(
              color: AppDarkColors.primarySoft.withValues(alpha: 0.24),
            );
          }),
          shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 52)),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return disabledForeground;
            }
            return scheme.onSurface;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return BorderSide(color: scheme.outline.withValues(alpha: 0.42));
            }
            return BorderSide(
              color: isDark
                  ? AppDarkColors.primary.withValues(alpha: 0.24)
                  : scheme.outline,
            );
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (!isDark || states.contains(WidgetState.disabled)) {
              return null;
            }
            if (states.contains(WidgetState.pressed)) {
              return AppDarkColors.primary.withValues(alpha: 0.12);
            }
            return AppDarkColors.surface1.withValues(alpha: 0.85);
          }),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return disabledForeground;
            }
            return scheme.primary;
          }),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return scheme.primary.withValues(alpha: 0.08);
            }
            return null;
          }),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppDarkColors.surface2 : const Color(0xFF1E2A45),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        showCheckmark: false,
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        labelStyle: textTheme.labelSmall,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.primary,
        textColor: scheme.onSurface,
        tileColor: isDark ? AppDarkColors.surface1 : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        backgroundColor: scheme.primary,
        foregroundColor: buttonForegroundOnDark ?? scheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return scheme.primary;
            }
            return isDark ? AppDarkColors.surface2 : scheme.surface;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return buttonForegroundOnDark ?? scheme.onPrimary;
            }
            return textTheme.labelLarge?.color;
          }),
          side: WidgetStateProperty.all(
            BorderSide(
              color: isDark
                  ? AppDarkColors.primary.withValues(alpha: 0.22)
                  : scheme.outline,
            ),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          textStyle: WidgetStateProperty.all(textTheme.labelMedium),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: scheme.outline.withValues(alpha: isDark ? 0.7 : 0.85),
        indicatorColor: scheme.primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: scheme.primary,
        unselectedLabelColor: textTheme.bodySmall?.color,
        splashFactory: NoSplash.splashFactory,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: isDark
            ? AppDarkColors.primary.withValues(alpha: 0.14)
            : AppColors.primary.withValues(alpha: 0.12),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.all(textTheme.labelSmall),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary;
          }
          return Colors.transparent;
        }),
        side: BorderSide(color: scheme.outline),
        checkColor: WidgetStatePropertyAll(buttonForegroundOnDark ?? Colors.white),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary;
          }
          return scheme.onSurfaceVariant;
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return buttonForegroundOnDark ?? Colors.white;
          }
          return isDark ? AppDarkColors.textSecondary : Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary.withValues(alpha: 0.72);
          }
          return isDark ? AppDarkColors.surface3 : const Color(0xFFD4DBE6);
        }),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withValues(alpha: 0.28),
        selectionHandleColor: scheme.primary,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(
            color: scheme.outline.withValues(alpha: isDark ? 0.8 : 0.6),
          ),
        ),
        textStyle: textTheme.bodyMedium,
      ),
    );
  }
}
