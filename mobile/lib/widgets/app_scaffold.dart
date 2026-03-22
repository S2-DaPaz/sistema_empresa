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
    this.logoHeight = 20,
    this.padding,
    this.headerHeight = 184,
    this.headerOverlap = 56,
    this.headerGradient,
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
  final double headerHeight;
  final double headerOverlap;
  final Gradient? headerGradient;

  @override
  Widget build(BuildContext context) {
    RouteTracker.instance.update(title);

    final bodyPadding = padding ??
        const EdgeInsets.fromLTRB(
          AppTokens.space4,
          0,
          AppTokens.space4,
          AppTokens.space4,
        );

    return Scaffold(
      extendBody: true,
      backgroundColor: AppTokens.bgLight,
      floatingActionButton: floatingActionButton,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppTokens.softBackgroundGradient,
              ),
            ),
          ),
          if (showAppBar)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _HeaderBlock(
                title: title,
                subtitle: subtitle,
                actions: actions,
                leading: leading,
                showLogo: showLogo,
                logoHeight: logoHeight,
                height: headerHeight,
                gradient: headerGradient,
              ),
            ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                bodyPadding.left,
                showAppBar ? headerHeight - headerOverlap : bodyPadding.top,
                bodyPadding.right,
                bodyPadding.bottom,
              ),
              child: body,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderBlock extends StatelessWidget {
  const _HeaderBlock({
    required this.title,
    required this.subtitle,
    required this.actions,
    required this.leading,
    required this.showLogo,
    required this.logoHeight,
    required this.height,
    required this.gradient,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showLogo;
  final double logoHeight;
  final double height;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canPop = Navigator.of(context).canPop();

    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: gradient ?? AppTokens.heroGradient,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppTokens.radiusXl),
        ),
        boxShadow: AppTokens.softShadow,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.space4,
            AppTokens.space3,
            AppTokens.space4,
            AppTokens.space5,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  leading ??
                      (canPop
                          ? _HeaderButton(
                              icon: Icons.arrow_back_ios_new_rounded,
                              onTap: () => Navigator.of(context).maybePop(),
                            )
                          : const SizedBox(width: 44, height: 44)),
                  const Spacer(),
                  if (actions != null)
                    IconTheme(
                      data: const IconThemeData(color: Colors.white),
                      child: DefaultTextStyle(
                        style: theme.textTheme.labelLarge!.copyWith(
                          color: Colors.white,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: actions!,
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showLogo) ...[
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                      ),
                      alignment: Alignment.center,
                      child: BrandLogo(height: logoHeight),
                    ),
                    const SizedBox(width: AppTokens.space3),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (subtitle != null &&
                            subtitle!.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            subtitle!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.82),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppTokens.radiusPill),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
            ),
          ),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}
