import 'package:flutter/material.dart';

import 'budgets_screen.dart';
import 'clients_screen.dart';
import 'dashboard_screen.dart';
import 'equipments_screen.dart';
import 'more_screen.dart';
import 'tasks_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  late final List<Widget> _screens = [
    const DashboardScreen(),
    const TasksScreen(),
    const EquipmentsScreen(),
    const BudgetsScreen(),
    ClientsScreen(),
    const MoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Painel'),
          NavigationDestination(icon: Icon(Icons.task_alt), label: 'Tarefas'),
          NavigationDestination(icon: Icon(Icons.handyman_outlined), label: 'Equipamentos'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Orçamentos'),
          NavigationDestination(icon: Icon(Icons.people_alt_outlined), label: 'Clientes'),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'Mais'),
        ],
      ),
    );
  }
}
