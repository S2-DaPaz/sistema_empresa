import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/offline_cache_service.dart';
import '../services/permissions.dart';
import '../theme/app_assets.dart';
import '../utils/contact_utils.dart';
import '../utils/entity_config.dart';
import '../utils/field_config.dart';
import '../widgets/access_restricted_state.dart';
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
  static const String _chaveCache = 'offline_cache_clients_list';

  final ApiService _api = ApiService();
  final TextEditingController _controladorBusca = TextEditingController();

  bool _carregando = true;
  String? _erro;
  List<Map<String, dynamic>> _clientes = [];
  List<Map<String, dynamic>> _tarefas = [];
  List<Map<String, dynamic>> _orcamentos = [];
  String _busca = '';
  bool get _canViewData => Permissions.canViewModuleData(AppModule.clients);
  bool get _canManage => Permissions.canManageModule(AppModule.clients);
  bool get _isDemoMode => AuthService.instance.isVisitor;

  @override
  void initState() {
    super.initState();
    if (!_canViewData) {
      _carregando = false;
      return;
    }
    if (!_isDemoMode) {
      _carregarDoCache();
    }
    _load();
  }

  @override
  void dispose() {
    _controladorBusca.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final hadClients = _clientes.isNotEmpty;
    setState(() {
      _carregando = !hadClients;
      _erro = null;
    });
    try {
      final clients = await _api.get('/clients') as List<dynamic>;
      final nextClients = List<Map<String, dynamic>>.from(clients);
      if (!_isDemoMode) {
        await OfflineCacheService.writeList(_chaveCache, nextClients);
      }
      if (!mounted) return;
      setState(() {
        _clientes = nextClients;
        _tarefas = <Map<String, dynamic>>[];
        _orcamentos = <Map<String, dynamic>>[];
        _carregando = false;
      });
      unawaited(_carregarMetricasCliente());
    } catch (error) {
      final cached = hadClients || _isDemoMode
          ? _clientes
          : await OfflineCacheService.readList(_chaveCache);
      if (!mounted) return;
      if (cached != null && cached.isNotEmpty) {
        setState(() {
          _clientes = cached;
          _carregando = false;
        });
        _exibirAvisoDesatualizado();
        unawaited(_carregarMetricasCliente());
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
    if (!mounted || cached == null || cached.isEmpty || _clientes.isNotEmpty) {
      return;
    }
    setState(() {
      _clientes = cached;
      _carregando = false;
      _erro = null;
    });
  }

  Future<void> _carregarMetricasCliente() async {
    try {
      final results = await Future.wait([
        _api.get('/tasks'),
        _api.get('/budgets'),
      ]);
      if (!mounted) return;
      setState(() {
        _tarefas = List<Map<String, dynamic>>.from(
          (results[0] as List?) ?? const [],
        );
        _orcamentos = List<Map<String, dynamic>>.from(
          (results[1] as List?) ?? const [],
        );
      });
    } catch (_) {
      // Metrics are complementary. Keep the list available even if they fail.
    }
  }

  void _exibirAvisoDesatualizado() {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      const SnackBar(
        content: Text(
          'Clientes exibidos com dados salvos enquanto a API responde.',
        ),
      ),
    );
  }

  Future<void> _abrirFormularioCliente([Map<String, dynamic>? client]) async {
    if (!_canManage) return;
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EntityFormScreen(
          config: _configCliente,
          item: client,
        ),
      ),
    );
    if (updated == true && mounted) {
      await _load();
    }
  }

  List<Map<String, dynamic>> get _clientesFiltrados {
    final query = _busca.trim().toLowerCase();
    if (query.isEmpty) return _clientes;
    return _clientes.where((client) {
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
    if (!_canViewData) {
      return const AppScaffold(
        title: 'Clientes',
        showAppBar: false,
        body: AccessRestrictedState(
          title: 'Clientes protegidos para este perfil',
          message:
              'O perfil visitante pode navegar até esta área, mas não pode visualizar cadastros nem métricas de clientes.',
        ),
      );
    }

    if (_carregando) {
      return const AppScaffold(
        title: 'Clientes',
        showAppBar: false,
        body: LoadingView(message: 'Carregando clientes...'),
      );
    }

    if (_erro != null) {
      return AppScaffold(
        title: 'Clientes',
        showAppBar: false,
        body: ErrorView(message: _erro!, onRetry: _load),
      );
    }

    final filteredClients = _clientesFiltrados;

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
                if (_canManage)
                  ElevatedButton.icon(
                    onPressed: () => _abrirFormularioCliente(),
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
              hintText: 'Buscar clientes...',
              onChanged: (value) => setState(() => _busca = value),
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
                final taskCount = _tarefas
                    .where((task) => task['client_id'] == clientId)
                    .length;
                final budgetCount = _orcamentos
                    .where((budget) => budget['client_id'] == clientId)
                    .length;
                final email = extrairEmail(client['contact']?.toString());
                final phone = extrairTelefone(client['contact']?.toString());
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

final ConfiguracaoEntidade _configCliente = ConfiguracaoEntidade(
  title: 'Cliente',
  endpoint: '/clients',
  primaryField: 'name',
  fields: [
    ConfiguracaoCampo(name: 'name', label: 'Nome', type: TipoCampo.text),
    ConfiguracaoCampo(name: 'cnpj', label: 'CPF/CNPJ', type: TipoCampo.text),
    ConfiguracaoCampo(name: 'address', label: 'Endereço', type: TipoCampo.textarea),
    ConfiguracaoCampo(name: 'contact', label: 'Contato', type: TipoCampo.text),
  ],
);
