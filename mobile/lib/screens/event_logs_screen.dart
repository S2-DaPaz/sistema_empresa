import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/section_header.dart';

class EventLogsScreen extends StatefulWidget {
  const EventLogsScreen({super.key});

  @override
  State<EventLogsScreen> createState() => _EventLogsScreenState();
}

class _EventLogsScreenState extends State<EventLogsScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _items = [];
  bool _loading = true;
  String? _error;
  String _outcome = '';
  String _platform = '';

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
      };

      if (_searchController.text.trim().isNotEmpty) {
        query['search'] = _searchController.text.trim();
      }
      if (_outcome.isNotEmpty) query['outcome'] = _outcome;
      if (_platform.isNotEmpty) query['platform'] = _platform;

      final envelope = await _api.getEnvelope(
        '/admin/event-logs?${Uri(queryParameters: query).query}',
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
      final detail = await _api.get('/admin/event-logs/${item['id']}');
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
                  Text(
                    map['action']?.toString() ?? 'Evento',
                    style: textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    map['description']?.toString() ?? 'Sem descrição.',
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        label: Text(map['outcome']?.toString() ?? 'resultado'),
                      ),
                      Chip(
                        label: Text(map['platform']?.toString() ?? 'plataforma'),
                      ),
                      Chip(
                        label: Text(map['module']?.toString() ?? 'sistema'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _EventDetailBlock(
                    title: 'Metadados',
                    value: _prettyJson(map['metadata_json']),
                  ),
                  _EventDetailBlock(
                    title: 'Antes',
                    value: _prettyJson(map['before_json']),
                  ),
                  _EventDetailBlock(
                    title: 'Depois',
                    value: _prettyJson(map['after_json']),
                  ),
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
      'Ação: ${map['action']}',
      'Resultado: ${map['outcome']}',
      'Usuário: ${map['user_name'] ?? map['user_email'] ?? '-'}',
      '',
      'Descrição:',
      map['description']?.toString() ?? '-',
      '',
      'Metadados:',
      _prettyJson(map['metadata_json']),
      '',
      'Antes:',
      _prettyJson(map['before_json']),
      '',
      'Depois:',
      _prettyJson(map['after_json']),
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
      title: 'Log de eventos',
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
                  'Somente administradores podem acessar o log de eventos.',
                ),
              ),
            )
          else ...[
            const SectionHeader(
              title: 'Auditoria operacional',
              subtitle: 'Rastreabilidade das ações relevantes do sistema.',
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
                        labelText: 'Buscar por ação, descrição ou usuário',
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
                            initialValue: _outcome.isEmpty ? null : _outcome,
                            decoration:
                                const InputDecoration(labelText: 'Resultado'),
                            items: const [
                              DropdownMenuItem(
                                value: 'success',
                                child: Text('Sucesso'),
                              ),
                              DropdownMenuItem(
                                value: 'failure',
                                child: Text('Falha'),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => _outcome = value ?? ''),
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
                                'Nenhum evento encontrado com os filtros atuais.',
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
                                      item['action']?.toString() ?? 'Evento',
                                    ),
                                    subtitle: Text(
                                      '${item['description'] ?? 'Sem descrição'}\n${_formatDate(item['created_at'])}',
                                    ),
                                    isThreeLine: true,
                                    trailing: Chip(
                                      label: Text(
                                        item['outcome'] == 'success'
                                            ? 'Sucesso'
                                            : 'Falha',
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

class _EventDetailBlock extends StatelessWidget {
  const _EventDetailBlock({required this.title, required this.value});

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
