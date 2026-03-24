import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'avatar_initials.dart';
import 'status_chip.dart';

class ClientCard extends StatelessWidget {
  const ClientCard({
    super.key,
    required this.name,
    required this.email,
    required this.phone,
    required this.metrics,
    this.onTap,
  });

  final String name;
  final String email;
  final String phone;
  final List<String> metrics;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        leading: AvatarInitials(name: name),
        title: Text(name, style: theme.textTheme.titleMedium),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (email.isNotEmpty) Text(email, style: theme.textTheme.bodySmall),
            if (phone.isNotEmpty) Text(phone, style: theme.textTheme.bodySmall),
            if (metrics.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: metrics
                    .map((metric) => StatusChip(
                          label: metric,
                          tone: StatusChipTone.neutral,
                          compact: true,
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
