import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

enum StatusChipTone { neutral, primary, info, success, warning, danger }

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.tone,
    this.compact = false,
  });

  final String label;
  final StatusChipTone? tone;
  final bool compact;

  static StatusChipTone inferTone(String value) {
    final normalized = value.toLowerCase();
    if (normalized.contains('conclu') ||
        normalized.contains('aprov') ||
        normalized.contains('ativo') ||
        normalized.contains('sucesso')) {
      return StatusChipTone.success;
    }
    if (normalized.contains('alerta') ||
        normalized.contains('pend') ||
        normalized.contains('andamento') ||
        normalized.contains('rascunho')) {
      return StatusChipTone.warning;
    }
    if (normalized.contains('erro') ||
        normalized.contains('recus') ||
        normalized.contains('bloque') ||
        normalized.contains('alta') ||
        normalized.contains('logout')) {
      return StatusChipTone.danger;
    }
    if (normalized.contains('aberta') ||
        normalized.contains('nova') ||
        normalized.contains('info')) {
      return StatusChipTone.info;
    }
    if (normalized.contains('media') || normalized.contains('média')) {
      return StatusChipTone.warning;
    }
    if (normalized.contains('baixa')) {
      return StatusChipTone.success;
    }
    return StatusChipTone.primary;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedTone = tone ?? inferTone(label);
    final colors = _toneColors(resolvedTone, theme.brightness == Brightness.dark);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.sm : AppSpacing.md,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: colors.$3),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: colors.$2,
        ),
      ),
    );
  }

  (Color, Color, Color) _toneColors(StatusChipTone tone, bool isDark) {
    if (isDark) {
      switch (tone) {
        case StatusChipTone.neutral:
          return (
            AppDarkColors.surface2,
            AppDarkColors.textSecondary,
            AppDarkColors.borderSubtle,
          );
        case StatusChipTone.primary:
          return (
            AppDarkColors.primary.withValues(alpha: 0.14),
            AppDarkColors.primarySoft,
            AppDarkColors.primary.withValues(alpha: 0.28),
          );
        case StatusChipTone.info:
          return (
            const Color(0xFF123049),
            AppDarkColors.primarySoft,
            AppDarkColors.primary.withValues(alpha: 0.24),
          );
        case StatusChipTone.success:
          return (
            const Color(0xFF102D26),
            AppDarkColors.success,
            AppDarkColors.success.withValues(alpha: 0.24),
          );
        case StatusChipTone.warning:
          return (
            const Color(0xFF34250F),
            AppDarkColors.warning,
            AppDarkColors.warning.withValues(alpha: 0.22),
          );
        case StatusChipTone.danger:
          return (
            const Color(0xFF341520),
            AppDarkColors.error,
            AppDarkColors.error.withValues(alpha: 0.22),
          );
      }
    }

    switch (tone) {
      case StatusChipTone.neutral:
        return (const Color(0xFFEFF3F9), AppColors.muted, Colors.transparent);
      case StatusChipTone.primary:
        return (AppColors.primarySoft, AppColors.primary, Colors.transparent);
      case StatusChipTone.info:
        return (const Color(0xFFEAF2FF), AppColors.info, Colors.transparent);
      case StatusChipTone.success:
        return (const Color(0xFFE8F8F1), AppColors.success, Colors.transparent);
      case StatusChipTone.warning:
        return (const Color(0xFFFFF4DE), AppColors.warning, Colors.transparent);
      case StatusChipTone.danger:
        return (const Color(0xFFFFECEC), AppColors.danger, Colors.transparent);
    }
  }
}
