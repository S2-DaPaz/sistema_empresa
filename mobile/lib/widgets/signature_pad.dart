import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:signature/signature.dart';

class SignaturePadField extends StatefulWidget {
  const SignaturePadField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<SignaturePadField> createState() => _SignaturePadFieldState();
}

class _SignaturePadFieldState extends State<SignaturePadField> {
  Uint8List? _decode(String dataUrl) {
    if (dataUrl.isEmpty) return null;
    final parts = dataUrl.split(',');
    if (parts.length != 2) return null;
    try {
      return base64Decode(parts.last);
    } catch (_) {
      return null;
    }
  }

  String _onlyDigits(String value) => value.replaceAll(RegExp(r'\D'), '');

  String _formatCpfDigits(String digits) {
    final trimmed = digits.length > 11 ? digits.substring(0, 11) : digits;
    final buffer = StringBuffer();
    for (var i = 0; i < trimmed.length; i++) {
      if (i == 3 || i == 6) buffer.write('.');
      if (i == 9) buffer.write('-');
      buffer.write(trimmed[i]);
    }
    return buffer.toString();
  }

  Future<_SignerInfo?> _promptSignerInfo() async {
    return Navigator.of(context).push<_SignerInfo>(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 180),
        reverseTransitionDuration: const Duration(milliseconds: 120),
        pageBuilder: (_, __, ___) => const SignatureInfoScreen(),
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  Future<void> _openSignature() async {
    final signer = await _promptSignerInfo();
    if (signer == null) return;
    if (!mounted) return;

    final dataUrl = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => SignatureCaptureScreen(
          signerName: signer.name,
          signerCpf: signer.cpf,
        ),
      ),
    );

    if (dataUrl != null && dataUrl.isNotEmpty) {
      widget.onChanged(dataUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _decode(widget.value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label.toUpperCase(), style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        InkWell(
          onTap: _openSignature,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            height: 140,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black.withValues(alpha: 0.12)),
            ),
            child: preview == null
                ? Center(
                    child: Text(
                      'toque para assinar',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.black54,
                          ),
                    ),
                  )
                : Column(
                    children: [
                      Expanded(child: Image.memory(preview, fit: BoxFit.contain)),
                      const SizedBox(height: 8),
                      Text(
                        'toque para assinar',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.black54,
                            ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class SignatureCaptureScreen extends StatefulWidget {
  const SignatureCaptureScreen({
    super.key,
    required this.signerName,
    required this.signerCpf,
  });

  final String signerName;
  final String signerCpf;

  @override
  State<SignatureCaptureScreen> createState() => _SignatureCaptureScreenState();
}

class _SignatureCaptureScreenState extends State<SignatureCaptureScreen> {
  late final SignatureController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SignatureController(
      penStrokeWidth: 2,
      penColor: const Color(0xFF0C1B2A),
      exportBackgroundColor: Colors.white,
    );
    SystemChrome.setPreferredOrientations(
      [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  Future<void> _saveSignature() async {
    final bytes = await _controller.toPngBytes();
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assinatura vazia.')),
      );
      return;
    }
    final dataUrl = 'data:image/png;base64,${base64Encode(bytes)}';
    if (!mounted) return;
    Navigator.pop(context, dataUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                  TextButton(
                    onPressed: _controller.clear,
                    child: const Text('Limpar'),
                  ),
                ],
              ),
            ),
            if (widget.signerName.isNotEmpty || widget.signerCpf.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.signerName,
                        style: Theme.of(context).textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.signerCpf.isNotEmpty)
                      Text(
                        widget.signerCpf,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.12)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Assinatura', style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Signature(
                          controller: _controller,
                          backgroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(height: 1, color: Colors.black26),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: SizedBox(
                width: 180,
                child: ElevatedButton(
                  onPressed: _saveSignature,
                  child: const Text('Salvar'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SignatureInfoScreen extends StatefulWidget {
  const SignatureInfoScreen({super.key});

  @override
  State<SignatureInfoScreen> createState() => _SignatureInfoScreenState();
}

class _SignatureInfoScreenState extends State<SignatureInfoScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _cpfController = TextEditingController();
  String? _nameError;
  String? _cpfError;

  @override
  void dispose() {
    _nameController.dispose();
    _cpfController.dispose();
    super.dispose();
  }

  String _onlyDigits(String value) => value.replaceAll(RegExp(r'\D'), '');

  String _formatCpfDigits(String digits) {
    final trimmed = digits.length > 11 ? digits.substring(0, 11) : digits;
    final buffer = StringBuffer();
    for (var i = 0; i < trimmed.length; i++) {
      if (i == 3 || i == 6) buffer.write('.');
      if (i == 9) buffer.write('-');
      buffer.write(trimmed[i]);
    }
    return buffer.toString();
  }

  Future<void> _close([_SignerInfo? payload]) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    Navigator.pop(context, payload);
  }

  void _submit() {
    final name = _nameController.text.trim();
    final cpfDigits = _onlyDigits(_cpfController.text);
    setState(() {
      _nameError = name.isEmpty ? 'Informe o nome.' : null;
      if (cpfDigits.isNotEmpty && cpfDigits.length != 11) {
        _cpfError = 'Informe um CPF válido.';
      } else {
        _cpfError = null;
      }
    });
    if (_nameError != null || _cpfError != null) return;
    final cpf = _formatCpfDigits(cpfDigits);
    _close(_SignerInfo(name: name, cpf: cpf));
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Assinatura', style: Theme.of(context).textTheme.titleMedium),
                      IconButton(
                        onPressed: () => _close(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  Text('Quem está assinando?', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.name,
                    decoration: InputDecoration(labelText: 'Nome', errorText: _nameError),
                    onChanged: (_) {
                      if (_nameError != null) {
                        setState(() => _nameError = null);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _cpfController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      CpfInputFormatter(),
                    ],
                    decoration: InputDecoration(labelText: 'CPF (opcional)', errorText: _cpfError),
                    onChanged: (_) {
                      if (_cpfError != null) {
                        setState(() => _cpfError = null);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submit,
                      child: const Text('Continuar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SignerInfo {
  const _SignerInfo({required this.name, required this.cpf});

  final String name;
  final String cpf;
}

class CpfInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length && i < 11; i++) {
      if (i == 3 || i == 6) buffer.write('.');
      if (i == 9) buffer.write('-');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
