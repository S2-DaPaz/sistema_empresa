import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/entity_refresh_service.dart';
import '../services/offline_cache_service.dart';
import '../utils/entity_config.dart';
import '../utils/field_config.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_search_field.dart';
import '../widgets/empty_state.dart';
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
  final ScrollController _listController = ScrollController();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  String _search = '';

  String get _cacheKey =>
      OfflineCacheService.endpointKey('entity', widget.config.endpoint);

  @override
  void initState() {
    super.initState();
    _primeFromCache();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _listController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final hadItems = _items.isNotEmpty;
    setState(() {
      _loading = !hadItems;
      _error = null;
    });
    try {
      final data = await _api.get(widget.config.endpoint) as List<dynamic>;
      final items = List<Map<String, dynamic>>.from(data);
      await OfflineCacheService.writeList(_cacheKey, items);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      final cached =
          hadItems ? _items : await OfflineCacheService.readList(_cacheKey);
      if (!mounted) return;
      if (cached != null && cached.isNotEmpty) {
        setState(() {
          _items = cached;
          _loading = false;
        });
        _showStaleDataWarning();
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _primeFromCache() async {
    final cached = await OfflineCacheService.readList(_cacheKey);
    if (!mounted || cached == null || cached.isEmpty || _items.isNotEmpty) {
      return;
    }
    setState(() {
      _items = cached;
      _loading = false;
      _error = null;
    });
  }

  void _showStaleDataWarning() {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          'Exibindo ${widget.config.title.toLowerCase()} salvos enquanto a API responde.',
        ),
      ),
    );
  }

  Future<void> _openForm({Map<String, dynamic>? item}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EntityFormScreen(config: widget.config, item: item),
      ),
    );
    if (mounted) {
      await _load();
    }
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final id = item['id'];
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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

    if (confirmed != true) return;

    try {
      await _api.delete('${widget.config.endpoint}/$id');
      EntityRefreshService.instance.notifyChanged(widget.config.endpoint);
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  String _buildSubtitle(Map<String, dynamic> item) {
    final parts = <String>[];
    for (final field in widget.config.fields) {
      if (field.name == widget.config.primaryField) continue;
      final value = item[field.name];
      if (value == null || value.toString().isEmpty) continue;
      if (field.type == FieldType.select && field.options.isNotEmpty) {
        final option = field.options.firstWhere(
          (current) => current.value.toString() == value.toString(),
          orElse: () => FieldOption(value: value, label: value.toString()),
        );
        parts.add(field.formatter?.call(option.label) ?? option.label);
      } else {
        parts.add(field.formatter?.call(value) ?? value.toString());
      }
    }
    return parts.join(' • ');
  }

  List<Map<String, dynamic>> get _filteredItems {
    final query = _search.trim().toLowerCase();
    if (query.isEmpty) return _items;
    return _items.where((item) {
      final haystack = item.values
          .map((value) => value?.toString() ?? '')
          .join(' ')
          .toLowerCase();
      return haystack.contains(query);
    }).toList();
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.config.title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Novo'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppSearchField(
            controller: _searchController,
            hintText: 'Buscar ${widget.config.title.toLowerCase()}...',
            onChanged: (value) => setState(() => _search = value),
          ),
          if (widget.config.hint != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(widget.config.hint!),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: items.isEmpty
                  ? ListView(
                      controller: _listController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 36),
                      children: [
                        EmptyState(
                          title: 'Nenhum registro encontrado',
                          message: widget.config.emptyMessage ??
                              'Crie um novo item para continuar.',
                          icon: Icons.list_alt_outlined,
                        ),
                      ],
                    )
                  : ListView.builder(
                      controller: _listController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 36),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Card(
                          child: ListTile(
                            onTap: () => _openForm(item: item),
                            title: Text(
                              item[widget.config.primaryField]?.toString() ??
                                  'Sem titulo',
                            ),
                            subtitle: Text(_buildSubtitle(item)),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _openForm(item: item);
                                } else if (value == 'delete') {
                                  _deleteItem(item);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Editar'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Remover'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
