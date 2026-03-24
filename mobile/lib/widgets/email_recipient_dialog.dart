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
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialEmail.trim());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = (value ?? '').trim().toLowerCase();
    if (_emailPattern.hasMatch(email)) return null;
    return 'Informe um endereco de e-mail valido.';
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    if (_formKey.currentState?.validate() != true) return;
    final email = _controller.text.trim().toLowerCase();
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
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(widget.message, style: textTheme.bodyMedium),
              const SizedBox(height: 16),
              TextFormField(
                controller: _controller,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.send,
                autovalidateMode: _submitted
                    ? AutovalidateMode.onUserInteraction
                    : AutovalidateMode.disabled,
                validator: _validateEmail,
                onFieldSubmitted: (_) => _submit(),
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
                      onPressed: _submit,
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
