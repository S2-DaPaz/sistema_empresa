import 'package:flutter/material.dart';

final RegExp _padraoEmail = RegExp(
    r'^[^\s@]+@([^\s@]+\.[^\s@]+|local|localhost)$',
    caseSensitive: false);

Future<String?> showEmailRecipientDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String initialEmail = '',
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _EmailRecipientDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      initialEmail: initialEmail,
    ),
  );
}

class _EmailRecipientDialog extends StatefulWidget {
  const _EmailRecipientDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.initialEmail,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String initialEmail;

  @override
  State<_EmailRecipientDialog> createState() => _EmailRecipientDialogState();
}

class _EmailRecipientDialogState extends State<_EmailRecipientDialog> {
  final GlobalKey<FormState> _chaveFormulario = GlobalKey<FormState>();
  late final TextEditingController _controlador;
  bool _submetido = false;

  @override
  void initState() {
    super.initState();
    _controlador = TextEditingController(text: widget.initialEmail.trim());
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  String? _validarEmail(String? value) {
    final email = (value ?? '').trim().toLowerCase();
    if (_padraoEmail.hasMatch(email)) return null;
    return 'Informe um endereco de e-mail valido.';
  }

  Future<void> _submeter() async {
    setState(() => _submetido = true);
    if (_chaveFormulario.currentState?.validate() != true) return;
    final email = _controlador.text.trim().toLowerCase();
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 16));
    if (!mounted) return;
    Navigator.of(context).pop(email);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, bottomInset + 28),
        child: Form(
          key: _chaveFormulario,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(widget.message, style: textTheme.bodyMedium),
              const SizedBox(height: 16),
              TextFormField(
                controller: _controlador,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.send,
                autovalidateMode: _submetido
                    ? AutovalidateMode.onUserInteraction
                    : AutovalidateMode.disabled,
                validator: _validarEmail,
                onFieldSubmitted: (_) => _submeter(),
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  hintText: 'cliente@empresa.com',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submeter,
                      child: Text(widget.confirmLabel),
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
