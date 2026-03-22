import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTokens.space4),
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.radius = AppTokens.radiusMd,
    this.shadow = AppTokens.softShadowSm,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final double radius;
  final List<BoxShadow> shadow;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? scheme.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? scheme.outlineVariant),
        boxShadow: shadow,
      ),
      child: child,
    );

    final wrapped = onTap == null
        ? content
        : Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(radius),
              onTap: onTap,
              child: content,
            ),
          );

    if (margin == null) {
      return wrapped;
    }

    return Padding(padding: margin!, child: wrapped);
  }
}

class AppHeroMetric {
  const AppHeroMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

class AppHeroBanner extends StatelessWidget {
  const AppHeroBanner({
    super.key,
    required this.title,
    required this.subtitle,
    this.metrics = const [],
    this.trailing,
  });

  final String title;
  final String subtitle;
  final List<AppHeroMetric> metrics;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        gradient: AppTokens.heroGradient,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        boxShadow: AppTokens.softShadow,
      ),
      padding: const EdgeInsets.all(AppTokens.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppTokens.space3),
                trailing!,
              ],
            ],
          ),
          if (metrics.isNotEmpty) ...[
            const SizedBox(height: AppTokens.space5),
            Row(
              children: metrics
                  .map(
                    (metric) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: AppTokens.space2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              metric.value,
                              style: textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              metric.label,
                              style: textTheme.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.72),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class AppMetricTile extends StatelessWidget {
  const AppMetricTile({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    this.emphasis = false,
    this.onTap,
  });

  final String title;
  final String value;
  final String subtitle;
  final bool emphasis;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final backgroundColor =
        emphasis ? scheme.primary : scheme.surface;
    final foregroundColor =
        emphasis ? Colors.white : scheme.onSurface;

    return AppSurface(
      onTap: onTap,
      backgroundColor: backgroundColor,
      borderColor: emphasis ? Colors.transparent : scheme.outlineVariant,
      radius: AppTokens.radiusMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.labelLarge?.copyWith(
              color: foregroundColor.withValues(alpha: emphasis ? 0.9 : 0.72),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: textTheme.headlineSmall?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: textTheme.bodySmall?.copyWith(
              color: foregroundColor.withValues(alpha: emphasis ? 0.8 : 0.62),
            ),
          ),
        ],
      ),
    );
  }
}

class AppQuickActionCard extends StatelessWidget {
  const AppQuickActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.value,
    this.color,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? value;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = color ?? scheme.primary;
    final textTheme = Theme.of(context).textTheme;

    return AppSurface(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(height: AppTokens.space4),
          Text(title, style: textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(subtitle, style: textTheme.bodySmall),
          if (value != null) ...[
            const SizedBox(height: AppTokens.space4),
            Text(
              value!,
              style: textTheme.labelLarge?.copyWith(color: accent),
            ),
          ],
        ],
      ),
    );
  }
}

class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.trailing,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: trailing,
      ),
    );
  }
}

class AppMessageBanner extends StatelessWidget {
  const AppMessageBanner({
    super.key,
    required this.message,
    required this.icon,
    this.toneColor,
  });

  final String message;
  final IconData icon;
  final Color? toneColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = toneColor ?? scheme.primary;
    return AppSurface(
      backgroundColor: color.withValues(alpha: 0.08),
      borderColor: color.withValues(alpha: 0.18),
      shadow: const [],
      radius: AppTokens.radiusSm,
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppTokens.space3),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: color.withValues(alpha: 0.95),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(subtitle, style: textTheme.bodySmall),
          if (action != null) ...[
            const SizedBox(height: AppTokens.space4),
            action!,
          ],
        ],
      ),
    );
  }
}

class AppSectionBlock extends StatelessWidget {
  const AppSectionBlock({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: textTheme.bodySmall),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class AppStatusPill extends StatelessWidget {
  const AppStatusPill({
    super.key,
    required this.label,
    this.color,
  });

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final baseColor = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        border: Border.all(color: baseColor.withValues(alpha: 0.16)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: baseColor,
            ),
      ),
    );
  }
}
