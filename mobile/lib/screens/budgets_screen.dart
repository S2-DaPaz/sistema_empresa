import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../services/entity_refresh_service.dart';
import '../services/offline_cache_service.dart';
import '../theme/app_assets.dart';
import '../theme/app_tokens.dart';
import '../utils/budget_email.dart';
import '../utils/formatters.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_search_field.dart';
import '../widgets/budget_card.dart';
import '../widgets/budget_form.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  static const String _cacheKey = 'offline_cache_budgets_list';

  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _listController = ScrollController();

  StreamSubscription<String>? _entityRefreshSubscription;
  Future<void>? _lookupsFuture;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _budgets = [];
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _products = [];
  String _searchQuery = '';
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _entityRefreshSubscription = EntityRefreshService.instance.listen(
      const ['/products', '/clients'],
      (_) => _load(),
    );
    _primeFromCache();
    _load();
  }

  @override
  void dispose() {
    _entityRefreshSubscription?.cancel();
    _searchController.dispose();
    _listController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final hadBudgets = _budgets.isNotEmpty;
    setState(() {
      _loading = !hadBudgets;
      _error = null;
    });
    try {
      final budgets = await _api.get('/budgets') as List<dynamic>;
      final nextBudgets = List<Map<String, dynamic>>.from(budgets);
      await OfflineCacheService.writeList(_cacheKey, nextBudgets);
      if (!mounted) return;
      setState(() {
        _budgets = nextBudgets;
        _loading = false;
      });
      unawaited(_loadLookups());
    } catch (error) {
      final cached =
          hadBudgets ? _budgets : await OfflineCacheService.readList(_cacheKey);
      if (!mounted) return;
      if (cached != null && cached.isNotEmpty) {
        setState(() {
          _budgets = cached;
          _loading = false;
        });
        _showStaleDataWarning();
        unawaited(_loadLookups());
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
    if (!mounted || cached == null || cached.isEmpty || _budgets.isNotEmpty) {
      return;
    }
    setState(() {
      _budgets = cached;
      _loading = false;
      _error = null;
    });
  }

  Future<void> _loadLookups({bool force = false}) {
    if (!force && _clients.isNotEmpty && _products.isNotEmpty) {
      return Future.value();
    }
    if (!force && _lookupsFuture != null) {
      return _lookupsFuture!;
    }

    late final Future<void> future;
    future = () async {
      try {
        final results = await Future.wait([
          _api.get('/clients'),
          _api.get('/products'),
        ]);
        if (!mounted) return;
        setState(() {
          _clients = List<Map<String, dynamic>>.from(
            (results[0] as List?) ?? const [],
          );
          _products = List<Map<String, dynamic>>.from(
            (results[1] as List?) ?? const [],
          );
        });
      } catch (_) {
        // Lookup data should not block the list screen.
      } finally {
        if (identical(_lookupsFuture, future)) {
          _lookupsFuture = null;
        }
      }
    }();

    _lookupsFuture = future;
    return future;
  }

  Future<void> _ensureLookupsLoaded() {
    return _loadLookups(force: _clients.isEmpty || _products.isEmpty);
  }

  Map<String, int> get _statusCounts {
    final counts = <String, int>{
      'all': _budgets.length,
      'em_andamento': 0,
      'aprovado': 0,
      'recusado': 0,
    };
    for (final budget in _budgets) {
      final status = budget['status']?.toString() ?? 'em_andamento';
      counts[status] = (counts[status] ?? 0) + 1;
    }
    return counts;
  }

  List<Map<String, dynamic>> get _filteredBudgets {
    final query = _searchQuery.trim().toLowerCase();
    return _budgets.where((budget) {
      if (_statusFilter != null &&
          budget['status']?.toString() != _statusFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      final haystack = [
        budget['id'],
        budget['client_name'],
        budget['task_title'],
        budget['report_title'],
        budget['notes'],
        ...(budget['items'] as List<dynamic>? ?? [])
            .map((item) => (item as Map)['description']),
      ].map((value) => value?.toString() ?? '').join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  Future<void> _openBudgetForm([Map<String, dynamic>? budget]) async {
    await _ensureLookupsLoaded();
    if (!mounted) return;
    Map<String, dynamic>? initialBudget = budget;
    if (budget != null && budget['id'] != null && budget['items'] == null) {
      try {
        final detail = await _api.get('/budgets/${budget['id']}');
        if (detail is Map<String, dynamic>) {
          initialBudget = Map<String, dynamic>.from(detail);
        }
      } catch (_) {
        // Keep the list payload if the detail fetch fails.
      }
    }
    if (!mounted) return;

    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: BudgetForm(
            initialBudget: initialBudget,
            clients: _clients,
            products: _products,
            onSaved: () => Navigator.pop(context, true),
          ),
        ),
      ),
    );

    if (updated == true && mounted) {
      await _load();
    }
  }

  Future<void> _deleteBudget(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover orçamento'),
        content: const Text('Deseja remover este orçamento?'),
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
      await _api.delete('/budgets/$id');
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _sendEmail(Map<String, dynamic> budget) async {
    final client = _findClient(budget['client_id'] as int?);
    final subject = 'Orçamento #${budget['id']}';
    final body = buildBudgetEmailText(budget, client ?? {});
    final email = RegExp(
      r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}',
      caseSensitive: false,
    ).firstMatch(client?['contact']?.toString() ?? '');

    final uri = Uri(
      scheme: 'mailto',
      path: email?.group(0) ?? '',
      queryParameters: {
        'subject': subject,
        'body': body,
      },
    );
    await launchUrl(uri);
  }

  Map<String, dynamic>? _findClient(int? id) {
    if (id == null) return null;
    for (final client in _clients) {
      if (client['id'] == id) return client;
    }
    return null;
  }

  Future<String?> _getPublicLink(Map<String, dynamic> budget) async {
    final budgetId = budget['id'];
    if (budgetId == null) return null;
    final response = await _api.post('/budgets/$budgetId/public-link', {});
    return response['url']?.toString();
  }

  Future<void> _shareReportLink(Map<String, dynamic> budget) async {
    final url = await _getPublicLink(budget);
    if (url == null || url.isEmpty) return;
    await Share.share(url, subject: 'Orçamento #${budget['id']}');
  }

  Future<void> _openReportLink(Map<String, dynamic> budget) async {
    final url = await _getPublicLink(budget);
    if (url == null || url.isEmpty) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  String _statusLabel(String? value) {
    switch (value) {
      case 'aprovado':
        return 'Aprovado';
      case 'recusado':
        return 'Recusado';
      default:
        return 'Em andamento';
    }
  }

  void _showStaleDataWarning() {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      const SnackBar(
        content: Text(
          'Orcamentos exibidos com dados salvos enquanto a API responde.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppScaffold(
        title: 'Orçamentos',
        body: LoadingView(message: 'Carregando orçamentos...'),
      );
    }

    if (_error != null) {
      return AppScaffold(
        title: 'Orçamentos',
        body: ErrorView(message: _error!, onRetry: _load),
      );
    }

    final budgets = _filteredBudgets;

    return AppScaffold(
      title: 'Orçamentos',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Orcamentos',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _openBudgetForm(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Novo'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppSearchField(
            controller: _searchController,
            hintText: 'Buscar orcamentos...',
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _BudgetFilterChip(
                  label: 'Todas',
                  count: _statusCounts['all'] ?? 0,
                  selected: _statusFilter == null,
                  onTap: () => setState(() => _statusFilter = null),
                ),
                _BudgetFilterChip(
                  label: 'Abertos',
                  count: _statusCounts['em_andamento'] ?? 0,
                  selected: _statusFilter == 'em_andamento',
                  onTap: () => setState(() => _statusFilter = 'em_andamento'),
                ),
                _BudgetFilterChip(
                  label: 'Aprovados',
                  count: _statusCounts['aprovado'] ?? 0,
                  selected: _statusFilter == 'aprovado',
                  onTap: () => setState(() => _statusFilter = 'aprovado'),
                ),
                _BudgetFilterChip(
                  label: 'Recusados',
                  count: _statusCounts['recusado'] ?? 0,
                  selected: _statusFilter == 'recusado',
                  onTap: () => setState(() => _statusFilter = 'recusado'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: budgets.isEmpty
                  ? ListView(
                      controller: _listController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 40),
                      children: const [
                        SizedBox(height: 12),
                        EmptyState(
                          title: 'Nenhum orcamento encontrado',
                          message:
                              'Crie um novo orcamento para comecar a compor propostas.',
                          icon: Icons.receipt_long_outlined,
                          illustrationAsset: AppAssets.emptyBudgets,
                        ),
                      ],
                    )
                  : ListView.builder(
                      controller: _listController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 40),
                      itemCount: budgets.length,
                      itemBuilder: (context, index) {
                        final budget = budgets[index];
                        return BudgetCard(
                          code: 'ORC #${budget['id']}',
                          clientName: budget['client_name']?.toString() ??
                              'Sem cliente',
                          description: budget['task_title']
                                      ?.toString()
                                      .isNotEmpty ==
                                  true
                              ? budget['task_title'].toString()
                              : budget['notes']?.toString().isNotEmpty == true
                                  ? budget['notes'].toString()
                                  : 'Sem descricao adicional',
                          dateLabel: budget['created_at']
                                      ?.toString()
                                      .isNotEmpty ==
                                  true
                              ? 'Enviado em ${formatDate(budget['created_at'].toString())}'
                              : 'Sem data',
                          amountLabel: formatCurrency(budget['total'] ?? 0),
                          statusLabel:
                              _statusLabel(budget['status']?.toString()),
                          onTap: () => _openBudgetForm(budget),
                          onMore: () => _openBudgetActions(budget),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openBudgetActions(Map<String, dynamic> budget) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar orcamento'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.mail_outline_rounded),
              title: const Text('Enviar por e-mail'),
              onTap: () => Navigator.pop(context, 'email'),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Compartilhar link'),
              onTap: () => Navigator.pop(context, 'share'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Abrir PDF publico'),
              onTap: () => Navigator.pop(context, 'pdf'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Remover orcamento'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;

    switch (action) {
      case 'edit':
        await _openBudgetForm(budget);
        break;
      case 'email':
        await _sendEmail(budget);
        break;
      case 'share':
        await _shareReportLink(budget);
        break;
      case 'pdf':
        await _openReportLink(budget);
        break;
      case 'delete':
        if (budget['id'] is int) {
          await _deleteBudget(budget['id'] as int);
        }
        break;
    }
  }
}

class _BudgetFilterChip extends StatelessWidget {
  const _BudgetFilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
          ),
          child: Text(
            '$label  $count',
            style: theme.textTheme.labelMedium?.copyWith(
              color: selected
                  ? theme.colorScheme.onPrimary
                  : theme.textTheme.labelMedium?.color,
            ),
          ),
        ),
      ),
    );
  }
}
