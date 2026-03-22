import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'app_ui.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({
    super.key,
    this.message = 'Carregando dados da tela...',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: AppSurface(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: AppTokens.space4),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
