import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'budgets_screen.dart';
import 'clients_screen.dart';
import 'dashboard_screen.dart';
import 'more_screen.dart';
import 'products_screen.dart';
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
    ClientsScreen(),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(index: _index, children: _screens),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  boxShadow: AppTokens.softShadow,
                ),
                child: NavigationBar(
                  height: 74,
                  selectedIndex: _index,
                  backgroundColor: Colors.transparent,
                  labelBehavior:
                      NavigationDestinationLabelBehavior.alwaysShow,
                  onDestinationSelected: (value) {
                    setState(() => _index = value);
                  },
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home_rounded),
                      label: 'Início',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.task_alt_outlined),
                      selectedIcon: Icon(Icons.task_alt),
                      label: 'Tarefas',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.people_alt_outlined),
                      selectedIcon: Icon(Icons.people_alt),
                      label: 'Clientes',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.grid_view_rounded),
                      selectedIcon: Icon(Icons.grid_view_rounded),
                      label: 'Mais',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
