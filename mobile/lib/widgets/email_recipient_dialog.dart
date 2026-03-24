import 'package:flutter/material.dart';

final RegExp _emailPattern = RegExp(
    r'^[^\s@]+@([^\s@]+\.[^\s@]+|local|localhost)$',
    caseSensitive: false);

Future<String?> showEmailRecipientDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String initialEmail = '',
}) async {
  final controller = TextEditingController(text: initialEmail.trim());
  String? errorText;

  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          void submit() {
            final email = controller.text.trim().toLowerCase();
            if (!_emailPattern.hasMatch(email)) {
              setState(
                  () => errorText = 'Informe um endereço de e-mail válido.');
              return;
            }
            Navigator.of(dialogContext).pop(email);
          }

          return AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => submit(),
                  decoration: InputDecoration(
                    labelText: 'E-mail',
                    hintText: 'cliente@empresa.com',
                    prefixIcon: const Icon(Icons.mail_outline_rounded),
                    errorText: errorText,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: submit,
                child: Text(confirmLabel),
              ),
            ],
          );
        },
      );
    },
  );

  controller.dispose();
  return result;
}
