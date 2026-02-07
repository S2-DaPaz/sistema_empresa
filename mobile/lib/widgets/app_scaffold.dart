import 'package:flutter/material.dart';

import 'brand_logo.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.showAppBar = true,
    this.showLogo = true,
    this.logoHeight = 24,
    this.padding,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final FloatingActionButton? floatingActionButton;
  final bool showAppBar;
  final bool showLogo;
  final double logoHeight;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final titleWidget = showLogo
        ? Row(
            children: [
              BrandLogo(height: logoHeight),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          )
        : Text(title);
    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              title: titleWidget,
              actions: actions,
            )
          : null,
      floatingActionButton: floatingActionButton,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              isDark ? const Color(0xFF0F1B2A) : const Color(0xFFF6FAFD),
              isDark ? const Color(0xFF0B1320) : const Color(0xFFEAF2F8),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -120,
              right: -60,
              child: _GlowCircle(
                size: 220,
                color: colors.primary.withValues(alpha: isDark ? 0.12 : 0.16),
              ),
            ),
            Positioned(
              bottom: -140,
              left: -80,
              child: _GlowCircle(
                size: 260,
                color: colors.secondary.withValues(alpha: isDark ? 0.12 : 0.16),
              ),
            ),
            Positioned(
              top: 180,
              left: -40,
              child: _GlowCircle(
                size: 160,
                color: colors.tertiary.withValues(alpha: isDark ? 0.08 : 0.12),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: padding ?? const EdgeInsets.all(16),
                child: body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}
