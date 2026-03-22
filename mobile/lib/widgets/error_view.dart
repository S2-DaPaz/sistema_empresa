import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'app_ui.dart';

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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: AppSurface(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 34,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: AppTokens.space3),
              Text(
                'Não foi possível carregar esta tela.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                message,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: AppTokens.space4),
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
