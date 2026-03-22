import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/entity_refresh_service.dart';
import '../theme/app_tokens.dart';
import '../utils/entity_config.dart';
import '../utils/field_config.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_ui.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';
import 'entity_form_screen.dart';

class EntityListScreen extends StatefulWidget {
  const EntityListScreen({super.key, required this.config});

  final EntityConfig config;

  @override
  State<EntityListScreen> createState() => _EntityListScreenState();
}

class _EntityListScreenState extends State<EntityListScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  List<dynamic> _items = [];
  String _query = '';

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
      final data = await _api.get(widget.config.endpoint);
      if (!mounted) {
        return;
      }
      setState(() {
        _items = data as List<dynamic>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Não foi possível carregar os registros desta área.';
        _loading = false;
      });
    }
  }

  Future<void> _openForm({Map<String, dynamic>? item}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EntityFormScreen(config: widget.config, item: item),
      ),
    );
    await _load();
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final id = item['id'];
    if (id == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover registro'),
        content: const Text('Deseja remover este item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    try {
      await _api.delete('${widget.config.endpoint}/$id');
      EntityRefreshService.instance.notifyChanged(widget.config.endpoint);
      await _load();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível remover o registro agora.'),
        ),
      );
    }
  }

  String _buildSubtitle(Map<String, dynamic> item) {
    final parts = <String>[];
    for (final field in widget.config.fields) {
      if (field.name == widget.config.primaryField) {
        continue;
      }
      final value = item[field.name];
      if (value == null || value.toString().isEmpty) {
        continue;
      }
      if (field.type == FieldType.select && field.options.isNotEmpty) {
        final match = field.options.firstWhere(
          (option) => option.value.toString() == value.toString(),
          orElse: () => FieldOption(value: value, label: value.toString()),
        );
        final formatted = field.formatter?.call(match.label) ?? match.label;
        parts.add(formatted.toString());
      } else {
        final formatted = field.formatter?.call(value) ?? value;
        parts.add(formatted.toString());
      }
    }
    return parts.join(' • ');
  }

  String _searchText(Map<String, dynamic> item) {
    final values = widget.config.fields
        .map((field) => item[field.name]?.toString() ?? '')
        .join(' ');
    return values.toLowerCase();
  }

  List<Map<String, dynamic>> get _filteredItems {
    if (_query.trim().isEmpty) {
      return _items.cast<Map<String, dynamic>>();
    }
    final normalized = _query.trim().toLowerCase();
    return _items
        .cast<Map<String, dynamic>>()
        .where((item) => _searchText(item).contains(normalized))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return AppScaffold(title: widget.config.title, body: const LoadingView());
    }
    if (_error != null) {
      return AppScaffold(
        title: widget.config.title,
        body: ErrorView(message: _error!, onRetry: _load),
      );
    }

    final items = _filteredItems;

    return AppScaffold(
      title: widget.config.title,
      subtitle: 'Lista operacional',
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-entity-${widget.config.endpoint}',
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            AppHeroBanner(
              title: widget.config.title,
              subtitle: widget.config.hint ?? 'Lista operacional da entidade.',
              metrics: [
                AppHeroMetric(
                  label: 'Total',
                  value: '${_items.length}',
                ),
                AppHeroMetric(
                  label: 'Visíveis',
                  value: '${items.length}',
                ),
              ],
            ),
            const SizedBox(height: AppTokens.space5),
            AppSearchField(
              controller: _searchController,
              hintText: 'Buscar por nome, código ou descrição',
              onChanged: (value) => setState(() => _query = value),
              trailing: _query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
            const SizedBox(height: AppTokens.space5),
            AppSectionBlock(
              title: 'Registros',
              subtitle: widget.config.emptyMessage ??
                  'Nenhum registro foi encontrado nesta área.',
            ),
            const SizedBox(height: AppTokens.space4),
            if (_items.isEmpty)
              EmptyStateCard(
                title: 'Nenhum registro cadastrado',
                subtitle: widget.config.emptyMessage ??
                    'Crie o primeiro item para começar.',
                action: ElevatedButton(
                  onPressed: () => _openForm(),
                  child: const Text('Novo cadastro'),
                ),
              ),
            if (_items.isNotEmpty && items.isEmpty)
              const EmptyStateCard(
                title: 'Nenhum resultado encontrado',
                subtitle: 'Ajuste o texto da busca para localizar outro registro.',
              ),
            ...items.map((item) {
              final title =
                  item[widget.config.primaryField]?.toString() ?? 'Sem título';
              final subtitle = _buildSubtitle(item);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppSurface(
                  onTap: () => _openForm(item: item),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppTokens.accentBlue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.layers_outlined,
                          color: AppTokens.accentBlue,
                        ),
                      ),
                      const SizedBox(width: AppTokens.space4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            if (subtitle.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                subtitle,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            _openForm(item: item);
                          }
                          if (value == 'delete') {
                            _deleteItem(item);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'edit', child: Text('Editar')),
                          PopupMenuItem(value: 'delete', child: Text('Remover')),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 96),
          ],
        ),
      ),
    );
  }
}
