import 'package:flutter/material.dart';

import '../core/navigation/route_tracker.dart';
import '../theme/app_tokens.dart';
import 'brand_logo.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.showAppBar = true,
    this.showLogo = false,
    this.logoHeight = 24,
    this.padding,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool showAppBar;
  final bool showLogo;
  final double logoHeight;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    RouteTracker.instance.update(title);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final appBarBackground = isDark
        ? AppDarkColors.backgroundSecondary.withValues(alpha: 0.92)
        : theme.colorScheme.surface.withValues(alpha: 0.98);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: showAppBar
          ? AppBar(
              backgroundColor: appBarBackground,
              titleSpacing: AppSpacing.md,
              title: Row(
                children: [
                  if (showLogo) ...[
                    BrandLogo(height: logoHeight),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: actions,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(
                  height: 1,
                  color: theme.colorScheme.outline.withValues(
                    alpha: isDark ? 0.4 : 0.5,
                  ),
                ),
              ),
            )
          : null,
      floatingActionButton: floatingActionButton,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: isDark
                    ? AppGradients.darkScaffold
                    : const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.background,
                          Color(0xFFF8FAFE),
                        ],
                      ),
              ),
            ),
          ),
          if (isDark) ...[
            const Positioned(
              top: -120,
              right: -90,
              child: _ScaffoldGlow(
                size: 260,
                color: AppDarkColors.glowPrimary,
                opacity: 0.55,
              ),
            ),
            const Positioned(
              top: 120,
              left: -100,
              child: _ScaffoldGlow(
                size: 220,
                color: Color(0x1AF4A640),
                opacity: 0.34,
              ),
            ),
          ],
          SafeArea(
            top: !showAppBar,
            bottom: false,
            child: Padding(
              padding: padding ?? const EdgeInsets.all(AppSpacing.md),
              child: body,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScaffoldGlow extends StatelessWidget {
  const _ScaffoldGlow({
    required this.size,
    required this.color,
    required this.opacity,
  });

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
