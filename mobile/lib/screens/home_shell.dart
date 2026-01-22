import 'package:flutter/material.dart';

import 'budgets_screen.dart';
import 'clients_screen.dart';
import 'dashboard_screen.dart';
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
    const BudgetsScreen(),
    ClientsScreen(),
    const MoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (value) => setState(() => _index = value),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Painel'),
          BottomNavigationBarItem(icon: Icon(Icons.task_alt), label: 'Tarefas'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Orçamentos'),
          BottomNavigationBarItem(icon: Icon(Icons.people_alt), label: 'Clientes'),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'Mais'),
        ],
      ),
    );
  }
}
