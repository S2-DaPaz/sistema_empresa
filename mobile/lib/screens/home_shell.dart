import 'package:flutter/material.dart';

import '../services/permissions.dart';
import '../theme/app_tokens.dart';
import 'budgets_screen.dart';
import 'clients_screen.dart';
import 'dashboard_screen.dart';
import 'more_screen.dart';
import 'task_detail_screen.dart';
import 'tasks_screen.dart';

enum DashboardShortcut { clients, tasks, budgets, more }

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  late final List<Widget> _screens = [
    DashboardScreen(onOpenShortcut: _handleDashboardShortcut),
    const TasksScreen(),
    const ClientsScreen(),
    const MoreScreen(),
  ];

  void _handleDashboardShortcut(DashboardShortcut shortcut) {
    switch (shortcut) {
      case DashboardShortcut.clients:
        setState(() => _index = 2);
        break;
      case DashboardShortcut.tasks:
        setState(() => _index = 1);
        break;
      case DashboardShortcut.budgets:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const BudgetsScreen()),
        );
        break;
      case DashboardShortcut.more:
        setState(() => _index = 3);
        break;
    }
  }

  Future<void> _openQuickCreate() async {
    if (!Permissions.canManageModule(AppModule.tasks)) {
      setState(() => _index = 1);
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TaskDetailScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: IndexedStack(index: _index, children: _screens),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: DecoratedBox(
        decoration: BoxDecoration(
          gradient: isDark ? AppGradients.darkPrimaryAction : null,
          shape: BoxShape.circle,
          boxShadow: isDark ? AppShadows.darkCard : AppShadows.card,
        ),
        child: FloatingActionButton(
          onPressed: _openQuickCreate,
          backgroundColor: isDark ? Colors.transparent : null,
          foregroundColor:
              isDark ? AppDarkColors.backgroundBase : theme.colorScheme.onPrimary,
          elevation: 0,
          child: const Icon(Icons.add_rounded),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: isDark ? 0.92 : 1),
            gradient: isDark ? AppGradients.darkNavigation : null,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: theme.colorScheme.outline
                  .withValues(alpha: isDark ? 0.92 : 0.5),
            ),
            boxShadow: isDark ? AppShadows.darkCard : AppShadows.card,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(
              children: [
                _ShellDestination(
                  label: 'Início',
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home_rounded,
                  selected: _index == 0,
                  onTap: () => setState(() => _index = 0),
                ),
                _ShellDestination(
                  label: 'Tarefas',
                  icon: Icons.task_alt_outlined,
                  selectedIcon: Icons.task_alt_rounded,
                  selected: _index == 1,
                  onTap: () => setState(() => _index = 1),
                ),
                const SizedBox(width: 72),
                _ShellDestination(
                  label: 'Clientes',
                  icon: Icons.people_outline_rounded,
                  selectedIcon: Icons.people_rounded,
                  selected: _index == 2,
                  onTap: () => setState(() => _index = 2),
                ),
                _ShellDestination(
                  label: 'Mais',
                  icon: Icons.grid_view_rounded,
                  selectedIcon: Icons.grid_view_rounded,
                  selected: _index == 3,
                  onTap: () => setState(() => _index = 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShellDestination extends StatelessWidget {
  const _ShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = selected
        ? theme.colorScheme.primary
        : theme.textTheme.bodySmall?.color;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.16 : 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected && isDark
                  ? theme.colorScheme.primary.withValues(alpha: 0.24)
                  : Colors.transparent,
            ),
            boxShadow: selected && isDark ? AppShadows.darkGlow : const [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? selectedIcon : icon, color: color),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(color: color),
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
