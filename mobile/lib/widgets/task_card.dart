import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'avatar_initials.dart';
import 'status_chip.dart';

class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.title,
    required this.clientName,
    required this.location,
    required this.statusLabel,
    required this.priorityLabel,
    required this.codeLabel,
    required this.avatarName,
    this.onTap,
    this.onMore,
  });

  final String title;
  final String clientName;
  final String location;
  final String statusLabel;
  final String priorityLabel;
  final String codeLabel;
  final String avatarName;
  final VoidCallback? onTap;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        if (onMore != null)
                          IconButton(
                            onPressed: onMore,
                            icon: const Icon(Icons.more_horiz),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      clientName,
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        location,
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        StatusChip(label: priorityLabel),
                        StatusChip(label: statusLabel),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      codeLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              AvatarInitials(name: avatarName, size: 36),
            ],
          ),
        ),
      ),
    );
  }
}
