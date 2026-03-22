import 'dart:typed_data';

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
    this.radius = AppTokens.radiusLg,
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
    this.gradient,
  });

  final String title;
  final String subtitle;
  final List<AppHeroMetric> metrics;
  final Widget? trailing;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        gradient: gradient ?? AppTokens.heroGradient,
        borderRadius: BorderRadius.circular(AppTokens.radiusXl),
        boxShadow: AppTokens.softShadow,
      ),
      padding: const EdgeInsets.all(AppTokens.space5),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -10,
            child: Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
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
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
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
                            padding: const EdgeInsets.only(
                              right: AppTokens.space2,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(AppTokens.space3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(
                                  AppTokens.radiusMd,
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.12),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    metric.value,
                                    style: textTheme.titleLarge?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    metric.label,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.72,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
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
    this.icon,
    this.color,
    this.footer,
  });

  final String title;
  final String value;
  final String subtitle;
  final bool emphasis;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? color;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final accent = color ?? (emphasis ? Colors.white : AppTokens.primaryBlue);
    final backgroundColor = emphasis ? scheme.primary : scheme.surface;
    final foregroundColor = emphasis ? Colors.white : scheme.onSurface;

    return AppSurface(
      onTap: onTap,
      backgroundColor: backgroundColor,
      borderColor: emphasis ? Colors.transparent : scheme.outlineVariant,
      radius: AppTokens.radiusLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: textTheme.labelLarge?.copyWith(
                    color:
                        foregroundColor.withValues(alpha: emphasis ? 0.9 : 0.7),
                  ),
                ),
              ),
              if (icon != null)
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: emphasis
                        ? Colors.white.withValues(alpha: 0.14)
                        : accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                  ),
                  child: Icon(
                    icon,
                    color: accent,
                    size: 20,
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.headlineSmall?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: foregroundColor.withValues(alpha: emphasis ? 0.8 : 0.62),
            ),
          ),
          if (footer != null) ...[
            const SizedBox(height: AppTokens.space3),
            Text(
              footer!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelMedium?.copyWith(
                color: accent,
              ),
            ),
          ],
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
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
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
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: AppTokens.softShadowSm,
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: trailing,
          fillColor: Colors.transparent,
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            borderSide: BorderSide.none,
          ),
        ),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
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
    this.icon = Icons.inbox_rounded,
  });

  final String title;
  final String subtitle;
  final Widget? action;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppTokens.primaryBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            ),
            child: Icon(
              icon,
              color: AppTokens.primaryBlue,
            ),
          ),
          const SizedBox(height: AppTokens.space4),
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
    this.icon,
  });

  final String label;
  final Color? color;
  final IconData? icon;

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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: baseColor),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: baseColor,
                ),
          ),
        ],
      ),
    );
  }
}

class AppAvatarInitials extends StatelessWidget {
  const AppAvatarInitials({
    super.key,
    required this.initials,
    this.size = 48,
    this.backgroundColor,
    this.foregroundColor,
    this.badge,
  });

  final String initials;
  final double size;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppTokens.primaryBlue.withValues(alpha: 0.12);
    final fg = foregroundColor ?? AppTokens.primaryBlue;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ),
          if (badge != null)
            Positioned(
              right: 0,
              bottom: 0,
              child: badge!,
            ),
        ],
      ),
    );
  }
}

class AppActionChip extends StatelessWidget {
  const AppActionChip({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radiusPill),
      child: Ink(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          border: Border.all(color: color.withValues(alpha: 0.16)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppInfoCallout extends StatelessWidget {
  const AppInfoCallout({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.color,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tone = color ?? AppTokens.primaryBlue;

    return AppSurface(
      backgroundColor: tone.withValues(alpha: 0.08),
      borderColor: tone.withValues(alpha: 0.16),
      shadow: const [],
      radius: AppTokens.radiusMd,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            ),
            child: Icon(icon, color: tone),
          ),
          const SizedBox(width: AppTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: tone,
                      ),
                ),
                const SizedBox(height: 4),
                Text(message, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AppIconButtonSurface extends StatelessWidget {
  const AppIconButtonSurface({
    super.key,
    required this.icon,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tone = color ?? Theme.of(context).colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        onTap: onTap,
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTokens.radiusPill),
            border:
                Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            boxShadow: AppTokens.softShadowSm,
          ),
          child: Icon(icon, color: tone, size: 20),
        ),
      ),
    );
  }
}

class AppPhotoThumbGallery extends StatelessWidget {
  const AppPhotoThumbGallery({
    super.key,
    required this.photos,
    this.onTap,
  });

  final List<Uint8List> photos;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return const EmptyStateCard(
        title: 'Sem fotos registradas',
        subtitle: 'As evidências desta tarefa aparecerão aqui.',
        icon: Icons.photo_library_outlined,
      );
    }

    final visible = photos.take(4).toList();
    final remaining = photos.length - visible.length;

    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: visible.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final isLastVisible = index == visible.length - 1 && remaining > 0;

          return GestureDetector(
            onTap: onTap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
              child: Stack(
                children: [
                  Image.memory(
                    visible[index],
                    width: 84,
                    height: 84,
                    fit: BoxFit.cover,
                  ),
                  if (isLastVisible)
                    Positioned.fill(
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: 0.45),
                        child: Center(
                          child: Text(
                            '+$remaining',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class AppChecklistProgressBlock extends StatelessWidget {
  const AppChecklistProgressBlock({
    super.key,
    required this.title,
    required this.completed,
    required this.total,
    required this.children,
  });

  final String title;
  final int completed;
  final int total;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : completed / total;

    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              AppStatusPill(
                label: '$completed/$total',
                color: AppTokens.supportTeal,
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space3),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTokens.radiusPill),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppTokens.bgSoft,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppTokens.supportTeal,
              ),
            ),
          ),
          const SizedBox(height: AppTokens.space4),
          ...children,
        ],
      ),
    );
  }
}
