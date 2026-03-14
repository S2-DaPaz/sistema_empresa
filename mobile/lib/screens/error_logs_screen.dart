import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/section_header.dart';

class ErrorLogsScreen extends StatefulWidget {
  const ErrorLogsScreen({super.key});

  @override
  State<ErrorLogsScreen> createState() => _ErrorLogsScreenState();
}

class _ErrorLogsScreenState extends State<ErrorLogsScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _items = [];
  bool _loading = true;
  String? _error;
  String _severity = '';
  String _platform = '';
  String _resolved = 'false';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final query = <String, String>{
        'page': '1',
        'pageSize': '50',
        'resolved': _resolved,
      };

      if (_searchController.text.trim().isNotEmpty) {
        query['search'] = _searchController.text.trim();
      }
      if (_severity.isNotEmpty) query['severity'] = _severity;
      if (_platform.isNotEmpty) query['platform'] = _platform;

      final envelope = await _api.getEnvelope(
        '/admin/error-logs?${Uri(queryParameters: query).query}',
      );

      if (!mounted) return;
      setState(() {
        _items = List<dynamic>.from(envelope['data'] as List? ?? const []);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openDetail(Map<String, dynamic> item) async {
    try {
      final detail = await _api.get('/admin/error-logs/${item['id']}');
      if (!mounted) return;

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) {
          final map = Map<String, dynamic>.from(detail as Map);
          final textTheme = Theme.of(context).textTheme;
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Log #${map['id']}', style: textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    map['friendly_message']?.toString() ??
                        'Sem mensagem amigável.',
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text(map['severity']?.toString() ?? 'erro')),
                      Chip(
                        label: Text(map['platform']?.toString() ?? 'mobile'),
                      ),
                      Chip(
                        label: Text(map['module']?.toString() ?? 'sistema'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _DetailBlock(
                    title: 'Mensagem técnica',
                    value:
                        map['technical_message']?.toString() ?? 'Sem detalhes.',
                  ),
                  _DetailBlock(
                    title: 'Stack trace',
                    value:
                        map['stack_trace']?.toString() ?? 'Sem stack trace.',
                  ),
                  _DetailBlock(
                    title: 'Contexto',
                    value: _prettyJson(map['context_json']),
                  ),
                  _DetailBlock(
                    title: 'Payload seguro',
                    value: _prettyJson(map['payload_json']),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: _buildSnapshot(map)),
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Detalhes copiados para a área de transferência.',
                          ),
                        ),
                      );
                    },
                    child: const Text('Copiar detalhes'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  String _formatDate(dynamic value) {
    if (value == null || value.toString().isEmpty) return '-';
    final date = DateTime.tryParse(value.toString());
    if (date == null) return value.toString();
    return DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal());
  }

  String _buildSnapshot(Map<String, dynamic> map) {
    return [
      'ID: ${map['id']}',
      'Data: ${map['created_at']}',
      'Severidade: ${map['severity']}',
      'Módulo: ${map['module']}',
      'Endpoint: ${map['http_method'] ?? '-'} ${map['endpoint'] ?? '-'}',
      '',
      'Mensagem técnica:',
      map['technical_message']?.toString() ?? '-',
      '',
      'Stack trace:',
      map['stack_trace']?.toString() ?? '-',
      '',
      'Contexto:',
      _prettyJson(map['context_json']),
      '',
      'Payload:',
      _prettyJson(map['payload_json']),
    ].join('\n');
  }

  String _prettyJson(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return 'Sem dados.';
    }
    if (value is Map || value is List) {
      return const JsonEncoder.withIndent('  ').convert(value);
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Logs de erro',
      actions: [
        IconButton(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!AuthService.instance.isAdmin)
            const Expanded(
              child: Center(
                child: Text(
                  'Somente administradores podem acessar os logs de erro.',
                ),
              ),
            )
          else ...[
            const SectionHeader(
              title: 'Falhas técnicas',
              subtitle: 'Erros do backend e falhas reportadas por web ou mobile.',
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      onSubmitted: (_) => _load(),
                      decoration: InputDecoration(
                        labelText: 'Buscar por mensagem, usuário ou endpoint',
                        suffixIcon: IconButton(
                          onPressed: _load,
                          icon: const Icon(Icons.search),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _severity.isEmpty ? null : _severity,
                            decoration:
                                const InputDecoration(labelText: 'Severidade'),
                            items: const [
                              DropdownMenuItem(
                                value: 'error',
                                child: Text('Erro'),
                              ),
                              DropdownMenuItem(
                                value: 'warning',
                                child: Text('Alerta'),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => _severity = value ?? ''),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _platform.isEmpty ? null : _platform,
                            decoration:
                                const InputDecoration(labelText: 'Plataforma'),
                            items: const [
                              DropdownMenuItem(
                                value: 'web',
                                child: Text('Web'),
                              ),
                              DropdownMenuItem(
                                value: 'mobile',
                                child: Text('Mobile'),
                              ),
                              DropdownMenuItem(
                                value: 'backend',
                                child: Text('Backend'),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => _platform = value ?? ''),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'false',
                          label: Text('Pendentes'),
                        ),
                        ButtonSegment(
                          value: 'true',
                          label: Text('Resolvidos'),
                        ),
                        ButtonSegment(
                          value: '',
                          label: Text('Todos'),
                        ),
                      ],
                      selected: {_resolved},
                      onSelectionChanged: (selection) {
                        setState(() => _resolved = selection.first);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : _items.isEmpty
                          ? const Center(
                              child: Text(
                                'Nenhum log encontrado com os filtros atuais.',
                              ),
                            )
                          : ListView.builder(
                              itemCount: _items.length,
                              itemBuilder: (context, index) {
                                final item =
                                    Map<String, dynamic>.from(_items[index] as Map);
                                return Card(
                                  child: ListTile(
                                    onTap: () => _openDetail(item),
                                    title: Text(
                                      item['friendly_message']?.toString() ??
                                          'Falha sem descrição amigável.',
                                    ),
                                    subtitle: Text(
                                      '${_formatDate(item['created_at'])} • ${item['module'] ?? 'sistema'} • ${item['platform'] ?? 'plataforma'}',
                                    ),
                                    trailing: Chip(
                                      label: Text(
                                        item['resolved_at'] == null
                                            ? 'Pendente'
                                            : 'Resolvido',
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          SelectableText(value),
        ],
      ),
    );
  }
}
