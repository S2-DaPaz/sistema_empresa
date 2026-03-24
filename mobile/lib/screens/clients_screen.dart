import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_assets.dart';
import '../utils/contact_utils.dart';
import '../utils/entity_config.dart';
import '../utils/field_config.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_search_field.dart';
import '../widgets/client_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';
import 'client_detail_screen.dart';
import 'entity_form_screen.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _budgets = [];
  String _search = '';

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
      final clients = await _api.get('/clients') as List<dynamic>;
      final tasks = await _api.get('/tasks') as List<dynamic>;
      final budgets = await _api.get('/budgets') as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _clients = List<Map<String, dynamic>>.from(clients);
        _tasks = List<Map<String, dynamic>>.from(tasks);
        _budgets = List<Map<String, dynamic>>.from(budgets);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openClientForm([Map<String, dynamic>? client]) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EntityFormScreen(
          config: _clientConfig,
          item: client,
        ),
      ),
    );
    if (updated == true && mounted) {
      await _load();
    }
  }

  List<Map<String, dynamic>> get _filteredClients {
    final query = _search.trim().toLowerCase();
    if (query.isEmpty) return _clients;
    return _clients.where((client) {
      final text = [
        client['name'],
        client['contact'],
        client['address'],
        client['cnpj'],
      ].map((value) => value?.toString() ?? '').join(' ').toLowerCase();
      return text.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppScaffold(
        title: 'Clientes',
        showAppBar: false,
        body: LoadingView(message: 'Carregando clientes...'),
      );
    }

    if (_error != null) {
      return AppScaffold(
        title: 'Clientes',
        showAppBar: false,
        body: ErrorView(message: _error!, onRetry: _load),
      );
    }

    final filteredClients = _filteredClients;

    return AppScaffold(
      title: 'Clientes',
      showAppBar: false,
      padding: EdgeInsets.zero,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Clientes',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _openClientForm(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Novo'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppSearchField(
              controller: _searchController,
              hintText: 'Buscar clientes...',
              onChanged: (value) => setState(() => _search = value),
            ),
            const SizedBox(height: 20),
            if (filteredClients.isEmpty)
              const EmptyState(
                title: 'Nenhum cliente encontrado',
                message: 'Cadastre um cliente para começar a operar.',
                icon: Icons.people_outline_rounded,
                illustrationAsset: AppAssets.emptyClients,
              )
            else
              ...filteredClients.map((client) {
                final clientId = client['id'];
                final taskCount = _tasks
                    .where((task) => task['client_id'] == clientId)
                    .length;
                final budgetCount = _budgets
                    .where((budget) => budget['client_id'] == clientId)
                    .length;
                final email = extractEmail(client['contact']?.toString());
                final phone = extractPhone(client['contact']?.toString());
                final metrics = <String>[
                  if (taskCount > 0) '$taskCount tarefas',
                  if (budgetCount > 0) '$budgetCount orçamentos',
                  if (taskCount == 0 && budgetCount == 0) 'Sem vínculos',
                ];

                return ClientCard(
                  name: client['name']?.toString() ?? 'Cliente',
                  email: email,
                  phone: phone,
                  metrics: metrics,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ClientDetailScreen(client: client),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

final EntityConfig _clientConfig = EntityConfig(
  title: 'Cliente',
  endpoint: '/clients',
  primaryField: 'name',
  fields: [
    FieldConfig(name: 'name', label: 'Nome', type: FieldType.text),
    FieldConfig(name: 'cnpj', label: 'CPF/CNPJ', type: FieldType.text),
    FieldConfig(name: 'address', label: 'Endereço', type: FieldType.textarea),
    FieldConfig(name: 'contact', label: 'Contato', type: FieldType.text),
  ],
);
