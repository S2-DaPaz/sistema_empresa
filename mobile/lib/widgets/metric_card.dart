import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.icon,
    this.onTap,
    this.accentColor,
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = accentColor ?? theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: isDark ? AppGradients.darkSurface : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (icon != null)
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: isDark ? 0.18 : 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: accent.withValues(alpha: isDark ? 0.22 : 0),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(icon, color: accent, size: 22),
                      ),
                    if (icon != null) const Spacer(),
                    Icon(
                      Icons.arrow_outward_rounded,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: isDark ? 0.46 : 0.28,
                      ),
                      size: 18,
                    ),
                  ],
                ),
                const Spacer(),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: theme.textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
