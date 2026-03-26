import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.error_outline_rounded,
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Não foi possível carregar este conteúdo.',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                message,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: AppSpacing.md),
                ElevatedButton(
                  onPressed: onRetry,
                  child: const Text('Tentar novamente'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
