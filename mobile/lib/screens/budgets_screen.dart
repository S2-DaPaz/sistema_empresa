import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/entity_refresh_service.dart';
import '../services/offline_cache_service.dart';
import '../services/permissions.dart';
import '../theme/app_assets.dart';
import '../theme/app_tokens.dart';
import '../utils/contact_utils.dart';
import '../utils/formatters.dart';
import '../utils/label_mappers.dart';
import '../widgets/access_restricted_state.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_search_field.dart';
import '../widgets/budget_card.dart';
import '../widgets/budget_form.dart';
import '../widgets/email_recipient_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key, this.clientId, this.clientName});

  final int? clientId;
  final String? clientName;

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  static const String _chaveCache = 'offline_cache_orcamentos_list';

  final ApiService _api = ApiService();
  final TextEditingController _controladorBusca = TextEditingController();
  final ScrollController _controladorLista = ScrollController();

  StreamSubscription<String>? _inscricaoAtualizacaoEntidade;
  Future<void>? _futuroConsultas;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _orcamentos = [];
  List<Map<String, dynamic>> _clientes = [];
  List<Map<String, dynamic>> _produtos = [];
  String _textoBusca = '';
  String? _filtroStatus;
  bool get _canViewData => Permissions.canViewModuleData(AppModule.budgets);
  bool get _canManage => Permissions.canManageModule(AppModule.budgets);
  bool get _isDemoMode => AuthService.instance.isVisitor;

  @override
  void initState() {
    super.initState();
    _inscricaoAtualizacaoEntidade = EntityRefreshService.instance.listen(
      const ['/products', '/clients'],
      (_) => _load(),
    );
    if (!_canViewData) {
      _loading = false;
      return;
    }
    if (!_isDemoMode) {
      _carregarDoCache();
    }
    _load();
  }

  @override
  void dispose() {
    _inscricaoAtualizacaoEntidade?.cancel();
    _controladorBusca.dispose();
    _controladorLista.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final hadBudgets = _orcamentos.isNotEmpty;
    setState(() {
      _loading = !hadBudgets;
      _error = null;
    });
    try {
      final endpoint = widget.clientId != null
          ? '/budgets?clientId=${widget.clientId}'
          : '/budgets';
      final budgets = await _api.get(endpoint) as List<dynamic>;
      final nextBudgets = List<Map<String, dynamic>>.from(budgets);
      if (!_isDemoMode) {
        await OfflineCacheService.writeList(_chaveCache, nextBudgets);
      }
      if (!mounted) return;
      setState(() {
        _orcamentos = nextBudgets;
        _loading = false;
      });
      unawaited(_loadLookups());
    } catch (error) {
      final cached = hadBudgets || _isDemoMode
          ? _orcamentos
          : await OfflineCacheService.readList(_chaveCache);
      if (!mounted) return;
      if (cached != null && cached.isNotEmpty) {
        setState(() {
          _orcamentos = cached;
          _loading = false;
        });
        _mostrarAvisoDadosAntigos();
        unawaited(_loadLookups());
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _carregarDoCache() async {
    final cached = await OfflineCacheService.readList(_chaveCache);
    if (!mounted || cached == null || cached.isEmpty || _orcamentos.isNotEmpty) {
      return;
    }
    setState(() {
      _orcamentos = cached;
      _loading = false;
      _error = null;
    });
  }

  Future<void> _loadLookups({bool force = false}) {
    if (!_canManage) {
      return Future.value();
    }
    if (!force && _clientes.isNotEmpty && _produtos.isNotEmpty) {
      return Future.value();
    }
    if (!force && _futuroConsultas != null) {
      return _futuroConsultas!;
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
          _clientes = List<Map<String, dynamic>>.from(
            (results[0] as List?) ?? const [],
          );
          _produtos = List<Map<String, dynamic>>.from(
            (results[1] as List?) ?? const [],
          );
        });
      } catch (_) {
        // Lookup data should not block the list screen.
      } finally {
        if (identical(_futuroConsultas, future)) {
          _futuroConsultas = null;
        }
      }
    }();

    _futuroConsultas = future;
    return future;
  }

  Future<void> _garantirConsultasCarregadas() {
    return _loadLookups(force: _clientes.isEmpty || _produtos.isEmpty);
  }

  Map<String, int> get _contagemStatus {
    final counts = <String, int>{
      'all': _orcamentos.length,
      'em_andamento': 0,
      'aprovado': 0,
      'recusado': 0,
    };
    for (final budget in _orcamentos) {
      final status = budget['status']?.toString() ?? 'em_andamento';
      counts[status] = (counts[status] ?? 0) + 1;
    }
    return counts;
  }

  List<Map<String, dynamic>> get _orcamentosFiltrados {
    final query = _textoBusca.trim().toLowerCase();
    return _orcamentos.where((budget) {
      if (_filtroStatus != null &&
          budget['status']?.toString() != _filtroStatus) {
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

  Future<void> _abrirFormularioOrcamento([Map<String, dynamic>? budget]) async {
    if (!_canManage) return;
    await _garantirConsultasCarregadas();
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

    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => _BudgetFormPage(
          initialBudget: initialBudget,
          clients: _clientes,
          products: _produtos,
        ),
      ),
    );

    if (updated == true && mounted) {
      await _load();
    }
  }

  Future<void> _excluirOrcamento(int id) async {
    if (!_canManage) return;
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

  Future<void> _enviarEmail(Map<String, dynamic> budget) async {
    if (!_canManage) return;
    final client = _encontrarCliente(budget['client_id'] as int?);
    final budgetId = budget['id'];
    if (budgetId == null) return;

    final email = await showEmailRecipientDialog(
      context,
      title: 'Enviar orçamento por e-mail',
      message:
          'Confirme o e-mail do destinatário para enviar um link seguro do orçamento.',
      confirmLabel: 'Enviar orçamento',
      initialEmail: extrairEmail(client?['contact']?.toString()),
    );
    if (email == null || email.isEmpty) return;

    try {
      final response = await _api.post('/budgets/$budgetId/email-link', {
        'email': email,
      });
      if (!mounted) return;
      final message =
          response is Map<String, dynamic> && response['message'] != null
              ? response['message'].toString()
              : 'Orçamento enviado por e-mail com sucesso.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Map<String, dynamic>? _encontrarCliente(int? id) {
    if (id == null) return null;
    for (final client in _clientes) {
      if (client['id'] == id) return client;
    }
    return null;
  }

  Future<String?> _obterLinkPublico(Map<String, dynamic> budget) async {
    if (!_canManage) return null;
    final budgetId = budget['id'];
    if (budgetId == null) return null;
    final response = await _api.post('/budgets/$budgetId/public-link', {});
    return response['url']?.toString();
  }

  Future<void> _compartilharLinkRelatorio(Map<String, dynamic> budget) async {
    final url = await _obterLinkPublico(budget);
    if (url == null || url.isEmpty) return;
    await Share.share(url, subject: 'Orçamento #${budget['id']}');
  }

  Future<void> _abrirLinkRelatorio(Map<String, dynamic> budget) async {
    final url = await _obterLinkPublico(budget);
    if (url == null || url.isEmpty) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }


  void _mostrarAvisoDadosAntigos() {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      const SnackBar(
        content: Text(
          'Orçamentos exibidos com dados salvos enquanto a API responde.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showBar = widget.clientId != null;

    if (!_canViewData) {
      return AppScaffold(
        title: 'Orçamentos',
        showAppBar: showBar,
        body: const AccessRestrictedState(
          title: 'Orçamentos protegidos para este perfil',
          message:
              'O perfil visitante pode acessar a tela, mas não pode visualizar propostas, valores nem ações derivadas.',
        ),
      );
    }

    if (_loading) {
      return AppScaffold(
        title: 'Orçamentos',
        showAppBar: showBar,
        body: const LoadingView(message: 'Carregando orçamentos...'),
      );
    }

    if (_error != null) {
      return AppScaffold(
        title: 'Orçamentos',
        showAppBar: showBar,
        body: ErrorView(message: _error!, onRetry: _load),
      );
    }

    final budgets = _orcamentosFiltrados;

    return AppScaffold(
      title: 'Orçamentos',
      showAppBar: showBar,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
                Expanded(
                  child: Text(
                    widget.clientName != null
                      ? 'Orçamentos — ${widget.clientName}'
                      : 'Orçamentos',
                  style: Theme.of(context).textTheme.headlineMedium,
                  maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (_canManage)
                ElevatedButton.icon(
                  onPressed: () => _abrirFormularioOrcamento(),
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
            hintText: 'Buscar orçamentos...',
            onChanged: (value) => setState(() => _textoBusca = value),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _BudgetFilterChip(
                  label: 'Todas',
                  count: _contagemStatus['all'] ?? 0,
                  selected: _filtroStatus == null,
                  onTap: () => setState(() => _filtroStatus = null),
                ),
                _BudgetFilterChip(
                  label: 'Abertos',
                  count: _contagemStatus['em_andamento'] ?? 0,
                  selected: _filtroStatus == 'em_andamento',
                  onTap: () => setState(() => _filtroStatus = 'em_andamento'),
                ),
                _BudgetFilterChip(
                  label: 'Aprovados',
                  count: _contagemStatus['aprovado'] ?? 0,
                  selected: _filtroStatus == 'aprovado',
                  onTap: () => setState(() => _filtroStatus = 'aprovado'),
                ),
                _BudgetFilterChip(
                  label: 'Recusados',
                  count: _contagemStatus['recusado'] ?? 0,
                  selected: _filtroStatus == 'recusado',
                  onTap: () => setState(() => _filtroStatus = 'recusado'),
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
                      controller: _controladorLista,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 40),
                      children: const [
                        SizedBox(height: 12),
                        EmptyState(
                          title: 'Nenhum orçamento encontrado',
                          message:
                              'Crie um novo orçamento para começar a compor propostas.',
                          icon: Icons.receipt_long_outlined,
                          illustrationAsset: AppAssets.emptyBudgets,
                        ),
                      ],
                    )
                  : ListView.builder(
                      controller: _controladorLista,
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
                                  : 'Sem descrição adicional',
                          dateLabel: budget['created_at']
                                      ?.toString()
                                      .isNotEmpty ==
                                  true
                              ? 'Enviado em ${formatarData(budget['created_at'].toString())}'
                              : 'Sem data',
                          amountLabel: formatarMoeda(budget['total'] ?? 0),
                          statusLabel:
                              labelStatusOrcamento(budget['status']?.toString()),
                          onTap: _canManage
                              ? () => _abrirFormularioOrcamento(budget)
                              : null,
                          onMore:
                              _canManage ? () => _abrirAcoesOrcamento(budget) : null,
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirAcoesOrcamento(Map<String, dynamic> budget) async {
    if (!_canManage) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar orçamento'),
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
              title: const Text('Remover orçamento'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;

    switch (action) {
      case 'edit':
        await _abrirFormularioOrcamento(budget);
        break;
      case 'email':
        await _enviarEmail(budget);
        break;
      case 'share':
        await _compartilharLinkRelatorio(budget);
        break;
      case 'pdf':
        await _abrirLinkRelatorio(budget);
        break;
      case 'delete':
        if (budget['id'] is int) {
          await _excluirOrcamento(budget['id'] as int);
        }
        break;
    }
  }
}

class _BudgetFormPage extends StatelessWidget {
  const _BudgetFormPage({
    required this.clients,
    required this.products,
    this.initialBudget,
  });

  final Map<String, dynamic>? initialBudget;
  final List<Map<String, dynamic>> clients;
  final List<Map<String, dynamic>> products;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          initialBudget != null ? 'Editar orçamento' : 'Novo orçamento',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: BudgetForm(
          initialBudget: initialBudget,
          clients: clients,
          products: products,
          onSaved: () => Navigator.pop(context, true),
        ),
      ),
    );
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
