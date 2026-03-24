import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'status_chip.dart';

class BudgetCard extends StatelessWidget {
  const BudgetCard({
    super.key,
    required this.code,
    required this.clientName,
    required this.description,
    required this.dateLabel,
    required this.amountLabel,
    required this.statusLabel,
    this.onTap,
    this.onMore,
  });

  final String code;
  final String clientName;
  final String description;
  final String dateLabel;
  final String amountLabel;
  final String statusLabel;
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(code, style: theme.textTheme.titleMedium),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  StatusChip(label: statusLabel, compact: true),
                  if (onMore != null)
                    IconButton(
                      onPressed: onMore,
                      icon: const Icon(Icons.more_horiz),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(clientName, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text(
                description,
                style: theme.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      dateLabel,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    amountLabel,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.ink,
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
