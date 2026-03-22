import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/entity_refresh_service.dart';
import '../theme/app_tokens.dart';
import '../utils/entity_config.dart';
import '../utils/field_config.dart';
import '../utils/formatters.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_ui.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';
import 'entity_form_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final List<Color> _accentColors = const [
    AppTokens.accentBlue,
    AppTokens.primaryCyan,
    AppTokens.supportTeal,
    AppTokens.accentViolet,
  ];

  StreamSubscription<String>? _entityRefreshSubscription;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _products = [];
  String _query = '';
  String? _categoryFilter;

  EntityConfig get _config => EntityConfig(
        title: 'Produtos',
        endpoint: '/products',
        primaryField: 'name',
        hint: 'Catálogo otimizado para orçamentos rápidos.',
        emptyMessage: 'Cadastre o primeiro produto para montar propostas com mais agilidade.',
        fields: [
          FieldConfig(name: 'name', label: 'Nome', type: FieldType.text),
          FieldConfig(name: 'sku', label: 'SKU', type: FieldType.text),
          FieldConfig(name: 'unit', label: 'Categoria', type: FieldType.text),
          FieldConfig(name: 'price', label: 'Preço base', type: FieldType.number),
        ],
      );

  @override
  void initState() {
    super.initState();
    _entityRefreshSubscription = EntityRefreshService.instance.listen(
      const ['/products'],
      (_) => _load(),
    );
    _load();
  }

  @override
  void dispose() {
    _entityRefreshSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.get('/products') as List<dynamic>;
      if (!mounted) {
        return;
      }
      setState(() {
        _products = data.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Não foi possível carregar o catálogo de produtos.';
        _loading = false;
      });
    }
  }

  Future<void> _openForm({Map<String, dynamic>? item}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EntityFormScreen(config: _config, item: item),
      ),
    );
    await _load();
  }

  Future<void> _deleteProduct(Map<String, dynamic> item) async {
    final id = item['id'];
    if (id == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover produto'),
        content: const Text('Deseja remover este produto do catálogo?'),
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
      await _api.delete('/products/$id');
      EntityRefreshService.instance.notifyChanged('/products');
      await _load();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível remover o produto agora.'),
        ),
      );
    }
  }

  List<String> get _categories {
    final categories = _products
        .map((item) => item['unit']?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return categories;
  }

  List<Map<String, dynamic>> get _filteredProducts {
    final normalizedQuery = _query.trim().toLowerCase();
    return _products.where((product) {
      if (_categoryFilter != null &&
          (product['unit']?.toString().trim() ?? '') != _categoryFilter) {
        return false;
      }
      if (normalizedQuery.isEmpty) {
        return true;
      }
      final searchable = [
        product['name'],
        product['sku'],
        product['unit'],
      ].map((value) => value?.toString() ?? '').join(' ').toLowerCase();
      return searchable.contains(normalizedQuery);
    }).toList();
  }

  String _subtitleFor(Map<String, dynamic> product) {
    final unit = product['unit']?.toString().trim() ?? '';
    final sku = product['sku']?.toString().trim() ?? '';
    if (unit.isNotEmpty && sku.isNotEmpty) {
      return '$unit • SKU $sku';
    }
    if (unit.isNotEmpty) {
      return unit;
    }
    if (sku.isNotEmpty) {
      return 'SKU $sku';
    }
    return 'Disponível para composição comercial';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppScaffold(
        title: 'Produtos',
        subtitle: 'Catálogo otimizado para orçamentos rápidos',
        showLogo: false,
        body: LoadingView(),
      );
    }

    if (_error != null) {
      return AppScaffold(
        title: 'Produtos',
        subtitle: 'Catálogo otimizado para orçamentos rápidos',
        showLogo: false,
        body: ErrorView(message: _error!, onRetry: _load),
      );
    }

    final products = _filteredProducts;

    return AppScaffold(
      title: 'Produtos',
      subtitle: 'Catálogo otimizado para orçamentos rápidos',
      showLogo: false,
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-products',
        onPressed: () => _openForm(),
        child: const Icon(Icons.add_rounded),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            AppSearchField(
              controller: _searchController,
              hintText: 'Buscar por nome, SKU ou categoria',
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
            const SizedBox(height: AppTokens.space4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Todos'),
                  selected: _categoryFilter == null,
                  onSelected: (_) => setState(() => _categoryFilter = null),
                ),
                for (final category in _categories.take(4))
                  ChoiceChip(
                    label: Text(category),
                    selected: _categoryFilter == category,
                    onSelected: (_) => setState(() => _categoryFilter = category),
                  ),
              ],
            ),
            const SizedBox(height: AppTokens.space5),
            if (_products.isEmpty)
              EmptyStateCard(
                title: 'Nenhum produto cadastrado',
                subtitle: _config.emptyMessage!,
                action: ElevatedButton(
                  onPressed: () => _openForm(),
                  child: const Text('Novo produto'),
                ),
              ),
            if (_products.isNotEmpty && products.isEmpty)
              const EmptyStateCard(
                title: 'Nenhum produto encontrado',
                subtitle: 'Ajuste a busca ou os filtros para localizar outro item.',
              ),
            if (products.isNotEmpty)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.72,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  final accent = _accentColors[index % _accentColors.length];
                  return AppSurface(
                    onTap: () => _openForm(item: product),
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                          child: Container(
                            height: 62,
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 12, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        product['name']?.toString() ?? 'Produto',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context).textTheme.titleSmall,
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_horiz_rounded),
                                      onSelected: (value) {
                                        if (value == 'edit') {
                                          _openForm(item: product);
                                        } else if (value == 'delete') {
                                          _deleteProduct(product);
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
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _subtitleFor(product),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const Spacer(),
                                Text(
                                  formatCurrency(product['price'] ?? 0),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        color: AppTokens.accentBlue,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 96),
          ],
        ),
      ),
    );
  }
}
