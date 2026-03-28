import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/entity_refresh_service.dart';
import '../services/offline_cache_service.dart';
import '../services/permissions.dart';
import '../utils/entity_config.dart';
import '../utils/field_config.dart';
import '../widgets/access_restricted_state.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_search_field.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';
import 'entity_form_screen.dart';

class EntityListScreen extends StatefulWidget {
  const EntityListScreen({super.key, required this.config});

  final ConfiguracaoEntidade config;

  @override
  State<EntityListScreen> createState() => _EntityListScreenState();
}

class _EntityListScreenState extends State<EntityListScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _controladorBusca = TextEditingController();
  final ScrollController _controladorLista = ScrollController();

  bool _carregando = true;
  String? _erro;
  List<Map<String, dynamic>> _itens = [];
  String _busca = '';
  bool get _canViewData => Permissions.canViewEndpointData(widget.config.endpoint);
  bool get _canManage => Permissions.canManageEndpoint(widget.config.endpoint);

  String get _chaveCache =>
      OfflineCacheService.endpointKey('entity', widget.config.endpoint);

  @override
  void initState() {
    super.initState();
    if (!_canViewData) {
      _carregando = false;
      return;
    }
    _carregarDoCache();
    _carregar();
  }

  @override
  void dispose() {
    _controladorBusca.dispose();
    _controladorLista.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    final hadItems = _itens.isNotEmpty;
    setState(() {
      _carregando = !hadItems;
      _erro = null;
    });
    try {
      final data = await _api.get(widget.config.endpoint) as List<dynamic>;
      final items = List<Map<String, dynamic>>.from(data);
      await OfflineCacheService.writeList(_chaveCache, items);
      if (!mounted) return;
      setState(() {
        _itens = items;
        _carregando = false;
      });
    } catch (error) {
      final cached =
          hadItems ? _itens : await OfflineCacheService.readList(_chaveCache);
      if (!mounted) return;
      if (cached != null && cached.isNotEmpty) {
        setState(() {
          _itens = cached;
          _carregando = false;
        });
        _mostrarAvisoDadosAntigos();
        return;
      }
      setState(() {
        _erro = error.toString();
        _carregando = false;
      });
    }
  }

  Future<void> _carregarDoCache() async {
    final cached = await OfflineCacheService.readList(_chaveCache);
    if (!mounted || cached == null || cached.isEmpty || _itens.isNotEmpty) {
      return;
    }
    setState(() {
      _itens = cached;
      _carregando = false;
      _erro = null;
    });
  }

  void _mostrarAvisoDadosAntigos() {
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

  Future<void> _abrirFormulario({Map<String, dynamic>? item}) async {
    if (!_canManage) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EntityFormScreen(config: widget.config, item: item),
      ),
    );
    if (mounted) {
      await _carregar();
    }
  }

  Future<void> _excluirItem(Map<String, dynamic> item) async {
    if (!_canManage) return;
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
      await _carregar();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  String _construirSubtitulo(Map<String, dynamic> item) {
    final parts = <String>[];
    for (final field in widget.config.fields) {
      if (field.name == widget.config.primaryField) continue;
      final value = item[field.name];
      if (value == null || value.toString().isEmpty) continue;
      if (field.type == TipoCampo.select && field.options.isNotEmpty) {
        final option = field.options.firstWhere(
          (current) => current.value.toString() == value.toString(),
          orElse: () => OpcaoCampo(value: value, label: value.toString()),
        );
        parts.add(field.formatter?.call(option.label) ?? option.label);
      } else {
        parts.add(field.formatter?.call(value) ?? value.toString());
      }
    }
    return parts.join(' • ');
  }

  List<Map<String, dynamic>> get _itensFiltrados {
    final query = _busca.trim().toLowerCase();
    if (query.isEmpty) return _itens;
    return _itens.where((item) {
      final haystack = item.values
          .map((value) => value?.toString() ?? '')
          .join(' ')
          .toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (!_canViewData) {
      return AppScaffold(
        title: widget.config.title,
        body: AccessRestrictedState(
          title: '${widget.config.title} protegidos para este perfil',
          message:
              'Seu perfil pode navegar por esta tela, mas não pode visualizar registros reais nem executar ações de gerenciamento.',
        ),
      );
    }

    if (_carregando) {
      return AppScaffold(title: widget.config.title, body: const LoadingView());
    }
    if (_erro != null) {
      return AppScaffold(
        title: widget.config.title,
        body: ErrorView(message: _erro!, onRetry: _carregar),
      );
    }

    final items = _itensFiltrados;

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
              if (_canManage)
                ElevatedButton.icon(
                  onPressed: () => _abrirFormulario(),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 42),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Novo'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          AppSearchField(
            controller: _controladorBusca,
            hintText: 'Buscar ${widget.config.title.toLowerCase()}...',
            onChanged: (value) => setState(() => _busca = value),
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
              onRefresh: _carregar,
              child: items.isEmpty
                  ? ListView(
                      controller: _controladorLista,
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
                      controller: _controladorLista,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 36),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Card(
                          child: ListTile(
                            onTap:
                                _canManage ? () => _abrirFormulario(item: item) : null,
                            title: Text(
                              item[widget.config.primaryField]?.toString() ??
                                  'Sem título',
                            ),
                            subtitle: Text(_construirSubtitulo(item)),
                            trailing: _canManage
                                ? PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        _abrirFormulario(item: item);
                                      } else if (value == 'delete') {
                                        _excluirItem(item);
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
                                  )
                                : null,
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
