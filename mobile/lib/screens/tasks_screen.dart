import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/offline_cache_service.dart';
import '../services/permissions.dart';
import '../theme/app_assets.dart';
import '../theme/app_tokens.dart';
import '../utils/formatters.dart';
import '../utils/label_mappers.dart';
import '../widgets/access_restricted_state.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_search_field.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';
import '../widgets/status_chip.dart';
import '../widgets/task_card.dart';
import 'task_detail_screen.dart';

enum TaskViewMode { list, calendar }

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key, this.clientId, this.clientName});

  final int? clientId;
  final String? clientName;

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  static const String _chaveCache = 'offline_cache_tarefas_list';

  final ApiService _api = ApiService();
  final TextEditingController _controladorBusca = TextEditingController();

  bool _carregando = true;
  String? _erro;
  List<Map<String, dynamic>> _tarefas = [];
  TaskViewMode _modoVisualizacao = TaskViewMode.list;
  DateTime _mesCalendario = DateTime.now();
  String? _dataSelecionada;
  String _textoBusca = '';
  String? _filtroStatus;
  bool get _canViewData => Permissions.canViewModuleData(AppModule.tasks);
  bool get _canManage => Permissions.canManageModule(AppModule.tasks);

  @override
  void initState() {
    super.initState();
    if (!_canViewData) {
      _carregando = false;
      return;
    }
    _carregarDoCache();
    _carregar();
  }

  @override
  void dispose() {
    _controladorBusca.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    final hadTasks = _tarefas.isNotEmpty;
    setState(() {
      _carregando = !hadTasks;
      _erro = null;
    });
    try {
      final endpoint = widget.clientId != null
          ? '/tasks?clientId=${widget.clientId}'
          : '/tasks';
      final data = await _api.get(endpoint) as List<dynamic>;
      final nextTasks = List<Map<String, dynamic>>.from(data);
      await OfflineCacheService.writeList(_chaveCache, nextTasks);
      if (!mounted) return;
      setState(() {
        _tarefas = nextTasks;
        _carregando = false;
      });
    } catch (error) {
      final cached =
          hadTasks ? _tarefas : await OfflineCacheService.readList(_chaveCache);
      if (!mounted) return;
      if (cached != null && cached.isNotEmpty) {
        setState(() {
          _tarefas = cached;
          _carregando = false;
        });
        _mostrarAvisoDadosAntigos();
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
    if (!mounted || cached == null || cached.isEmpty || _tarefas.isNotEmpty) {
      return;
    }
    setState(() {
      _tarefas = cached;
      _carregando = false;
      _erro = null;
    });
  }

  Future<void> _abrirTarefa([int? id]) async {
    if (!_canViewData) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: id)),
    );
    if (mounted) {
      await _carregar();
    }
  }

  Future<void> _excluirTarefa(int id) async {
    if (!_canManage) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover tarefa'),
        content: const Text('Deseja remover esta tarefa?'),
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
      await _api.delete('/tasks/$id');
      await _carregar();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Map<String, int> get _contagemStatus {
    final counts = <String, int>{
      'all': _tarefas.length,
      'aberta': 0,
      'em_andamento': 0,
      'concluida': 0,
    };
    for (final task in _tarefas) {
      final status = task['status']?.toString() ?? 'aberta';
      counts[status] = (counts[status] ?? 0) + 1;
    }
    return counts;
  }

  String _montarTextoBusca(Map<String, dynamic> task) {
    return [
      task['title'],
      task['client_name'],
      task['client_address'],
      task['task_type_name'],
      task['status'],
      task['priority'],
    ].map((value) => value?.toString() ?? '').join(' ').toLowerCase();
  }

  List<Map<String, dynamic>> _tarefasFiltradas() {
    final query = _textoBusca.trim().toLowerCase();
    return _tarefas.where((task) {
      if (_filtroStatus != null &&
          task['status']?.toString() != _filtroStatus) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      return _montarTextoBusca(task).contains(query);
    }).toList();
  }


  void _mostrarAvisoDadosAntigos() {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      const SnackBar(
        content: Text(
          'Tarefas exibidas com dados salvos enquanto a API responde.',
        ),
      ),
    );
  }

  Map<String, List<Map<String, dynamic>>> _agruparTarefasPorData(
    List<Map<String, dynamic>> tasks,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final task in tasks) {
      final key = formatarChaveData(task['start_date']?.toString() ?? '').isNotEmpty
          ? formatarChaveData(task['start_date']?.toString() ?? '')
          : formatarChaveData(task['due_date']?.toString() ?? '');
      if (key.isEmpty) continue;
      grouped.putIfAbsent(key, () => []).add(task);
    }
    return grouped;
  }

  List<DateTime?> _montarDiasCalendario(DateTime monthDate) {
    final firstDay = DateTime(monthDate.year, monthDate.month, 1);
    final startOffset = firstDay.weekday % 7;
    final daysInMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;
    final days = <DateTime?>[];
    for (var i = 0; i < startOffset; i += 1) {
      days.add(null);
    }
    for (var day = 1; day <= daysInMonth; day += 1) {
      days.add(DateTime(monthDate.year, monthDate.month, day));
    }
    while (days.length % 7 != 0) {
      days.add(null);
    }
    return days;
  }

  @override
  Widget build(BuildContext context) {
    if (!_canViewData) {
      return AppScaffold(
        title: 'Tarefas',
        showAppBar: widget.clientId != null,
        body: const AccessRestrictedState(
          title: 'Tarefas protegidas para este perfil',
          message:
              'O perfil visitante pode abrir a tela, mas não pode visualizar listas, detalhes nem histórico de tarefas.',
        ),
      );
    }

    if (_carregando) {
      return AppScaffold(
        title: 'Tarefas',
        showAppBar: widget.clientId != null,
        body: const LoadingView(message: 'Carregando tarefas...'),
      );
    }

    if (_erro != null) {
      return AppScaffold(
        title: 'Tarefas',
        showAppBar: widget.clientId != null,
        body: ErrorView(
          message: _erro!,
          onRetry: _carregar,
        ),
      );
    }

    final filteredTasks = _tarefasFiltradas();
    final groupedTasks = _agruparTarefasPorData(filteredTasks);
    final calendarDays = _montarDiasCalendario(_mesCalendario);
    final tasksForSelectedDate = _dataSelecionada == null
        ? const <Map<String, dynamic>>[]
        : groupedTasks[_dataSelecionada] ?? const <Map<String, dynamic>>[];

    return AppScaffold(
      title: 'Tarefas',
      showAppBar: false,
      padding: EdgeInsets.zero,
      body: RefreshIndicator(
        onRefresh: _carregar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            120,
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.clientName != null
                        ? 'Tarefas — ${widget.clientName}'
                        : 'Tarefas',
                    style: Theme.of(context).textTheme.headlineMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Atualizar',
                  onPressed: _carregar,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                IconButton(
                  tooltip: _modoVisualizacao == TaskViewMode.list
                      ? 'Abrir agenda'
                      : 'Abrir lista',
                  onPressed: () {
                    setState(() {
                      _modoVisualizacao = _modoVisualizacao == TaskViewMode.list
                          ? TaskViewMode.calendar
                          : TaskViewMode.list;
                    });
                  },
                  icon: Icon(
                    _modoVisualizacao == TaskViewMode.list
                        ? Icons.calendar_month_outlined
                        : Icons.view_list_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppSearchField(
              controller: _controladorBusca,
              hintText: 'Buscar tarefas...',
              onChanged: (value) => setState(() => _textoBusca = value),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _TaskFilterChip(
                    label: 'Todas',
                    count: _contagemStatus['all'] ?? 0,
                    selected: _filtroStatus == null,
                    onTap: () => setState(() => _filtroStatus = null),
                  ),
                  _TaskFilterChip(
                    label: 'Abertas',
                    count: _contagemStatus['aberta'] ?? 0,
                    selected: _filtroStatus == 'aberta',
                    onTap: () => setState(() => _filtroStatus = 'aberta'),
                  ),
                  _TaskFilterChip(
                    label: 'Andamento',
                    count: _contagemStatus['em_andamento'] ?? 0,
                    selected: _filtroStatus == 'em_andamento',
                    onTap: () => setState(() => _filtroStatus = 'em_andamento'),
                  ),
                  _TaskFilterChip(
                    label: 'Concluídas',
                    count: _contagemStatus['concluida'] ?? 0,
                    selected: _filtroStatus == 'concluida',
                    onTap: () => setState(() => _filtroStatus = 'concluida'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_modoVisualizacao == TaskViewMode.list) ...[
              if (filteredTasks.isEmpty)
                const EmptyState(
                  title: 'Nenhuma tarefa encontrada',
                  message:
                      'Ajuste os filtros ou crie uma nova tarefa para começar.',
                  icon: Icons.task_alt_outlined,
                  illustrationAsset: AppAssets.emptyTasks,
                )
              else
                ...filteredTasks.map((task) {
                  final id = task['id'] as int?;
                  return TaskCard(
                    title: task['title']?.toString() ?? 'Tarefa',
                    clientName:
                        task['client_name']?.toString() ?? 'Sem cliente',
                    location: task['client_address']?.toString() ?? '',
                    statusLabel: labelStatusTarefa(task['status']?.toString()),
                    priorityLabel: labelPrioridadeTarefa(task['priority']?.toString()),
                    codeLabel: '#${id ?? '--'}',
                    avatarName: task['client_name']?.toString() ?? 'Cliente',
                    onTap: () => _abrirTarefa(id),
                    onMore: !_canManage || id == null
                        ? null
                        : () => _abrirAcoesTarefa(context, task),
                  );
                }),
            ] else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _mesCalendario = DateTime(
                                  _mesCalendario.year,
                                  _mesCalendario.month - 1,
                                  1,
                                );
                              });
                            },
                            icon: const Icon(Icons.chevron_left_rounded),
                          ),
                          Expanded(
                            child: Text(
                              formatarRotuloMes(_mesCalendario),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _mesCalendario = DateTime(
                                  _mesCalendario.year,
                                  _mesCalendario.month + 1,
                                  1,
                                );
                              });
                            },
                            icon: const Icon(Icons.chevron_right_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      GridView.count(
                        crossAxisCount: 7,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: AppSpacing.xs,
                        mainAxisSpacing: AppSpacing.xs,
                        childAspectRatio: 0.92,
                        children: [
                          ...const ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'].map(
                            (label) => Center(
                              child: Text(
                                label,
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ),
                          ),
                          ...calendarDays.map((date) {
                            if (date == null) {
                              return const SizedBox.shrink();
                            }
                            final key =
                                '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                            final count = groupedTasks[key]?.length ?? 0;
                            final selected = _dataSelecionada == key;
                            return InkWell(
                              onTap: () => setState(() => _dataSelecionada = key),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: selected
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.1)
                                      : Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: selected
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.outline,
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    Center(
                                      child: Text(
                                        date.day.toString(),
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge,
                                      ),
                                    ),
                                    if (count > 0)
                                      Positioned(
                                        top: 6,
                                        right: 6,
                                        child: StatusChip(
                                          label: '$count',
                                          tone: StatusChipTone.primary,
                                          compact: true,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_dataSelecionada != null && tasksForSelectedDate.isEmpty)
                const EmptyState(
                  title: 'Sem tarefas neste dia',
                  message: 'Selecione outra data ou crie uma nova tarefa.',
                  icon: Icons.calendar_today_outlined,
                  illustrationAsset: AppAssets.emptyTasks,
                ),
              ...tasksForSelectedDate.map((task) {
                final id = task['id'] as int?;
                return TaskCard(
                  title: task['title']?.toString() ?? 'Tarefa',
                  clientName: task['client_name']?.toString() ?? 'Sem cliente',
                  location: task['client_address']?.toString() ?? '',
                  statusLabel: labelStatusTarefa(task['status']?.toString()),
                  priorityLabel: labelPrioridadeTarefa(task['priority']?.toString()),
                  codeLabel: '#${id ?? '--'}',
                  avatarName: task['client_name']?.toString() ?? 'Cliente',
                  onTap: () => _abrirTarefa(id),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _abrirAcoesTarefa(
    BuildContext context,
    Map<String, dynamic> task,
  ) async {
    if (!_canManage) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new_rounded),
              title: const Text('Abrir detalhes'),
              onTap: () => Navigator.pop(context, 'open'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Remover tarefa'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || selected == null) return;

    if (selected == 'open') {
      _abrirTarefa(task['id'] as int?);
    } else if (selected == 'delete' && task['id'] is int) {
      _excluirTarefa(task['id'] as int);
    }
  }
}

class _TaskFilterChip extends StatelessWidget {
  const _TaskFilterChip({
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
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
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
