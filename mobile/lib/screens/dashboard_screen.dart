import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/offline_cache_service.dart';
import '../theme/app_assets.dart';
import '../theme/app_tokens.dart';
import '../utils/contact_utils.dart';
import '../utils/formatters.dart';
import '../utils/label_mappers.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/brand_logo.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';
import '../widgets/metric_card.dart';
import '../widgets/section_header.dart';
import '../widgets/status_chip.dart';
import '../widgets/task_card.dart';
import 'home_shell.dart';

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
  static const String _cacheKey = 'offline_cache_dashboard_summary';

  final ApiService _api = ApiService();

  bool _loading = true;
  String? _error;
  Map<String, dynamic> _summary = {};
  Map<String, dynamic> _taskMetrics = {};
  Map<String, dynamic> _budgetMetrics = {};
  List<Map<String, dynamic>> _recentTasks = [];
  List<Map<String, dynamic>> _recentBudgets = [];
  int _notificationCount = 0;

  @override
  void initState() {
    super.initState();
    _primeFromCache();
    _load();
  }

  bool get _hasDashboardData =>
      _summary.isNotEmpty ||
      _taskMetrics.isNotEmpty ||
      _budgetMetrics.isNotEmpty ||
      _recentTasks.isNotEmpty ||
      _recentBudgets.isNotEmpty;

  Future<void> _primeFromCache() async {
    final cached = await OfflineCacheService.readMap(_cacheKey);
    if (!mounted || cached == null || _hasDashboardData) return;
    _applyPayload(cached);
  }

  Future<void> _load() async {
    final hadData = _hasDashboardData;
    if (mounted) {
      setState(() {
        _loading = !hadData;
        _error = null;
      });
    }

    try {
      final payload = Map<String, dynamic>.from(
        await _api.get('/summary') as Map,
      );
      await OfflineCacheService.writeMap(_cacheKey, payload);
      if (!mounted) return;
      _applyPayload(payload);
    } catch (error) {
      final cached =
          hadData ? null : await OfflineCacheService.readMap(_cacheKey);
      if (!mounted) return;
      if (cached != null) {
        _applyPayload(cached);
        _showBackgroundRefreshWarning();
        return;
      }
      if (hadData) {
        setState(() {
          _loading = false;
        });
        _showBackgroundRefreshWarning();
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _applyPayload(Map<String, dynamic> payload) {
    final normalized = _normalizePayload(payload);
    setState(() {
      _summary = normalized['summary'] as Map<String, dynamic>;
      _taskMetrics = normalized['taskMetrics'] as Map<String, dynamic>;
      _budgetMetrics = normalized['budgetMetrics'] as Map<String, dynamic>;
      _recentTasks = normalized['recentTasks'] as List<Map<String, dynamic>>;
      _recentBudgets =
          normalized['recentBudgets'] as List<Map<String, dynamic>>;
      _notificationCount = normalized['notificationCount'] as int;
      _loading = false;
      _error = null;
    });
  }

  Map<String, dynamic> _normalizePayload(Map<String, dynamic> payload) {
    final summary = Map<String, dynamic>.from(
      payload['summary'] as Map? ?? const {},
    );
    final legacyMetrics = Map<String, dynamic>.from(
      payload['metrics'] as Map? ?? const {},
    );
    final taskMetrics = Map<String, dynamic>.from(
      payload['taskMetrics'] as Map? ?? const {},
    );
    final budgetMetrics = Map<String, dynamic>.from(
      payload['budgetMetrics'] as Map? ?? const {},
    );

    taskMetrics.putIfAbsent(
        'total', () => (summary['tasks'] as num?)?.toInt() ?? 0);
    taskMetrics.putIfAbsent('open', () => 0);
    taskMetrics.putIfAbsent('inProgress', () => 0);
    taskMetrics.putIfAbsent('completed', () => 0);
    taskMetrics.putIfAbsent('today', () => 0);

    budgetMetrics.putIfAbsent(
      'total',
      () => (summary['budgets'] as num?)?.toInt() ?? 0,
    );
    budgetMetrics.putIfAbsent(
      'inProgress',
      () => (legacyMetrics['pendingBudgets'] as num?)?.toInt() ?? 0,
    );
    budgetMetrics.putIfAbsent('approved', () => 0);
    budgetMetrics.putIfAbsent('rejected', () => 0);

    final recentTasks = List<Map<String, dynamic>>.from(
      payload['recentTasks'] as List? ?? const [],
    );
    final recentBudgets = List<Map<String, dynamic>>.from(
      payload['recentBudgets'] as List? ?? const [],
    );

    final fallbackRecentTasks = recentTasks.isNotEmpty
        ? recentTasks
        : _legacyReportsAsRecentTasks(
            payload['recentReports'] as List? ?? const []);

    final notificationCount = (payload['notificationCount'] as num?)?.toInt() ??
        (taskMetrics['open'] as num?)?.toInt() ??
        0;

    return {
      'summary': summary,
      'taskMetrics': taskMetrics,
      'budgetMetrics': budgetMetrics,
      'recentTasks': fallbackRecentTasks,
      'recentBudgets': recentBudgets,
      'notificationCount': notificationCount,
    };
  }

  List<Map<String, dynamic>> _legacyReportsAsRecentTasks(
      List<dynamic> reports) {
    return reports
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(
          (item) => <String, dynamic>{
            'id': item['id'],
            'title': item['task_title']?.toString().isNotEmpty == true
                ? item['task_title']
                : (item['title']?.toString().isNotEmpty == true
                    ? item['title']
                    : 'Atividade recente'),
            'status':
                _legacyReportStatusToTaskStatus(item['status']?.toString()),
            'priority': 'media',
            'client_name': item['client_name'],
            'client_address': '',
            'created_at': item['created_at'],
          },
        )
        .toList();
  }

  String _legacyReportStatusToTaskStatus(String? status) {
    switch (status) {
      case 'enviado':
        return 'em_andamento';
      case 'aprovado':
      case 'concluido':
      case 'concluida':
        return 'concluida';
      default:
        return 'aberta';
    }
  }

  void _showBackgroundRefreshWarning() {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      const SnackBar(
        content: Text(
          'Painel exibido com dados salvos. A atualização do servidor falhou agora.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppScaffold(
        title: 'Início',
        showAppBar: false,
        body: LoadingView(message: 'Preparando o painel...'),
      );
    }

    if (_error != null) {
      return AppScaffold(
        title: 'Início',
        showAppBar: false,
        body: ErrorView(
          message: _error!,
          onRetry: _load,
        ),
      );
    }

    final theme = Theme.of(context);
    final userName = AuthService.instance.user?['name']?.toString();
    final greetingName = firstNameOf(userName);
    final openTasks = (_taskMetrics['open'] as num?)?.toInt() ?? 0;
    final inProgressTasks = (_taskMetrics['inProgress'] as num?)?.toInt() ?? 0;
    final tasksToday = (_taskMetrics['today'] as num?)?.toInt() ?? 0;
    final budgetsInProgress =
        (_budgetMetrics['inProgress'] as num?)?.toInt() ?? 0;
    final approvedBudgets = (_budgetMetrics['approved'] as num?)?.toInt() ?? 0;

    return AppScaffold(
      title: 'Início',
      showAppBar: false,
      padding: EdgeInsets.zero,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            120,
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.24),
                    blurRadius: 32,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const BrandLogo(
                              height: 26,
                              color: Colors.white,
                              monogram: true,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'Olá, $greetingName',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              _heroSubtitle(
                                openTasks: openTasks,
                                inProgressTasks: inProgressTasks,
                                tasksToday: tasksToday,
                              ),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.84),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _NotificationButton(
                        count: _notificationCount,
                        onTap: () => _openNotificationCenter(
                          openTasks: openTasks,
                          inProgressTasks: inProgressTasks,
                          budgetsInProgress: budgetsInProgress,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      _HeroPill(
                        label: '$tasksToday para hoje',
                        icon: Icons.calendar_month_rounded,
                      ),
                      _HeroPill(
                        label: '$budgetsInProgress em proposta',
                        icon: Icons.receipt_long_rounded,
                      ),
                      _HeroPill(
                        label: formatDate(DateTime.now().toIso8601String()),
                        icon: Icons.schedule_rounded,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionHeader(
              title: 'Atalhos rápidos',
              subtitle: 'Acesse os fluxos mais usados do dia',
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 132,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _ShortcutCard(
                    title: 'Tarefas',
                    subtitle: '$openTasks abertas',
                    icon: Icons.task_alt_rounded,
                    onTap: () =>
                        widget.onOpenShortcut?.call(DashboardShortcut.tasks),
                  ),
                  _ShortcutCard(
                    title: 'Clientes',
                    subtitle: '${_summary['clients'] ?? 0} ativos',
                    icon: Icons.people_alt_rounded,
                    accentColor: AppColors.secondary,
                    onTap: () =>
                        widget.onOpenShortcut?.call(DashboardShortcut.clients),
                  ),
                  _ShortcutCard(
                    title: 'Orçamentos',
                    subtitle: '$approvedBudgets aprovados',
                    icon: Icons.receipt_long_rounded,
                    accentColor: AppColors.info,
                    onTap: () =>
                        widget.onOpenShortcut?.call(DashboardShortcut.budgets),
                  ),
                  _ShortcutCard(
                    title: 'Mais',
                    subtitle: 'Admin e apoio',
                    icon: Icons.grid_view_rounded,
                    accentColor: AppColors.warning,
                    onTap: () =>
                        widget.onOpenShortcut?.call(DashboardShortcut.more),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionHeader(
              title: 'Painel operacional',
              subtitle: 'Status real de tarefas, clientes e propostas',
            ),
            const SizedBox(height: AppSpacing.sm),
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: AppSpacing.sm,
                mainAxisSpacing: AppSpacing.sm,
                mainAxisExtent: 166,
              ),
              children: [
                MetricCard(
                  title: 'Tarefas',
                  value: '${_taskMetrics['total'] ?? _summary['tasks'] ?? 0}',
                  subtitle: '$openTasks abertas',
                  icon: Icons.task_alt_rounded,
                  onTap: () =>
                      widget.onOpenShortcut?.call(DashboardShortcut.tasks),
                ),
                MetricCard(
                  title: 'Em andamento',
                  value: '$inProgressTasks',
                  subtitle: 'Execução em campo',
                  icon: Icons.timelapse_rounded,
                  accentColor: AppColors.warning,
                  onTap: () =>
                      widget.onOpenShortcut?.call(DashboardShortcut.tasks),
                ),
                MetricCard(
                  title: 'Orçamentos',
                  value:
                      '${_budgetMetrics['total'] ?? _summary['budgets'] ?? 0}',
                  subtitle: '$budgetsInProgress aguardando retorno',
                  icon: Icons.request_quote_rounded,
                  accentColor: AppColors.info,
                  onTap: () =>
                      widget.onOpenShortcut?.call(DashboardShortcut.budgets),
                ),
                MetricCard(
                  title: 'Clientes',
                  value: '${_summary['clients'] ?? 0}',
                  subtitle: 'Base comercial ativa',
                  icon: Icons.people_alt_rounded,
                  accentColor: AppColors.success,
                  onTap: () =>
                      widget.onOpenShortcut?.call(DashboardShortcut.clients),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            SectionHeader(
              title: 'Tarefas recentes',
              subtitle: 'Últimas movimentações de atendimento',
              actionLabel: 'Ver tudo',
              onAction: () =>
                  widget.onOpenShortcut?.call(DashboardShortcut.tasks),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_recentTasks.isEmpty)
              const EmptyState(
                title: 'Nenhuma tarefa recente',
                message:
                    'Assim que novas tarefas forem criadas elas aparecem aqui.',
                icon: Icons.task_alt_outlined,
                illustrationAsset: AppAssets.emptyTasks,
              )
            else
              ..._recentTasks.take(3).map((task) {
                final title = task['title']?.toString() ?? 'Tarefa';
                final clientName =
                    task['client_name']?.toString() ?? 'Sem cliente';
                final address = task['client_address']?.toString() ?? '';
                return TaskCard(
                  title: title,
                  clientName: clientName,
                  location: address,
                  statusLabel: taskStatusLabel(task['status']?.toString()),
                  priorityLabel:
                      taskPriorityLabel(task['priority']?.toString()),
                  codeLabel: '#${task['id'] ?? '--'}',
                  avatarName: clientName,
                  onTap: () =>
                      widget.onOpenShortcut?.call(DashboardShortcut.tasks),
                );
              }),
            const SizedBox(height: AppSpacing.xl),
            SectionHeader(
              title: 'Orçamentos recentes',
              subtitle: 'Propostas com retorno mais próximo',
              actionLabel: 'Abrir módulo',
              onAction: () =>
                  widget.onOpenShortcut?.call(DashboardShortcut.budgets),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_recentBudgets.isEmpty)
              const EmptyState(
                title: 'Nenhum orçamento recente',
                message:
                    'As propostas criadas pela equipe aparecem aqui com status.',
                icon: Icons.receipt_long_outlined,
                illustrationAsset: AppAssets.emptyBudgets,
              )
            else
              ..._recentBudgets.take(3).map(
                    (budget) => _RecentBudgetCard(
                      code: 'ORC #${budget['id'] ?? '--'}',
                      clientName:
                          budget['client_name']?.toString() ?? 'Sem cliente',
                      title: budget['task_title']?.toString().isNotEmpty == true
                          ? budget['task_title'].toString()
                          : 'Proposta comercial',
                      total: formatCurrency(budget['total'] as num? ?? 0),
                      createdAt: formatDate(budget['created_at']?.toString()),
                      status: budgetStatusLabel(budget['status']?.toString()),
                      onTap: () => widget.onOpenShortcut
                          ?.call(DashboardShortcut.budgets),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  String _heroSubtitle({
    required int openTasks,
    required int inProgressTasks,
    required int tasksToday,
  }) {
    if (openTasks == 0 && inProgressTasks == 0) {
      return 'Operação tranquila. Você não tem pendências críticas agora.';
    }
    if (tasksToday > 0) {
      return 'Você tem $tasksToday compromisso(s) para hoje e $openTasks frente(s) abertas.';
    }
    return 'Existem $inProgressTasks atendimento(s) em execução e $openTasks tarefa(s) abertas.';
  }


  Future<void> _openNotificationCenter({
    required int openTasks,
    required int inProgressTasks,
    required int budgetsInProgress,
  }) async {
    final alerts = <_DashboardAlertItem>[
      if (openTasks > 0)
        _DashboardAlertItem(
          title: '$openTasks tarefa(s) aberta(s)',
          subtitle: 'Pendências que precisam de andamento da equipe.',
          icon: Icons.task_alt_rounded,
          accentColor: AppColors.warning,
          onTap: () => widget.onOpenShortcut?.call(DashboardShortcut.tasks),
        ),
      if (inProgressTasks > 0)
        _DashboardAlertItem(
          title: '$inProgressTasks atendimento(s) em execução',
          subtitle: 'Serviços em campo com atividade em andamento.',
          icon: Icons.timelapse_rounded,
          accentColor: AppColors.primary,
          onTap: () => widget.onOpenShortcut?.call(DashboardShortcut.tasks),
        ),
      if (budgetsInProgress > 0)
        _DashboardAlertItem(
          title: '$budgetsInProgress orçamento(s) aguardando retorno',
          subtitle: 'Propostas que pedem acompanhamento comercial.',
          icon: Icons.receipt_long_rounded,
          accentColor: AppColors.info,
          onTap: () => widget.onOpenShortcut?.call(DashboardShortcut.budgets),
        ),
    ];

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notificações operacionais',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  alerts.isEmpty
                      ? 'Nenhum alerta crítico no momento.'
                      : 'Resumo rápido do que merece atenção agora.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                if (alerts.isEmpty)
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.notifications_off_outlined),
                    title: Text('Tudo em ordem'),
                    subtitle: Text(
                      'Quando surgirem pendências ou retornos pendentes, elas aparecem aqui.',
                    ),
                  )
                else
                  ...alerts.map(
                    (item) => Card(
                      child: ListTile(
                        onTap: () {
                          Navigator.of(context).pop();
                          item.onTap();
                        },
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: item.accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          alignment: Alignment.center,
                          child: Icon(item.icon, color: item.accentColor),
                        ),
                        title: Text(item.title),
                        subtitle: Text(item.subtitle),
                        trailing: const Icon(Icons.chevron_right_rounded),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({
    required this.count,
    required this.onTap,
  });

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Center(
                child: Icon(
                  Icons.notifications_none_rounded,
                  color: Colors.white,
                ),
              ),
              if (count > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      count > 9 ? '9+' : '$count',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                          ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardAlertItem {
  const _DashboardAlertItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.accentColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = accentColor ?? theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: SizedBox(
        width: 156,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, color: accent),
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentBudgetCard extends StatelessWidget {
  const _RecentBudgetCard({
    required this.code,
    required this.clientName,
    required this.title,
    required this.total,
    required this.createdAt,
    required this.status,
    required this.onTap,
  });

  final String code;
  final String clientName;
  final String title;
  final String total;
  final String createdAt;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      code,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  StatusChip(label: status, compact: true),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                clientName,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      createdAt,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    total,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
