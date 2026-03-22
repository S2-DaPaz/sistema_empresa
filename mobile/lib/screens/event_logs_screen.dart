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
      if (_outcome.isNotEmpty) {
        query['outcome'] = _outcome;
      }
      if (_platform.isNotEmpty) {
        query['platform'] = _platform;
      }

      final envelope = await _api.getEnvelope(
        '/admin/event-logs?${Uri(queryParameters: query).query}',
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
        _error = 'Não foi possível carregar o log de eventos.';
        _loading = false;
      });
    }
  }

  Future<void> _openDetail(Map<String, dynamic> item) async {
    try {
      final detail = await _api.get('/admin/event-logs/${item['id']}');
      if (!mounted) {
        return;
      }

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
                  Text(_friendlyActionTitle(map), style: textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(_friendlyDescription(map), style: textTheme.bodyMedium),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      AppStatusPill(label: _outcomeLabel(map['outcome'])),
                      AppStatusPill(label: _platformLabel(map['platform'])),
                      AppStatusPill(label: _moduleLabel(map['module'])),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _EventDetailBlock(
                    title: 'Resumo',
                    value: [
                      'Usuário: ${_formatUser(map)}',
                      'Data e hora: ${_formatDate(map['created_at'])}',
                      'Resultado: ${_outcomeLabel(map['outcome'])}',
                      'Plataforma: ${_platformLabel(map['platform'])}',
                    ].join('\n'),
                  ),
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
                      if (!context.mounted) {
                        return;
                      }
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
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível carregar os detalhes do evento.'),
        ),
      );
    }
  }

  String _formatDate(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return '-';
    }
    final date = DateTime.tryParse(value.toString());
    if (date == null) {
      return value.toString();
    }
    return DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal());
  }

  String _friendlyActionTitle(Map<String, dynamic> item) {
    final action = item['action']?.toString() ?? '';
    final entity = item['entity_type']?.toString().toLowerCase() ?? '';

    const explicitTitles = <String, String>{
      'AUTH_LOGIN_SUCCESS': 'Login realizado',
      'AUTH_LOGIN_FAILURE': 'Falha de login',
      'AUTH_LOGOUT': 'Sessão encerrada',
      'AUTH_LOGOUT_ALL': 'Sessões encerradas',
      'AUTH_REGISTER_SUCCESS': 'Conta criada',
      'AUTH_REGISTER_FAILURE': 'Falha no cadastro',
      'AUTH_EMAIL_VERIFICATION_SENT': 'Código de verificação enviado',
      'AUTH_EMAIL_VERIFICATION_RESENT': 'Código de verificação reenviado',
      'AUTH_EMAIL_VERIFIED': 'E-mail confirmado',
      'AUTH_PASSWORD_RESET_REQUESTED': 'Recuperação de senha solicitada',
      'AUTH_PASSWORD_RESET_SUCCESS': 'Senha redefinida',
      'AUTH_REFRESH_TOKEN_ROTATED': 'Sessão renovada',
      'TASK_EQUIPMENT_ATTACHED': 'Equipamento vinculado à tarefa',
      'TASK_EQUIPMENT_DETACHED': 'Equipamento removido da tarefa',
      'ERROR_LOG_RESOLVED': 'Log de erro atualizado',
    };

    if (explicitTitles.containsKey(action)) {
      return explicitTitles[action]!;
    }

    const entityLabels = <String, String>{
      'task': 'Tarefa',
      'report': 'Relatório',
      'budget': 'Orçamento',
      'user': 'Usuário',
      'client': 'Cliente',
      'equipment': 'Equipamento',
      'product': 'Produto',
      'role': 'Perfil',
      'task_type': 'Tipo de tarefa',
      'report_template': 'Modelo de relatório',
      'error_log': 'Log de erro',
    };

    final label = entityLabels[entity];
    if (label != null) {
      if (action.endsWith('_CREATED')) return '$label criado';
      if (action.endsWith('_UPDATED')) return '$label atualizado';
      if (action.endsWith('_DELETED')) return '$label removido';
      if (action.endsWith('_STATUS_CHANGED')) return 'Status de $label atualizado';
      if (action.endsWith('_GENERATED')) return '$label gerado';
      if (action.endsWith('_APPROVED')) return '$label aprovado';
      if (action.endsWith('_REJECTED')) return '$label rejeitado';
    }

    final description = item['description']?.toString().trim() ?? '';
    if (description.isNotEmpty) {
      return description.endsWith('.')
          ? description.substring(0, description.length - 1)
          : description;
    }
    return 'Evento registrado';
  }

  String _friendlyDescription(Map<String, dynamic> item) {
    final description = item['description']?.toString().trim() ?? '';
    if (description.isNotEmpty) {
      return description;
    }
    return 'Ação registrada no histórico do sistema.';
  }

  String _formatUser(Map<String, dynamic> item) {
    final name = item['user_name']?.toString().trim() ?? '';
    if (name.isNotEmpty) {
      return name;
    }
    final email = item['user_email']?.toString().trim() ?? '';
    if (email.isNotEmpty) {
      return email;
    }
    return 'Sistema';
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

  String _moduleLabel(dynamic value) {
    const labels = <String, String>{
      'auth': 'Autenticação',
      'users': 'Usuários',
      'tasks': 'Tarefas',
      'reports': 'Relatórios',
      'budgets': 'Orçamentos',
      'monitoring': 'Monitoramento',
      'public': 'Páginas públicas',
      'system': 'Sistema',
    };
    final module = value?.toString().trim() ?? '';
    if (module.isEmpty) {
      return 'Sistema';
    }
    return labels[module] ?? module;
  }

  String _outcomeLabel(dynamic value) {
    return value?.toString() == 'success' ? 'Sucesso' : 'Falha';
  }

  String _buildSnapshot(Map<String, dynamic> map) {
    return [
      'ID: ${map['id']}',
      'Evento: ${_friendlyActionTitle(map)}',
      'Descrição: ${_friendlyDescription(map)}',
      'Usuário: ${_formatUser(map)}',
      'Data e hora: ${_formatDate(map['created_at'])}',
      'Resultado: ${_outcomeLabel(map['outcome'])}',
      'Plataforma: ${_platformLabel(map['platform'])}',
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
    if (!AuthService.instance.isAdmin) {
      return const AppScaffold(
        title: 'Log de eventos',
        body: Center(
          child: Text('Somente administradores podem acessar o log de eventos.'),
        ),
      );
    }

    final successCount = _items
        .where((item) => (item as Map)['outcome']?.toString() == 'success')
        .length;

    return AppScaffold(
      title: 'Log de eventos',
      subtitle: 'Auditoria operacional e rastreabilidade',
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
            subtitle: 'Erros, eventos e resolução com contexto.',
            metrics: [
              AppHeroMetric(label: 'Eventos', value: '${_items.length}'),
              AppHeroMetric(label: 'Sucesso', value: '$successCount'),
            ],
          ),
          const SizedBox(height: AppTokens.space4),
          AppSearchField(
            controller: _searchController,
            hintText: 'Buscar por ação, descrição ou usuário',
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
                MapEntry('', 'Todos'),
                MapEntry('success', 'Sucesso'),
                MapEntry('failure', 'Falha'),
              ])
                ChoiceChip(
                  label: Text(entry.value),
                  selected: _outcome == entry.key,
                  onSelected: (_) => setState(() => _outcome = entry.key),
                ),
            ],
          ),
          const SizedBox(height: AppTokens.space3),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
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
                ? const LoadingView(message: 'Carregando eventos...')
                : _error != null
                    ? AppMessageBanner(
                        message: _error!,
                        icon: Icons.error_outline_rounded,
                        toneColor: Theme.of(context).colorScheme.error,
                      )
                    : _items.isEmpty
                        ? const EmptyStateCard(
                            title: 'Nenhum evento encontrado',
                            subtitle:
                                'Ajuste os filtros para localizar outros registros de auditoria.',
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
                                          color: AppTokens.accentBlue
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        child: const Icon(
                                          Icons.event_note_rounded,
                                          color: AppTokens.accentBlue,
                                        ),
                                      ),
                                      const SizedBox(width: AppTokens.space3),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _friendlyActionTitle(item),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleSmall,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _friendlyDescription(item),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              '${_formatDate(item['created_at'])} • ${_formatUser(item)}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelMedium,
                                            ),
                                          ],
                                        ),
                                      ),
                                      AppStatusPill(
                                        label: _outcomeLabel(item['outcome']),
                                        color: item['outcome'] == 'success'
                                            ? AppTokens.accentBlue
                                            : Theme.of(context).colorScheme.error,
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
