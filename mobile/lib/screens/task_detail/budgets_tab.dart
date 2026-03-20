import 'package:flutter/material.dart';

import '../../utils/formatters.dart';
import '../../widgets/budget_form.dart';

class TaskBudgetsTab extends StatelessWidget {
  const TaskBudgetsTab({
    super.key,
    required this.taskId,
    required this.clientId,
    required this.generalReportId,
    required this.products,
    required this.budgets,
    required this.onBudgetSaved,
    required this.onEditBudget,
    required this.onDeleteBudget,
  });

  final int? taskId;
  final int? clientId;
  final int? generalReportId;
  final List<Map<String, dynamic>> products;
  final List<Map<String, dynamic>> budgets;
  final VoidCallback onBudgetSaved;
  final ValueChanged<Map<String, dynamic>> onEditBudget;
  final ValueChanged<int> onDeleteBudget;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (taskId == null)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Salve a tarefa para liberar os Orçamentos.'),
            ),
          ),
        if (taskId != null) ...[
          BudgetForm(
            clientId: clientId,
            taskId: taskId,
            reportId: generalReportId,
            products: products,
            onSaved: onBudgetSaved,
          ),
          const SizedBox(height: 12),
          ...budgets.map((budget) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Orçamento #${budget['id']}',
                            style: Theme.of(context).textTheme.titleSmall),
                        Row(
                          children: [
                            Chip(label: Text(budget['status']?.toString() ?? 'rascunho')),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  onEditBudget(budget);
                                } else if (value == 'delete') {
                                  onDeleteBudget(budget['id'] as int);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(value: 'edit', child: Text('Editar')),
                                PopupMenuItem(value: 'delete', child: Text('Remover')),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Total: ${formatCurrency(budget['total'] ?? 0)}'),
                    const SizedBox(height: 8),
                    ...(budget['items'] as List<dynamic>? ?? [])
                        .cast<Map<String, dynamic>>()
                        .map((item) => Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(item['description']?.toString() ?? 'Item')),
                                Text(formatCurrency(item['total'] ?? 0)),
                              ],
                            )),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}
