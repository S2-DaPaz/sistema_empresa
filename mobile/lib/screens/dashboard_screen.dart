import 'package:flutter/material.dart';

import '../core/offline/offline_read_cache.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_tokens.dart';
import '../utils/formatters.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_ui.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';

enum DashboardShortcut { clients, tasks, products, budgets }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    this.onOpenShortcut,
  });

  final ValueChanged<DashboardShortcut>? onOpenShortcut;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _cacheKey = 'offline_cache_dashboard_summary';

  final ApiService _api = ApiService();
  final OfflineReadCache _cache = OfflineReadCache.instance;
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  String? _offlineNotice;
  String _searchQuery = '';
  Map<String, dynamic> _summary = {};
  Map<String, dynamic> _metrics = {};
  Map<String, dynamic> _notifications = {};
  List<Map<String, dynamic>> _recentActivity = [];

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
      _offlineNotice = null;
    });

    try {
      final payload =
          Map<String, dynamic>.from(await _api.get('/summary') as Map);
      final summary = Map<String, dynamic>.from(
        payload['summary'] as Map? ?? const {},
      );
      final metrics = Map<String, dynamic>.from(
        payload['metrics'] as Map? ?? const {},
      );
      final notifications = Map<String, dynamic>.from(
        payload['notifications'] as Map? ?? const {},
      );
      final recentActivity = List<Map<String, dynamic>>.from(
        (payload['recentActivity'] as List? ?? const []).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _summary = summary;
        _metrics = metrics;
        _notifications = notifications;
        _recentActivity = recentActivity;
        _loading = false;
      });
      await _cache.writeJson(_cacheKey, payload);
    } catch (_) {
      final cached = await _cache.readMap(_cacheKey);
      if (cached != null) {
        if (!mounted) {
          return;
        }

        setState(() {
          _summary = Map<String, dynamic>.from(
            cached['summary'] as Map? ?? const {},
          );
          _metrics = Map<String, dynamic>.from(
            cached['metrics'] as Map? ?? const {},
          );
          _notifications = Map<String, dynamic>.from(
            cached['notifications'] as Map? ?? const {},
          );
          _recentActivity = List<Map<String, dynamic>>.from(
            (cached['recentActivity'] as List? ?? const []).map(
              (item) => Map<String, dynamic>.from(item as Map),
            ),
          );
          _offlineNotice =
              'Sem conexao. Exibindo a ultima atualizacao salva neste aparelho.';
          _loading = false;
        });
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _error = 'Nao foi possivel carregar o painel operacional.';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredActivity {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return _recentActivity;
    }
    return _recentActivity.where((item) {
      final text = [
        item['title'],
        item['subtitle'],
        item['status'],
      ].join(' ').toLowerCase();
      return text.contains(query);
    }).toList();
  }

  Color _activityColor(String kind) {
    switch (kind) {
      case 'budget':
        return AppTokens.warning;
      case 'report':
        return AppTokens.supportTeal;
      default:
        return AppTokens.primaryBlue;
    }
  }

  IconData _activityIcon(String kind) {
    switch (kind) {
      case 'budget':
        return Icons.receipt_long_outlined;
      case 'report':
        return Icons.description_outlined;
      default:
        return Icons.task_alt_rounded;
    }
  }

  String _firstName() {
    final name =
        AuthService.instance.user?['name']?.toString().trim() ?? 'Equipe';
    final parts = name.split(RegExp(r'\s+')).where((item) => item.isNotEmpty);
    return parts.isEmpty ? 'Equipe' : parts.first;
  }

  String _roleLabel() {
    return AuthService.instance.user?['role_name']?.toString() ??
        AuthService.instance.user?['role']?.toString() ??
        'Operacao';
  }

  String _initials() {
    final name = AuthService.instance.user?['name']?.toString().trim() ?? 'RV';
    final parts =
        name.split(RegExp(r'\s+')).where((item) => item.isNotEmpty).toList();
    if (parts.isEmpty) return 'RV';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppScaffold(title: 'Painel', body: LoadingView());
    }

    if (_error != null) {
      return AppScaffold(
        title: 'Painel',
        body: ErrorView(message: _error!, onRetry: _load),
      );
    }

    final busiestTechnician = Map<String, dynamic>.from(
        _metrics['busiestTechnician'] as Map? ?? const {});
    final activity = _filteredActivity;

    return AppScaffold(
      title: 'Ola, ${_firstName()}!',
      subtitle: '${_roleLabel()} • Online',
      showLogo: false,
      actions: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              tooltip: 'Notificacoes',
              onPressed: _load,
              icon: const Icon(Icons.notifications_none_rounded),
            ),
            if ((_notifications['count'] ?? 0) > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: AppTokens.danger,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${_notifications['count']}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontSize: 9,
                        ),
                  ),
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: AppAvatarInitials(
            initials: _initials(),
            size: 40,
            backgroundColor: Colors.white.withValues(alpha: 0.16),
            foregroundColor: Colors.white,
          ),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            Row(
              children: [
                Expanded(
                  child: AppSearchField(
                    controller: _searchController,
                    hintText: 'Buscar atividade, cliente ou tarefa',
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
                ),
                const SizedBox(width: AppTokens.space3),
                AppIconButtonSurface(
                  icon: Icons.add_task_rounded,
                  onTap: () =>
                      widget.onOpenShortcut?.call(DashboardShortcut.tasks),
                ),
              ],
            ),
            if (_offlineNotice != null) ...[
              const SizedBox(height: AppTokens.space4),
              AppMessageBanner(
                message: _offlineNotice!,
                icon: Icons.cloud_off_outlined,
                toneColor: AppTokens.warning,
              ),
            ],
            const SizedBox(height: AppTokens.space5),
            const AppSectionBlock(
              title: 'Visao geral',
              subtitle: 'Leitura rapida da operacao e da fila tecnica.',
            ),
            const SizedBox(height: AppTokens.space4),
            SizedBox(
              height: 204,
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.05,
                children: [
                  AppMetricTile(
                    title: 'Tarefas abertas',
                    value: '${_metrics['openTasks'] ?? _summary['tasks'] ?? 0}',
                    subtitle: 'Demandas aguardando acao',
                    footer:
                        '${_metrics['todayTasks'] ?? 0} programadas para hoje',
                    icon: Icons.task_alt_outlined,
                    color: AppTokens.primaryBlue,
                    emphasis: true,
                  ),
                  AppMetricTile(
                    title: 'Em andamento',
                    value: '${_metrics['inProgressTasks'] ?? 0}',
                    subtitle: 'Equipe em campo e execucao',
                    footer: '${_metrics['activeSessions'] ?? 0} sessoes ativas',
                    icon: Icons.timelapse_rounded,
                    color: AppTokens.primaryCyan,
                  ),
                  AppMetricTile(
                    title: 'Orcamentos',
                    value: '${_metrics['pendingBudgets'] ?? 0}',
                    subtitle: 'Aguardando decisao',
                    footer:
                        '${_metrics['budgetConversionRate'] ?? 0}% de conversao',
                    icon: Icons.receipt_long_outlined,
                    color: AppTokens.warning,
                  ),
                  AppMetricTile(
                    title: 'Tecnico lider',
                    value: busiestTechnician['name']?.toString() ?? '—',
                    subtitle:
                        '${busiestTechnician['taskCount'] ?? 0} em andamento',
                    footer: '${_summary['clients'] ?? 0} clientes ativos',
                    icon: Icons.groups_rounded,
                    color: AppTokens.supportTeal,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTokens.space5),
            const AppSectionBlock(
              title: 'Acessos rapidos',
              subtitle: 'Atalhos diretos para a rotina operacional.',
            ),
            const SizedBox(height: AppTokens.space4),
            SizedBox(
              height: 174,
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.18,
                children: [
                  AppQuickActionCard(
                    title: 'Clientes',
                    subtitle: 'Carteira e historico',
                    icon: Icons.people_alt_outlined,
                    value: '${_summary['clients'] ?? 0} registros',
                    color: AppTokens.supportTeal,
                    onTap: () =>
                        widget.onOpenShortcut?.call(DashboardShortcut.clients),
                  ),
                  AppQuickActionCard(
                    title: 'Tarefas',
                    subtitle: 'Fila tecnica e agenda',
                    icon: Icons.task_alt_outlined,
                    value: '${_summary['tasks'] ?? 0} abertas',
                    color: AppTokens.primaryBlue,
                    onTap: () =>
                        widget.onOpenShortcut?.call(DashboardShortcut.tasks),
                  ),
                  AppQuickActionCard(
                    title: 'Orcamentos',
                    subtitle: 'Pipeline comercial',
                    icon: Icons.request_quote_outlined,
                    value: '${_summary['budgets'] ?? 0} propostas',
                    color: AppTokens.warning,
                    onTap: () =>
                        widget.onOpenShortcut?.call(DashboardShortcut.budgets),
                  ),
                  AppQuickActionCard(
                    title: 'Produtos',
                    subtitle: 'Catalogo e itens',
                    icon: Icons.inventory_2_outlined,
                    value: '${_summary['products'] ?? 0} cadastros',
                    color: AppTokens.primaryCyan,
                    onTap: () =>
                        widget.onOpenShortcut?.call(DashboardShortcut.products),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTokens.space5),
            const AppSectionBlock(
              title: 'Atividade recente',
              subtitle: 'O que mudou agora na operacao.',
            ),
            const SizedBox(height: AppTokens.space4),
            if (activity.isEmpty)
              const EmptyStateCard(
                title: 'Nenhuma atividade recente',
                subtitle:
                    'As proximas atualizacoes de tarefa, relatorio e orcamento aparecerao aqui.',
              ),
            ...activity.map((item) {
              final kind = item['kind']?.toString() ?? 'task';
              final color = _activityColor(kind);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppSurface(
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius:
                              BorderRadius.circular(AppTokens.radiusSm),
                        ),
                        child: Icon(_activityIcon(kind), color: color),
                      ),
                      const SizedBox(width: AppTokens.space4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['title']?.toString() ?? 'Atualizacao',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item['subtitle']?.toString() ?? 'Sem contexto',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          AppStatusPill(
                            label: item['status']?.toString() ?? 'ativo',
                            color: color,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            formatDate(item['createdAt']?.toString()),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }
}
