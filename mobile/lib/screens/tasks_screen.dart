import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/formatters.dart';
import '../widgets/app_scaffold.dart';
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
      final data = await _api.get('/tasks') as List<dynamic>;
      setState(() {
        _tasks = data.cast<Map<String, dynamic>>();
      });
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      setState(() => _loading = false);
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remover')),
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

  String _formatStatus(String? value) {
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

  String _formatPriority(String? value) {
    switch (value) {
      case 'alta':
        return 'Alta';
      case 'media':
        return 'Media';
      case 'baixa':
        return 'Baixa';
      default:
        return value?.isNotEmpty == true ? value! : 'Media';
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupTasksByDate(List<Map<String, dynamic>> tasks) {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final task in tasks) {
      final key = formatDateKey(task['start_date']?.toString() ?? '')
          .ifEmpty(formatDateKey(task['due_date']?.toString() ?? ''));
      if (key == null || key.isEmpty) continue;
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
      if (query.isEmpty) return true;
      return _buildSearchText(task).contains(query);
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
              title: const Text('Aberta'),
              onTap: () => Navigator.pop(context, 'aberta'),
            ),
            ListTile(
              title: const Text('Em andamento'),
              onTap: () => Navigator.pop(context, 'em_andamento'),
            ),
            ListTile(
              title: const Text('Concluída'),
              onTap: () => Navigator.pop(context, 'concluida'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || selected == null) return;
    setState(() => _statusFilter = selected == 'todos' ? null : selected);
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

    return AppScaffold(
      title: 'Tarefas',
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-tasks',
        onPressed: () => _openTask(),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar tarefas',
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
                    label: Text('Status: ${_formatStatus(_statusFilter)}'),
                    onDeleted: () => setState(() => _statusFilter = null),
                  ),
              ],
            ),
          ],
          ToggleButtons(
            isSelected: [
              _viewMode == TaskViewMode.list,
              _viewMode == TaskViewMode.calendar,
            ],
            onPressed: (index) {
              setState(() {
                _viewMode = index == 0 ? TaskViewMode.list : TaskViewMode.calendar;
              });
            },
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('Lista'),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('Calendario'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_viewMode == TaskViewMode.list)
            if (filteredTasks.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Nenhuma tarefa encontrada com os filtros atuais.'),
                ),
              )
            else
              ...filteredTasks.map((task) {
                return Card(
                  child: ListTile(
                    title: Text(task['title']?.toString() ?? 'Tarefa'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${task['client_name'] ?? 'Sem cliente'} | ${task['task_type_name'] ?? 'Sem tipo'}',
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          children: [
                            Chip(label: Text(_formatStatus(task['status']?.toString()))),
                            Chip(label: Text(_formatPriority(task['priority']?.toString()))),
                          ],
                        ),
                      ],
                    ),
                    onTap: () => _openTask(task['id'] as int?),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'delete') {
                          _deleteTask(task['id'] as int);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'delete', child: Text('Remover')),
                      ],
                    ),
                  ),
                );
              }),
          if (_viewMode == TaskViewMode.calendar)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Mes anterior',
                          onPressed: () {
                            setState(() {
                              _calendarMonth = DateTime(
                                _calendarMonth.year,
                                _calendarMonth.month - 1,
                                1,
                              );
                            });
                          },
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Expanded(
                          child: Text(
                            formatMonthLabel(_calendarMonth),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Proximo mes',
                          onPressed: () {
                            setState(() {
                              _calendarMonth = DateTime(
                                _calendarMonth.year,
                                _calendarMonth.month + 1,
                                1,
                              );
                            });
                          },
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 7,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 0.95,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        ...['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sab']
                            .map((label) => Center(
                                  child: Text(
                                    label,
                                    style: Theme.of(context).textTheme.labelSmall,
                                  ),
                                )),
                        ...calendarDays.map((date) {
                          if (date == null) {
                            return Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                              ),
                            );
                          }
                          final key =
                              '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                          final count = grouped[key]?.length ?? 0;
                          final isSelected = _selectedDate == key;
                          return InkWell(
                            onTap: () => setState(() => _selectedDate = key),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.black.withValues(alpha: 0.1),
                                ),
                              ),
                              child: Stack(
                                children: [
                                  Center(
                                    child: Text(
                                      date.day.toString(),
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                  if (count > 0)
                                    Positioned(
                                      right: 6,
                                      top: 6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          count.toString(),
                                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                color: Theme.of(context).colorScheme.primary,
                                              ),
                                        ),
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
          if (_viewMode == TaskViewMode.calendar)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                children: [
                  if (_selectedDate != null && tasksForSelectedDate.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Nenhuma tarefa para este dia.'),
                      ),
                    ),
                  ...tasksForSelectedDate.map((task) => Card(
                        child: ListTile(
                          title: Text(task['title']?.toString() ?? 'Tarefa'),
                          subtitle: Text(task['client_name']?.toString() ?? 'Sem cliente'),
                          onTap: () => _openTask(task['id'] as int?),
                        ),
                      )),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

extension on String {
  String? ifEmpty(String? fallback) {
    if (isNotEmpty) return this;
    return fallback;
  }
}
