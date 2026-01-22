import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../widgets/app_scaffold.dart';
import '../widgets/loading_view.dart';

class PdfViewerScreen extends StatefulWidget {
  const PdfViewerScreen({
    super.key,
    required this.title,
    required this.pdfFetcher,
  });

  final String title;
  final Future<List<int>> Function() pdfFetcher;

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  Uint8List? _bytes;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await widget.pdfFetcher();
      setState(() => _bytes = Uint8List.fromList(data));
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes == null && _error == null) {
      return AppScaffold(title: widget.title, body: const LoadingView());
    }
    if (_error != null) {
      return AppScaffold(
        title: widget.title,
        body: Center(child: Text(_error!)),
      );
    }

    return AppScaffold(
      title: widget.title,
      body: PdfPreview(
        canChangePageFormat: false,
        canChangeOrientation: false,
        build: (format) async => _bytes!,
      ),
    );
  }
}
