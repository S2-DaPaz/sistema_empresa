import 'package:flutter/material.dart';

import '../core/navigation/route_tracker.dart';
import '../theme/app_tokens.dart';
import 'brand_logo.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions,
    this.leading,
    this.floatingActionButton,
    this.showAppBar = true,
    this.showLogo = true,
    this.logoHeight = 24,
    this.padding,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget>? actions;
  final Widget? leading;
  final FloatingActionButton? floatingActionButton;
  final bool showAppBar;
  final bool showLogo;
  final double logoHeight;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    RouteTracker.instance.update(title);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final titleWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (showLogo) ...[
              BrandLogo(height: logoHeight),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );

    return Scaffold(
      extendBody: true,
      appBar: showAppBar
          ? AppBar(
              leading: leading,
              title: titleWidget,
              actions: actions,
            )
          : null,
      floatingActionButton: floatingActionButton,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF0F1826),
                    Color(0xFF0B1320),
                  ],
                )
              : AppTokens.softBackgroundGradient,
        ),
        child: Stack(
          children: [
            Positioned(
              top: -60,
              left: 80,
              right: 80,
              height: 220,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary.withValues(alpha: 0.12),
                        theme.colorScheme.secondary.withValues(alpha: 0.06),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              bottom: 0,
              left: 88,
              width: 1,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.48),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              bottom: 0,
              right: 112,
              width: 1,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.38),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: padding ??
                    const EdgeInsets.fromLTRB(
                      AppTokens.space4,
                      AppTokens.space4,
                      AppTokens.space4,
                      AppTokens.space4,
                    ),
                child: body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
