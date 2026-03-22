import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_ui.dart';
import '../widgets/loading_view.dart';

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

      if (!mounted) {
        return;
      }

      setState(() {
        _items = List<dynamic>.from(envelope['data'] as List? ?? const []);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Não foi possível carregar os logs de erro.';
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
                      AppStatusPill(label: _severityLabel(map['severity'])),
                      AppStatusPill(label: _platformLabel(map['platform'])),
                      AppStatusPill(
                        label: map['resolved_at'] == null
                            ? 'Pendente'
                            : 'Resolvido',
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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível carregar os detalhes do log.'),
        ),
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

  String _severityLabel(dynamic value) {
    return value?.toString() == 'warning' ? 'Alerta' : 'Erro';
  }

  String _platformLabel(dynamic value) {
    switch (value?.toString()) {
      case 'web':
        return 'Web';
      case 'mobile':
        return 'Mobile';
      case 'backend':
        return 'Backend';
      default:
        return 'Sistema';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthService.instance.isAdmin) {
      return const AppScaffold(
        title: 'Logs de erro',
        body: Center(
          child: Text('Somente administradores podem acessar os logs de erro.'),
        ),
      );
    }

    final openItems = _items
        .where((item) => (item as Map)['resolved_at'] == null)
        .length;

    return AppScaffold(
      title: 'Logs de erro',
      subtitle: 'Falhas técnicas, investigação e resolução',
      actions: [
        IconButton(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppHeroBanner(
            title: 'Logs administrativos',
            subtitle: 'Falhas registradas pelo backend, web e mobile com contexto.',
            metrics: [
              AppHeroMetric(label: 'Abertos', value: '$openItems'),
              AppHeroMetric(label: 'Total', value: '${_items.length}'),
            ],
          ),
          const SizedBox(height: AppTokens.space4),
          AppSearchField(
            controller: _searchController,
            hintText: 'Buscar por mensagem, usuário ou endpoint',
            onSubmitted: (_) => _load(),
            trailing: IconButton(
              onPressed: _load,
              icon: const Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: AppTokens.space3),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in const <MapEntry<String, String>>[
                MapEntry('', 'Todas as severidades'),
                MapEntry('error', 'Erro'),
                MapEntry('warning', 'Alerta'),
              ])
                ChoiceChip(
                  label: Text(entry.value),
                  selected: _severity == entry.key,
                  onSelected: (_) => setState(() => _severity = entry.key),
                ),
            ],
          ),
          const SizedBox(height: AppTokens.space3),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in const <MapEntry<String, String>>[
                MapEntry('false', 'Pendentes'),
                MapEntry('true', 'Resolvidos'),
                MapEntry('', 'Todos'),
              ])
                ChoiceChip(
                  label: Text(entry.value),
                  selected: _resolved == entry.key,
                  onSelected: (_) => setState(() => _resolved = entry.key),
                ),
              for (final entry in const <MapEntry<String, String>>[
                MapEntry('', 'Plataforma'),
                MapEntry('web', 'Web'),
                MapEntry('mobile', 'Mobile'),
                MapEntry('backend', 'Backend'),
              ])
                ChoiceChip(
                  label: Text(entry.value),
                  selected: _platform == entry.key,
                  onSelected: (_) => setState(() => _platform = entry.key),
                ),
            ],
          ),
          const SizedBox(height: AppTokens.space4),
          Expanded(
            child: _loading
                ? const LoadingView(message: 'Carregando logs...')
                : _error != null
                    ? AppMessageBanner(
                        message: _error!,
                        icon: Icons.error_outline_rounded,
                        toneColor: Theme.of(context).colorScheme.error,
                      )
                    : _items.isEmpty
                        ? const EmptyStateCard(
                            title: 'Nenhum log encontrado',
                            subtitle:
                                'Ajuste os filtros para localizar falhas de outro período ou plataforma.',
                          )
                        : ListView.builder(
                            itemCount: _items.length,
                            itemBuilder: (context, index) {
                              final item =
                                  Map<String, dynamic>.from(_items[index] as Map);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: AppSurface(
                                  onTap: () => _openDetail(item),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        child: Icon(
                                          Icons.error_outline_rounded,
                                          color: Theme.of(context).colorScheme.error,
                                        ),
                                      ),
                                      const SizedBox(width: AppTokens.space3),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item['friendly_message']
                                                      ?.toString() ??
                                                  'Falha sem descrição amigável.',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleSmall,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${_formatDate(item['created_at'])} • ${item['module'] ?? 'sistema'} • ${_platformLabel(item['platform'])}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                      AppStatusPill(
                                        label: item['resolved_at'] == null
                                            ? 'aberto'
                                            : 'resolvido',
                                        color: item['resolved_at'] == null
                                            ? Theme.of(context).colorScheme.error
                                            : AppTokens.supportTeal,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
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
