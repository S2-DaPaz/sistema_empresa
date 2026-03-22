import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'budgets_screen.dart';
import 'clients_screen.dart';
import 'dashboard_screen.dart';
import 'more_screen.dart';
import 'products_screen.dart';
import 'task_detail_screen.dart';
import 'tasks_screen.dart';

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
      case DashboardShortcut.products:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProductsScreen()),
        );
        break;
    }
  }

  void _openNewTask() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const TaskDetailScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBody: true,
      backgroundColor: AppTokens.bgLight,
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(index: _index, children: _screens),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: SafeArea(
              top: false,
              child: Container(
                height: 82,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.98),
                  borderRadius: BorderRadius.circular(AppTokens.radiusXl),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  boxShadow: AppTokens.softShadow,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _ShellNavItem(
                        label: 'Inicio',
                        icon: Icons.home_outlined,
                        selectedIcon: Icons.home_rounded,
                        selected: _index == 0,
                        onTap: () => setState(() => _index = 0),
                      ),
                    ),
                    Expanded(
                      child: _ShellNavItem(
                        label: 'Tarefas',
                        icon: Icons.task_alt_outlined,
                        selectedIcon: Icons.task_alt_rounded,
                        selected: _index == 1,
                        onTap: () => setState(() => _index = 1),
                      ),
                    ),
                    const SizedBox(width: 72),
                    Expanded(
                      child: _ShellNavItem(
                        label: 'Clientes',
                        icon: Icons.people_outline_rounded,
                        selectedIcon: Icons.people_rounded,
                        selected: _index == 2,
                        onTap: () => setState(() => _index = 2),
                      ),
                    ),
                    Expanded(
                      child: _ShellNavItem(
                        label: 'Mais',
                        icon: Icons.grid_view_outlined,
                        selectedIcon: Icons.grid_view_rounded,
                        selected: _index == 3,
                        onTap: () => setState(() => _index = 3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 44,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _openNewTask,
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    gradient: AppTokens.heroGradient,
                    shape: BoxShape.circle,
                    boxShadow: AppTokens.softShadow,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShellNavItem extends StatelessWidget {
  const _ShellNavItem({
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
    final color = selected
        ? AppTokens.primaryBlue
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.48);

    return InkWell(
      borderRadius: BorderRadius.circular(AppTokens.radiusLg),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? selectedIcon : icon, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
