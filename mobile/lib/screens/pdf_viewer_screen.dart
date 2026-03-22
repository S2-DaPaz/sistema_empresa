import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../widgets/app_scaffold.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';

class PdfViewerScreen extends StatefulWidget {
  const PdfViewerScreen({
    super.key,
    required this.title,
    this.pdfFetcher,
    this.initialBytes,
  }) : assert(
          pdfFetcher != null || initialBytes != null,
          'Informe pdfFetcher ou initialBytes',
        );

  final String title;
  final Future<List<int>> Function()? pdfFetcher;
  final Uint8List? initialBytes;

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  Uint8List? _bytes;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialBytes != null) {
      _bytes = widget.initialBytes;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    final fetcher = widget.pdfFetcher;
    if (fetcher == null) {
      return;
    }
    try {
      final data = await fetcher();
      if (!mounted) {
        return;
      }
      setState(() => _bytes = Uint8List.fromList(data));
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _error = 'Não foi possível carregar o PDF.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes == null && _error == null) {
      return AppScaffold(
        title: widget.title,
        subtitle: 'Visualização de documento',
        body: const LoadingView(message: 'Preparando o PDF...'),
      );
    }
    if (_error != null) {
      return AppScaffold(
        title: widget.title,
        subtitle: 'Visualização de documento',
        body: ErrorView(message: _error!, onRetry: _load),
      );
    }

    return AppScaffold(
      title: widget.title,
      subtitle: 'Documento técnico',
      body: PdfPreview(
        canChangePageFormat: false,
        canChangeOrientation: false,
        build: (format) async => _bytes!,
      ),
    );
  }
}
