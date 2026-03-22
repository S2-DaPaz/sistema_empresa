import 'package:flutter/material.dart';

import '../core/offline/offline_read_cache.dart';
import '../services/api_service.dart';
import '../theme/app_tokens.dart';
import '../utils/formatters.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_ui.dart';
import '../widgets/brand_logo.dart';
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

  bool _loading = true;
  String? _error;
  String? _offlineNotice;
  Map<String, dynamic> _summary = {};
  Map<String, dynamic> _metrics = {};
  List<dynamic> _reports = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _offlineNotice = null;
    });

    try {
      final payload = Map<String, dynamic>.from(await _api.get('/summary') as Map);
      final summary = Map<String, dynamic>.from(
        payload['summary'] as Map? ?? const {},
      );
      final metrics = Map<String, dynamic>.from(
        payload['metrics'] as Map? ?? const {},
      );
      final recentReports = List<dynamic>.from(
        payload['recentReports'] as List? ?? const [],
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _summary = summary;
        _metrics = metrics;
        _reports = recentReports.take(4).toList();
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
          _reports = List<dynamic>.from(
            cached['recentReports'] as List? ?? const [],
          ).take(4).toList();
          _offlineNotice =
              'Sem conexão. Exibindo a última atualização salva neste aparelho.';
          _loading = false;
        });
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _error = 'Não foi possível carregar o painel operacional.';
        _loading = false;
      });
    }
  }

  String _formatPercent(dynamic value) {
    final numeric = double.tryParse(value?.toString() ?? '') ?? 0;
    return numeric % 1 == 0
        ? '${numeric.toStringAsFixed(0)}%'
        : '${numeric.toStringAsFixed(1)}%';
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

    final busiestTechnician =
        Map<String, dynamic>.from(_metrics['busiestTechnician'] as Map? ?? const {});

    return AppScaffold(
      title: 'Painel',
      subtitle: 'Centro operacional da equipe',
      actions: [
        IconButton(
          tooltip: 'Atualizar painel',
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            AppHeroBanner(
              title: 'Painel da operação',
              subtitle:
                  'Acompanhe pendências, acessos rápidos e atividade recente sem perder contexto.',
              trailing: const CircleAvatar(
                radius: 22,
                backgroundColor: Color(0x1FFFFFFF),
                child: BrandLogo(height: 26),
              ),
              metrics: [
                AppHeroMetric(
                  label: 'Tarefas abertas',
                  value: '${_summary['tasks'] ?? 0}',
                ),
                AppHeroMetric(
                  label: 'Pendentes',
                  value: '${_metrics['pendingBudgets'] ?? 0}',
                ),
                AppHeroMetric(
                  label: 'Conversão',
                  value: _formatPercent(_metrics['budgetConversionRate']),
                ),
              ],
            ),
            if (_offlineNotice != null) ...[
              const SizedBox(height: AppTokens.space4),
              AppMessageBanner(
                message: _offlineNotice!,
                icon: Icons.cloud_off_outlined,
                toneColor: Theme.of(context).colorScheme.secondary,
              ),
            ],
            const SizedBox(height: AppTokens.space5),
            const AppSectionBlock(
              title: 'Visão geral',
              subtitle: 'Números principais desta operação.',
            ),
            const SizedBox(height: AppTokens.space4),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.04,
              children: [
                AppMetricTile(
                  title: 'Tarefas vencidas',
                  value: '${_metrics['overdueTasks'] ?? 0}',
                  subtitle: 'Demandas fora do prazo',
                  emphasis: true,
                ),
                AppMetricTile(
                  title: 'Orçamentos',
                  value: '${_metrics['pendingBudgets'] ?? 0}',
                  subtitle: 'Aguardando decisão',
                ),
                AppMetricTile(
                  title: 'Clientes ativos',
                  value: '${_summary['clients'] ?? 0}',
                  subtitle: 'Carteira atual',
                ),
                AppMetricTile(
                  title: 'Técnico líder',
                  value: busiestTechnician['name']?.toString() ?? '—',
                  subtitle:
                      '${busiestTechnician['taskCount'] ?? 0} em andamento',
                ),
              ],
            ),
            const SizedBox(height: AppTokens.space5),
            const AppSectionBlock(
              title: 'Atalhos rápidos',
              subtitle: 'Tudo que move a rotina de campo e escritório.',
            ),
            const SizedBox(height: AppTokens.space4),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.02,
              children: [
                AppQuickActionCard(
                  title: 'Clientes',
                  subtitle: 'Base de atendimento',
                  icon: Icons.people_alt_outlined,
                  value: '${_summary['clients'] ?? 0} abrir',
                  color: AppTokens.supportTeal,
                  onTap: () =>
                      widget.onOpenShortcut?.call(DashboardShortcut.clients),
                ),
                AppQuickActionCard(
                  title: 'Tarefas',
                  subtitle: 'Fila ativa',
                  icon: Icons.task_alt_outlined,
                  value: '${_summary['tasks'] ?? 0} abrir',
                  color: AppTokens.accentBlue,
                  onTap: () =>
                      widget.onOpenShortcut?.call(DashboardShortcut.tasks),
                ),
                AppQuickActionCard(
                  title: 'Produtos',
                  subtitle: 'Itens de orçamento',
                  icon: Icons.inventory_2_outlined,
                  value: '${_summary['products'] ?? 0} abrir',
                  color: AppTokens.primaryCyan,
                  onTap: () =>
                      widget.onOpenShortcut?.call(DashboardShortcut.products),
                ),
                AppQuickActionCard(
                  title: 'Orçamentos',
                  subtitle: 'Pipeline comercial',
                  icon: Icons.receipt_long_outlined,
                  value: '${_summary['budgets'] ?? 0} abrir',
                  color: AppTokens.accentBlue,
                  onTap: () =>
                      widget.onOpenShortcut?.call(DashboardShortcut.budgets),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.space5),
            const AppSectionBlock(
              title: 'Últimos relatórios',
              subtitle: 'Atividade recente da equipe técnica.',
            ),
            const SizedBox(height: AppTokens.space4),
            if (_reports.isEmpty)
              const EmptyStateCard(
                title: 'Nenhum relatório recente',
                subtitle: 'Os relatórios publicados e atualizados aparecem aqui.',
              ),
            ..._reports.map((report) {
              final map = Map<String, dynamic>.from(report as Map);
              final title = map['title'] ?? map['template_name'] ?? 'Relatório';
              final created = map['created_at']?.toString() ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppSurface(
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppTokens.accentBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.description_outlined,
                          color: AppTokens.accentBlue,
                        ),
                      ),
                      const SizedBox(width: AppTokens.space4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title.toString(),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${map['client_name'] ?? 'Sem cliente'} • ${formatDate(created)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      AppStatusPill(
                        label: map['status']?.toString() ?? 'rascunho',
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
