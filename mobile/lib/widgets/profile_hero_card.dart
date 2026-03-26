import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'avatar_initials.dart';

class ProfileHeroCard extends StatelessWidget {
  const ProfileHeroCard({
    super.key,
    required this.name,
    required this.subtitle,
    required this.actions,
  });

  final String name;
  final String subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: isDark
            ? AppGradients.darkHero
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark
              ? AppDarkColors.primary.withValues(alpha: 0.18)
              : Colors.transparent,
        ),
        boxShadow: isDark ? AppShadows.darkCard : const [],
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarInitials(
                name: name,
                backgroundColor: isDark
                    ? AppDarkColors.primary.withValues(alpha: 0.16)
                    : const Color(0x26FFFFFF),
                foregroundColor: Colors.white,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }
}
