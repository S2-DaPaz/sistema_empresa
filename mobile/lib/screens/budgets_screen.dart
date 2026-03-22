import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../services/entity_refresh_service.dart';
import '../theme/app_tokens.dart';
import '../utils/budget_email.dart';
import '../utils/formatters.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_ui.dart';
import '../widgets/budget_form.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();

  StreamSubscription<String>? _entityRefreshSubscription;
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
      final budgets = await _api.get('/budgets?includeItems=1') as List<dynamic>;
      final clients = await _api.get('/clients') as List<dynamic>;
      final products = await _api.get('/products') as List<dynamic>;

      if (!mounted) {
        return;
      }

      setState(() {
        _budgets = budgets.cast<Map<String, dynamic>>();
        _clients = clients.cast<Map<String, dynamic>>();
        _products = products.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Não foi possível carregar o pipeline de orçamentos.';
        _loading = false;
      });
    }
  }

  Map<String, dynamic>? _findClient(int? id) {
    if (id == null) return null;
    return _clients.firstWhere(
      (client) => client['id'] == id,
      orElse: () => {},
    );
  }

  Future<void> _sendEmail(Map<String, dynamic> budget) async {
    final client = _findClient(budget['client_id'] as int?);
    final email = extractEmail(client?['contact']?.toString() ?? '');
    final subject = 'Orçamento #${budget['id']}';
    final body = buildBudgetEmailText(budget, client ?? {});
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        'subject': subject,
        'body': body,
      },
    );
    await launchUrl(uri);
  }

  Future<String?> _getPublicLink(Map<String, dynamic> budget) async {
    final budgetId = budget['id'];
    if (budgetId == null) return null;
    try {
      final response = await _api.post('/budgets/$budgetId/public-link', {});
      return response['url']?.toString();
    } catch (_) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível gerar o link público agora.'),
        ),
      );
      return null;
    }
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

  String _buildSearchText(Map<String, dynamic> budget) {
    final items = (budget['items'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map((item) => item['description']?.toString() ?? '')
        .join(' ');
    final parts = [
      budget['id']?.toString(),
      budget['client_name'],
      budget['task_title'],
      budget['report_title'],
      budget['status'],
      items,
    ];
    return parts.map((value) => value?.toString() ?? '').join(' ').toLowerCase();
  }

  List<Map<String, dynamic>> _filteredBudgets() {
    final query = _searchQuery.trim().toLowerCase();
    return _budgets.where((budget) {
      if (_statusFilter != null && budget['status']?.toString() != _statusFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      return _buildSearchText(budget).contains(query);
    }).toList();
  }

  Future<void> _editBudget(Map<String, dynamic> budget) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.92,
          minChildSize: 0.6,
          maxChildSize: 0.98,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  16 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: BudgetForm(
                  initialBudget: budget,
                  clients: _clients,
                  products: _products,
                  onSaved: () => Navigator.pop(context, true),
                ),
              ),
            );
          },
        );
      },
    );

    if (updated == true) {
      await _load();
    }
  }

  Future<void> _deleteBudget(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível remover o orçamento agora.'),
        ),
      );
    }
  }

  String _formatStatus(String? value) {
    switch (value) {
      case 'em_andamento':
        return 'Em andamento';
      case 'aprovado':
        return 'Aprovado';
      case 'recusado':
        return 'Recusado';
      default:
        return value?.toString() ?? 'Em andamento';
    }
  }

  Color _statusColor(String? value) {
    switch (value) {
      case 'aprovado':
        return AppTokens.supportTeal;
      case 'recusado':
        return Theme.of(context).colorScheme.error;
      default:
        return AppTokens.accentBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppScaffold(title: 'Orçamentos', body: LoadingView());
    }
    if (_error != null) {
      return AppScaffold(
        title: 'Orçamentos',
        body: ErrorView(message: _error!, onRetry: _load),
      );
    }

    final filteredBudgets = _filteredBudgets();
    final inProgress =
        _budgets.where((budget) => budget['status'] == 'em_andamento').length;
    final approved =
        _budgets.where((budget) => budget['status'] == 'aprovado').length;
    final rejected =
        _budgets.where((budget) => budget['status'] == 'recusado').length;

    return AppScaffold(
      title: 'Orçamentos',
      subtitle: 'Pipeline comercial vinculado às tarefas',
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            AppHeroBanner(
              title: 'Pipeline de orçamentos',
              subtitle: 'Andamento, conversão e propostas da operação comercial.',
              metrics: [
                AppHeroMetric(label: 'Ativos', value: '$inProgress'),
                AppHeroMetric(label: 'Aprovados', value: '$approved'),
                AppHeroMetric(label: 'Recusados', value: '$rejected'),
              ],
            ),
            const SizedBox(height: AppTokens.space5),
            AppSurface(
              child: BudgetForm(
                clients: _clients,
                products: _products,
                onSaved: _load,
              ),
            ),
            const SizedBox(height: AppTokens.space5),
            AppSearchField(
              controller: _searchController,
              hintText: 'Buscar por cliente, tarefa ou item',
              onChanged: (value) => setState(() => _searchQuery = value),
              trailing: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
            const SizedBox(height: AppTokens.space3),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in const <MapEntry<String?, String>>[
                  MapEntry(null, 'Todos'),
                  MapEntry('em_andamento', 'Em andamento'),
                  MapEntry('aprovado', 'Aprovado'),
                  MapEntry('recusado', 'Recusado'),
                ])
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: _statusFilter == entry.key,
                    onSelected: (_) => setState(() => _statusFilter = entry.key),
                  ),
              ],
            ),
            const SizedBox(height: AppTokens.space5),
            const AppSectionBlock(
              title: 'Propostas cadastradas',
              subtitle: 'Histórico, andamento e compartilhamento comercial.',
            ),
            const SizedBox(height: AppTokens.space4),
            if (_budgets.isEmpty)
              const EmptyStateCard(
                title: 'Nenhum orçamento cadastrado',
                subtitle: 'Crie a primeira proposta para começar o pipeline.',
              ),
            if (_budgets.isNotEmpty && filteredBudgets.isEmpty)
              const EmptyStateCard(
                title: 'Nenhum orçamento encontrado',
                subtitle: 'Os filtros atuais não retornaram propostas.',
              ),
            ...filteredBudgets.map((budget) {
              final clientName = budget['client_name'] ?? 'Sem cliente';
              final statusLabel = _formatStatus(budget['status']?.toString());
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Orçamento #${budget['id']}',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  clientName.toString(),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          AppStatusPill(
                            label: statusLabel,
                            color: _statusColor(budget['status']?.toString()),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                _editBudget(budget);
                              } else if (value == 'delete') {
                                _deleteBudget(budget['id'] as int);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(value: 'edit', child: Text('Editar')),
                              PopupMenuItem(value: 'delete', child: Text('Remover')),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Total ${formatCurrency(budget['total'] ?? 0)}',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      if (budget['task_title'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Tarefa: ${budget['task_title']}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 12),
                      ...(budget['items'] as List<dynamic>? ?? [])
                          .cast<Map<String, dynamic>>()
                          .take(3)
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      item['description']?.toString() ?? 'Item',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(formatCurrency(item['total'] ?? 0)),
                                ],
                              ),
                            ),
                          ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: () => _sendEmail(budget),
                            child: const Text('Enviar e-mail'),
                          ),
                          OutlinedButton(
                            onPressed: () => _shareReportLink(budget),
                            child: const Text('Compartilhar link'),
                          ),
                          OutlinedButton(
                            onPressed: () => _openReportLink(budget),
                            child: const Text('Abrir PDF'),
                          ),
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
