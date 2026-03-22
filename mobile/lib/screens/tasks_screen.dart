import 'package:flutter/material.dart';

import '../core/offline/offline_read_cache.dart';
import '../services/api_service.dart';
import '../theme/app_tokens.dart';
import '../utils/formatters.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_ui.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';
import 'task_detail_screen.dart';

enum TaskViewMode { list, calendar }

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  static const _cacheKey = 'offline_cache_tasks_list';

  final ApiService _api = ApiService();
  final OfflineReadCache _cache = OfflineReadCache.instance;
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  String? _offlineNotice;
  List<Map<String, dynamic>> _tasks = [];
  TaskViewMode _viewMode = TaskViewMode.list;
  DateTime _calendarMonth = DateTime.now();
  String? _selectedDate;
  String _searchQuery = '';
  String? _statusFilter = 'em_andamento';

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
      final data = await _api.get('/tasks') as List<dynamic>;
      final tasks = data.cast<Map<String, dynamic>>();
      if (!mounted) {
        return;
      }
      setState(() {
        _tasks = tasks;
        _loading = false;
      });
      await _cache.writeJson(_cacheKey, data);
    } catch (_) {
      final cached = await _cache.readList(_cacheKey);
      if (cached != null) {
        if (!mounted) {
          return;
        }
        setState(() {
          _tasks = cached.cast<Map<String, dynamic>>();
          _offlineNotice =
              'Sem conexão. Exibindo a última lista de tarefas salva neste aparelho.';
          _loading = false;
        });
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Não foi possível carregar a fila de tarefas.';
        _loading = false;
      });
    }
  }

  void _openTask([int? id]) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: id)))
        .then((_) => _load());
  }

  Future<void> _deleteTask(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
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
    if (confirmed != true) {
      return;
    }
    try {
      await _api.delete('/tasks/$id');
      await _load();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível remover a tarefa agora.'),
        ),
      );
    }
  }

  String _formatStatus(String? value) {
    switch (value) {
      case 'aberta':
        return 'Hoje';
      case 'em_andamento':
        return 'Em andamento';
      case 'concluida':
        return 'Concluídas';
      default:
        return 'Hoje';
    }
  }

  String _formatPriority(String? value) {
    switch (value) {
      case 'alta':
        return 'alta';
      case 'media':
        return 'média';
      case 'baixa':
        return 'baixa';
      default:
        return 'média';
    }
  }

  Color _priorityColor(String? value) {
    switch (value) {
      case 'alta':
        return AppTokens.accentBlue;
      case 'media':
        return AppTokens.primaryCyan;
      case 'baixa':
        return AppTokens.supportTeal;
      default:
        return AppTokens.accentBlue;
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupTasksByDate(
    List<Map<String, dynamic>> tasks,
  ) {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final task in tasks) {
      final key = formatDateKey(task['start_date']?.toString() ?? '')
          .ifEmpty(formatDateKey(task['due_date']?.toString() ?? ''));
      if (key == null || key.isEmpty) {
        continue;
      }
      map.putIfAbsent(key, () => []).add(task);
    }
    return map;
  }

  String _buildSearchText(Map<String, dynamic> task) {
    final parts = [
      task['title'],
      task['client_name'],
      task['task_type_name'],
      task['status'],
      task['priority'],
    ];
    return parts.map((value) => value?.toString() ?? '').join(' ').toLowerCase();
  }

  List<Map<String, dynamic>> _filteredTasks() {
    final query = _searchQuery.trim().toLowerCase();
    return _tasks.where((task) {
      if (_statusFilter != null && task['status']?.toString() != _statusFilter) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      return _buildSearchText(task).contains(query);
    }).toList();
  }

  List<DateTime?> _buildCalendarDays(DateTime monthDate) {
    final year = monthDate.year;
    final month = monthDate.month;
    final firstDay = DateTime(year, month, 1);
    final startOffset = firstDay.weekday % 7;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final days = <DateTime?>[];
    for (var i = 0; i < startOffset; i += 1) {
      days.add(null);
    }
    for (var day = 1; day <= daysInMonth; day += 1) {
      days.add(DateTime(year, month, day));
    }
    while (days.length % 7 != 0) {
      days.add(null);
    }
    return days;
  }

  Map<String, dynamic>? _priorityTask(List<Map<String, dynamic>> tasks) {
    if (tasks.isEmpty) {
      return null;
    }
    final high = tasks.where((task) => task['priority'] == 'alta').toList();
    if (high.isNotEmpty) {
      return high.first;
    }
    final running =
        tasks.where((task) => task['status'] == 'em_andamento').toList();
    return running.isNotEmpty ? running.first : tasks.first;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppScaffold(title: 'Tarefas', body: LoadingView());
    }

    if (_error != null) {
      return AppScaffold(
        title: 'Tarefas',
        body: ErrorView(message: _error!, onRetry: _load),
      );
    }

    final filteredTasks = _filteredTasks();
    final grouped = _groupTasksByDate(filteredTasks);
    final calendarDays = _buildCalendarDays(_calendarMonth);
    final tasksForSelectedDate = _selectedDate != null
        ? grouped[_selectedDate] ?? <Map<String, dynamic>>[]
        : <Map<String, dynamic>>[];
    final priorityTask = _priorityTask(filteredTasks);

    return AppScaffold(
      title: 'Tarefas',
      subtitle: _viewMode == TaskViewMode.list
          ? 'Fila priorizada para a equipe técnica'
          : 'Agenda técnica por data e janela de atendimento',
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-tasks',
        onPressed: () => _openTask(),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            if (_offlineNotice != null) ...[
              AppMessageBanner(
                message: _offlineNotice!,
                icon: Icons.cloud_off_outlined,
              ),
              const SizedBox(height: AppTokens.space4),
            ],
            AppSearchField(
              controller: _searchController,
              hintText: 'Buscar por cliente, técnico ou status',
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
            const SizedBox(height: AppTokens.space4),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in const <MapEntry<String?, String>>[
                        MapEntry('aberta', 'Hoje'),
                        MapEntry('em_andamento', 'Em andamento'),
                        MapEntry('concluida', 'Concluídas'),
                      ])
                        ChoiceChip(
                          label: Text(entry.value),
                          selected: _statusFilter == entry.key,
                          onSelected: (_) => setState(() => _statusFilter = entry.key),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ToggleButtons(
                  isSelected: [
                    _viewMode == TaskViewMode.list,
                    _viewMode == TaskViewMode.calendar,
                  ],
                  onPressed: (index) {
                    setState(() {
                      _viewMode = index == 0
                          ? TaskViewMode.list
                          : TaskViewMode.calendar;
                    });
                  },
                  borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.view_list_rounded),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.calendar_month_rounded),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppTokens.space4),
            if (priorityTask != null)
              AppHeroBanner(
                title: 'Prioridade do dia',
                subtitle:
                    '${priorityTask['title'] ?? 'Tarefa'} • ${priorityTask['client_name'] ?? 'Sem cliente'}',
                metrics: [
                  AppHeroMetric(
                    label: 'Status',
                    value: _formatStatus(priorityTask['status']?.toString()),
                  ),
                  AppHeroMetric(
                    label: 'Prioridade',
                    value: _formatPriority(priorityTask['priority']?.toString()),
                  ),
                  AppHeroMetric(
                    label: 'Início',
                    value: formatTime(priorityTask['start_date']?.toString()),
                  ),
                ],
              ),
            const SizedBox(height: AppTokens.space5),
            if (_viewMode == TaskViewMode.list) ...[
              AppSectionBlock(
                title: _statusFilter == 'concluida'
                    ? 'Concluídas'
                    : 'Em andamento',
                subtitle: '${filteredTasks.length} item(ns) nesta leitura',
              ),
              const SizedBox(height: AppTokens.space4),
              if (filteredTasks.isEmpty)
                const EmptyStateCard(
                  title: 'Nenhuma tarefa encontrada',
                  subtitle: 'Ajuste os filtros ou crie uma nova tarefa para começar.',
                ),
              ...filteredTasks.map((task) {
                final priority = task['priority']?.toString();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppSurface(
                    onTap: () => _openTask(task['id'] as int?),
                    borderColor: _priorityColor(priority).withValues(alpha: 0.35),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppTokens.accentBlue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.assignment_outlined,
                                color: AppTokens.accentBlue,
                              ),
                            ),
                            const SizedBox(width: AppTokens.space3),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    task['title']?.toString() ?? 'Tarefa',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${task['client_name'] ?? 'Sem cliente'} • ${task['task_type_name'] ?? 'Sem tipo'}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            AppStatusPill(
                              label: _formatPriority(priority),
                              color: _priorityColor(priority),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTokens.space4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Início ${formatDate(task['start_date']?.toString() ?? '')}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'delete') {
                                  _deleteTask(task['id'] as int);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Remover'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTokens.space2),
                        LinearProgressIndicator(
                          value: task['status'] == 'concluida'
                              ? 1
                              : task['status'] == 'em_andamento'
                                  ? 0.62
                                  : 0.28,
                          borderRadius: BorderRadius.circular(999),
                          minHeight: 7,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ] else ...[
              AppSectionBlock(
                title: 'Agenda técnica',
                subtitle: formatMonthLabel(_calendarMonth),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
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
              ),
              const SizedBox(height: AppTokens.space4),
              AppSurface(
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 7,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.9,
                  children: [
                    ...['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sab']
                        .map(
                          (label) => Center(
                            child: Text(
                              label,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ),
                        ),
                    ...calendarDays.map((date) {
                      if (date == null) {
                        return const SizedBox.shrink();
                      }
                      final key =
                          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                      final count = grouped[key]?.length ?? 0;
                      final isSelected = _selectedDate == key;
                      return InkWell(
                        onTap: () => setState(() => _selectedDate = key),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.1)
                                : Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: Text(
                                  date.day.toString(),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              if (count > 0)
                                Positioned(
                                  right: 4,
                                  top: 4,
                                  child: AppStatusPill(
                                    label: count.toString(),
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: AppTokens.space4),
              if (_selectedDate != null && tasksForSelectedDate.isEmpty)
                const EmptyStateCard(
                  title: 'Nenhuma visita para este dia',
                  subtitle: 'Selecione outra data ou ajuste os filtros da fila.',
                ),
              ...tasksForSelectedDate.map(
                (task) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppSurface(
                    onTap: () => _openTask(task['id'] as int?),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task['title']?.toString() ?? 'Tarefa',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${task['client_name'] ?? 'Sem cliente'} • ${task['task_type_name'] ?? 'Sem tipo'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            AppStatusPill(
                              label: _formatStatus(task['status']?.toString()),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              formatTime(task['start_date']?.toString()),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 96),
          ],
        ),
      ),
    );
  }
}

extension on String {
  String? ifEmpty(String? fallback) {
    if (isNotEmpty) {
      return this;
    }
    return fallback;
  }
}
