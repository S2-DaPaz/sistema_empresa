import 'package:flutter/material.dart';

import '../core/offline/offline_read_cache.dart';
import '../services/api_service.dart';
import '../utils/formatters.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/brand_logo.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';
import '../widgets/section_header.dart';

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
        _reports = recentReports.take(5).toList();
        _loading = false;
      });
      await _cache.writeJson(_cacheKey, payload);
    } catch (_) {
      final cached = await _cache.readMap(_cacheKey);
      if (cached != null) {
        final summary = Map<String, dynamic>.from(
          cached['summary'] as Map? ?? const {},
        );
        final metrics = Map<String, dynamic>.from(
          cached['metrics'] as Map? ?? const {},
        );
        final recentReports = List<dynamic>.from(
          cached['recentReports'] as List? ?? const [],
        );

        if (!mounted) {
          return;
        }

        setState(() {
          _summary = summary;
          _metrics = metrics;
          _reports = recentReports.take(5).toList();
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
        _error = 'Não foi possível carregar os dados do painel.';
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
      body: ListView(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const BrandLogo(height: 46),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RV TecnoCare',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Assistência técnica, relatórios e orçamentos',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _load,
                    tooltip: 'Atualizar painel',
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_offlineNotice != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off_outlined),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_offlineNotice!)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          const SectionHeader(
            title: 'Visão geral',
            subtitle: 'Atalhos rápidos para os módulos mais usados da operação.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ShortcutCard(
                title: 'Clientes',
                subtitle: 'Base de atendimento',
                value: _summary['clients'],
                icon: Icons.people_alt_outlined,
                onTap: () =>
                    widget.onOpenShortcut?.call(DashboardShortcut.clients),
              ),
              _ShortcutCard(
                title: 'Tarefas',
                subtitle: 'Fluxos em andamento',
                value: _summary['tasks'],
                icon: Icons.task_alt,
                onTap: () => widget.onOpenShortcut?.call(DashboardShortcut.tasks),
              ),
              _ShortcutCard(
                title: 'Produtos',
                subtitle: 'Itens para orçamento',
                value: _summary['products'],
                icon: Icons.inventory_2_outlined,
                onTap: () =>
                    widget.onOpenShortcut?.call(DashboardShortcut.products),
              ),
              _ShortcutCard(
                title: 'Orçamentos',
                subtitle: 'Propostas vinculadas',
                value: _summary['budgets'],
                icon: Icons.receipt_long,
                onTap: () =>
                    widget.onOpenShortcut?.call(DashboardShortcut.budgets),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const SectionHeader(
            title: 'Métricas operacionais',
            subtitle: 'Indicadores para priorização diária da equipe.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricCard(
                title: 'Tarefas vencidas',
                subtitle: 'Demandas fora do prazo',
                value: '${_metrics['overdueTasks'] ?? 0}',
                icon: Icons.warning_amber_rounded,
              ),
              _MetricCard(
                title: 'Orçamentos pendentes',
                subtitle: 'Ainda aguardando decisão',
                value: '${_metrics['pendingBudgets'] ?? 0}',
                icon: Icons.pending_actions_outlined,
              ),
              _MetricCard(
                title: 'Conversão',
                subtitle: 'Aprovados sobre o total',
                value: _formatPercent(_metrics['budgetConversionRate']),
                icon: Icons.trending_up,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Técnico com maior carga',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    busiestTechnician.isEmpty
                        ? 'Nenhuma carga ativa foi identificada no momento.'
                        : '${busiestTechnician['name']} lidera a fila atual com '
                            '${busiestTechnician['taskCount'] ?? 0} tarefa(s) abertas.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeader(
            title: 'Últimos relatórios',
            subtitle: 'Acompanhe os registros mais recentes sem sair do painel.',
          ),
          const SizedBox(height: 12),
          if (_reports.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Nenhum relatório recente foi encontrado.'),
              ),
            ),
          ..._reports.map((report) {
            final map = Map<String, dynamic>.from(report as Map);
            final title = map['title'] ?? map['template_name'] ?? 'Relatório';
            final created = map['created_at']?.toString() ?? '';

            return Card(
              child: ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(title.toString()),
                subtitle: Text(
                  '${map['client_name'] ?? 'Sem cliente'} • ${formatDate(created)}',
                ),
                trailing: Chip(
                  label: Text(map['status']?.toString() ?? 'rascunho'),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final dynamic value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 164,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Chip(label: Text('${value ?? 0}')),
                const SizedBox(height: 10),
                Text(
                  'Toque para abrir',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 164,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(height: 10),
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              Text(subtitle, style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
              Chip(label: Text(value)),
            ],
          ),
        ),
      ),
    );
  }
}
