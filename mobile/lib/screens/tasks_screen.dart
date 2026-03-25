import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/offline_cache_service.dart';
import '../theme/app_assets.dart';
import '../theme/app_tokens.dart';
import '../utils/formatters.dart';
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
  static const String _cacheKey = 'offline_cache_tasks_list';

  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _tasks = [];
  TaskViewMode _viewMode = TaskViewMode.list;
  DateTime _calendarMonth = DateTime.now();
  String? _selectedDate;
  String _searchQuery = '';
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _primeFromCache();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final hadTasks = _tasks.isNotEmpty;
    setState(() {
      _loading = !hadTasks;
      _error = null;
    });
    try {
      final endpoint = widget.clientId != null
          ? '/tasks?clientId=${widget.clientId}'
          : '/tasks';
      final data = await _api.get(endpoint) as List<dynamic>;
      final nextTasks = List<Map<String, dynamic>>.from(data);
      await OfflineCacheService.writeList(_cacheKey, nextTasks);
      if (!mounted) return;
      setState(() {
        _tasks = nextTasks;
        _loading = false;
      });
    } catch (error) {
      final cached =
          hadTasks ? _tasks : await OfflineCacheService.readList(_cacheKey);
      if (!mounted) return;
      if (cached != null && cached.isNotEmpty) {
        setState(() {
          _tasks = cached;
          _loading = false;
        });
        _showStaleDataWarning();
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _primeFromCache() async {
    final cached = await OfflineCacheService.readList(_cacheKey);
    if (!mounted || cached == null || cached.isEmpty || _tasks.isNotEmpty) {
      return;
    }
    setState(() {
      _tasks = cached;
      _loading = false;
      _error = null;
    });
  }

  Future<void> _openTask([int? id]) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: id)),
    );
    if (mounted) {
      await _load();
    }
  }

  Future<void> _deleteTask(int id) async {
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
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Map<String, int> get _statusCounts {
    final counts = <String, int>{
      'all': _tasks.length,
      'aberta': 0,
      'em_andamento': 0,
      'concluida': 0,
    };
    for (final task in _tasks) {
      final status = task['status']?.toString() ?? 'aberta';
      counts[status] = (counts[status] ?? 0) + 1;
    }
    return counts;
  }

  String _buildSearchText(Map<String, dynamic> task) {
    return [
      task['title'],
      task['client_name'],
      task['client_address'],
      task['task_type_name'],
      task['status'],
      task['priority'],
    ].map((value) => value?.toString() ?? '').join(' ').toLowerCase();
  }

  List<Map<String, dynamic>> _filteredTasks() {
    final query = _searchQuery.trim().toLowerCase();
    return _tasks.where((task) {
      if (_statusFilter != null &&
          task['status']?.toString() != _statusFilter) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      return _buildSearchText(task).contains(query);
    }).toList();
  }

  String _statusLabel(String? value) {
    switch (value) {
      case 'aberta':
        return 'Aberta';
      case 'em_andamento':
        return 'Em andamento';
      case 'concluida':
        return 'Concluída';
      default:
        return value?.isNotEmpty == true ? value! : 'Aberta';
    }
  }

  String _priorityLabel(String? value) {
    switch (value) {
      case 'alta':
        return 'Alta';
      case 'media':
        return 'Média';
      case 'baixa':
        return 'Baixa';
      default:
        return value?.isNotEmpty == true ? value! : 'Média';
    }
  }

  void _showStaleDataWarning() {
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

  Map<String, List<Map<String, dynamic>>> _groupTasksByDate(
    List<Map<String, dynamic>> tasks,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final task in tasks) {
      final key = formatDateKey(task['start_date']?.toString() ?? '').isNotEmpty
          ? formatDateKey(task['start_date']?.toString() ?? '')
          : formatDateKey(task['due_date']?.toString() ?? '');
      if (key.isEmpty) continue;
      grouped.putIfAbsent(key, () => []).add(task);
    }
    return grouped;
  }

  List<DateTime?> _buildCalendarDays(DateTime monthDate) {
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
    if (_loading) {
      return AppScaffold(
        title: 'Tarefas',
        showAppBar: widget.clientId != null,
        body: const LoadingView(message: 'Carregando tarefas...'),
      );
    }

    if (_error != null) {
      return AppScaffold(
        title: 'Tarefas',
        showAppBar: widget.clientId != null,
        body: ErrorView(
          message: _error!,
          onRetry: _load,
        ),
      );
    }

    final filteredTasks = _filteredTasks();
    final groupedTasks = _groupTasksByDate(filteredTasks);
    final calendarDays = _buildCalendarDays(_calendarMonth);
    final tasksForSelectedDate = _selectedDate == null
        ? const <Map<String, dynamic>>[]
        : groupedTasks[_selectedDate] ?? const <Map<String, dynamic>>[];

    return AppScaffold(
      title: 'Tarefas',
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
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                IconButton(
                  tooltip: _viewMode == TaskViewMode.list
                      ? 'Abrir agenda'
                      : 'Abrir lista',
                  onPressed: () {
                    setState(() {
                      _viewMode = _viewMode == TaskViewMode.list
                          ? TaskViewMode.calendar
                          : TaskViewMode.list;
                    });
                  },
                  icon: Icon(
                    _viewMode == TaskViewMode.list
                        ? Icons.calendar_month_outlined
                        : Icons.view_list_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppSearchField(
              controller: _searchController,
              hintText: 'Buscar tarefas...',
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _TaskFilterChip(
                    label: 'Todas',
                    count: _statusCounts['all'] ?? 0,
                    selected: _statusFilter == null,
                    onTap: () => setState(() => _statusFilter = null),
                  ),
                  _TaskFilterChip(
                    label: 'Abertas',
                    count: _statusCounts['aberta'] ?? 0,
                    selected: _statusFilter == 'aberta',
                    onTap: () => setState(() => _statusFilter = 'aberta'),
                  ),
                  _TaskFilterChip(
                    label: 'Andamento',
                    count: _statusCounts['em_andamento'] ?? 0,
                    selected: _statusFilter == 'em_andamento',
                    onTap: () => setState(() => _statusFilter = 'em_andamento'),
                  ),
                  _TaskFilterChip(
                    label: 'Concluídas',
                    count: _statusCounts['concluida'] ?? 0,
                    selected: _statusFilter == 'concluida',
                    onTap: () => setState(() => _statusFilter = 'concluida'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_viewMode == TaskViewMode.list) ...[
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
                    statusLabel: _statusLabel(task['status']?.toString()),
                    priorityLabel: _priorityLabel(task['priority']?.toString()),
                    codeLabel: '#${id ?? '--'}',
                    avatarName: task['client_name']?.toString() ?? 'Cliente',
                    onTap: () => _openTask(id),
                    onMore: id == null
                        ? null
                        : () => _openTaskActions(context, task),
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
                                _calendarMonth = DateTime(
                                  _calendarMonth.year,
                                  _calendarMonth.month - 1,
                                  1,
                                );
                              });
                            },
                            icon: const Icon(Icons.chevron_left_rounded),
                          ),
                          Expanded(
                            child: Text(
                              formatMonthLabel(_calendarMonth),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _calendarMonth = DateTime(
                                  _calendarMonth.year,
                                  _calendarMonth.month + 1,
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
                            final selected = _selectedDate == key;
                            return InkWell(
                              onTap: () => setState(() => _selectedDate = key),
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
              if (_selectedDate != null && tasksForSelectedDate.isEmpty)
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
                  statusLabel: _statusLabel(task['status']?.toString()),
                  priorityLabel: _priorityLabel(task['priority']?.toString()),
                  codeLabel: '#${id ?? '--'}',
                  avatarName: task['client_name']?.toString() ?? 'Cliente',
                  onTap: () => _openTask(id),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openTaskActions(
    BuildContext context,
    Map<String, dynamic> task,
  ) async {
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
      _openTask(task['id'] as int?);
    } else if (selected == 'delete' && task['id'] is int) {
      _deleteTask(task['id'] as int);
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
