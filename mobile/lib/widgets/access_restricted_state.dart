import 'package:flutter/material.dart';

import 'empty_state.dart';

class AccessRestrictedState extends StatelessWidget {
  const AccessRestrictedState({
    super.key,
    this.title = 'Visualização bloqueada',
    this.message =
        'Seu perfil pode navegar por esta área, mas não pode acessar dados cadastrados nem executar ações de gerenciamento.',
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      title: title,
      message: message,
      icon: Icons.visibility_off_outlined,
    );
  }
}
