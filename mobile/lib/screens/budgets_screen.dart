import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../utils/budget_email.dart';
import '../utils/formatters.dart';
import '../widgets/app_scaffold.dart';
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
      final budgets = await _api.get('/budgets?includeItems=1') as List<dynamic>;
      final clients = await _api.get('/clients') as List<dynamic>;
      final products = await _api.get('/products') as List<dynamic>;
      setState(() {
        _budgets = budgets.cast<Map<String, dynamic>>();
        _clients = clients.cast<Map<String, dynamic>>();
        _products = products.cast<Map<String, dynamic>>();
      });
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      setState(() => _loading = false);
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
    } catch (error) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
      return null;
    }
  }

  Future<void> _shareReportLink(Map<String, dynamic> budget) async {
    final url = await _getPublicLink(budget);
    if (url == null || url.isEmpty) return;
    await Share.share(
      url,
      subject: 'Relatório da tarefa #${budget['task_id']}',
    );
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

  Future<void> _openFilters() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Filtrar por status'),
            ),
            ListTile(
              title: const Text('Todos'),
              leading: const Icon(Icons.clear_all),
              onTap: () => Navigator.pop(context, 'todos'),
            ),
            ListTile(
              title: const Text('Rascunho'),
              onTap: () => Navigator.pop(context, 'rascunho'),
            ),
            ListTile(
              title: const Text('Enviado'),
              onTap: () => Navigator.pop(context, 'enviado'),
            ),
            ListTile(
              title: const Text('Aprovado'),
              onTap: () => Navigator.pop(context, 'aprovado'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || selected == null) return;
    setState(() => _statusFilter = selected == 'todos' ? null : selected);
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
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remover')),
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

    return AppScaffold(
      title: 'Orçamentos',
      body: ListView(
        children: [
          BudgetForm(
            clients: _clients,
            products: _products,
            onSaved: _load,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar orçamentos',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          ),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: _openFilters,
                  child: const Icon(Icons.tune),
                ),
              ),
            ],
          ),
          if (_searchQuery.isNotEmpty || _statusFilter != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (_searchQuery.isNotEmpty)
                  Chip(
                    label: Text('Busca: $_searchQuery'),
                    onDeleted: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  ),
                if (_statusFilter != null)
                  Chip(
                    label: Text('Status: $_statusFilter'),
                    onDeleted: () => setState(() => _statusFilter = null),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          if (_budgets.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Nenhum orçamento cadastrado.'),
              ),
            ),
          if (_budgets.isNotEmpty && filteredBudgets.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Nenhum orçamento encontrado com os filtros atuais.'),
              ),
            ),
          ...filteredBudgets.map((budget) {
            final clientName = budget['client_name'] ?? 'Sem cliente';
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Orçamento #${budget['id']}', style: Theme.of(context).textTheme.titleSmall),
                        Row(
                          children: [
                            Chip(label: Text(budget['status']?.toString() ?? 'rascunho')),
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
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Cliente: $clientName | Total: ${formatCurrency(budget['total'] ?? 0)}'),
                    if (budget['task_title'] != null)
                      Text('Tarefa: ${budget['task_title']}'),
                    if (budget['report_title'] != null)
                      Text('Relatório: ${budget['report_title']}'),
                    const SizedBox(height: 8),
                    ...(budget['items'] as List<dynamic>? ?? [])
                        .cast<Map<String, dynamic>>()
                        .map((item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text(item['description']?.toString() ?? 'Item')),
                                  Text(formatCurrency(item['total'] ?? 0)),
                                ],
                              ),
                            )),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
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
        ],
      ),
    );
  }
}
