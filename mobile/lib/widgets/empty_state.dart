import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_tokens.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.illustrationAsset,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? illustrationAsset;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (illustrationAsset != null)
              Container(
                width: 132,
                height: 96,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppDarkColors.surface2.withValues(alpha: 0.84)
                      : theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.34),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: theme.colorScheme.outline
                        .withValues(alpha: isDark ? 0.72 : 0),
                  ),
                ),
                child: SvgPicture.asset(
                  illustrationAsset!,
                  fit: BoxFit.contain,
                ),
              )
            else
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary
                      .withValues(alpha: isDark ? 0.16 : 0.1),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: theme.colorScheme.primary),
              ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
