/// Aba "Orçamentos" da tela de tarefa.
///
/// Exibe o [BudgetForm] inline para criação rápida e a lista de
/// orçamentos já vinculados, com opções de editar e remover.
library;

import 'package:flutter/material.dart';

import '../utils/formatters.dart';
import '../widgets/budget_form.dart';

class TaskDetailBudgetsTab extends StatelessWidget {
  const TaskDetailBudgetsTab({
    super.key,
    required this.taskId,
    required this.clientId,
    required this.reports,
    required this.budgets,
    required this.products,
    required this.onBudgetsSaved,
    required this.onEditBudget,
    required this.onDeleteBudget,
  });

  final int? taskId;
  final int? clientId;
  final List<Map<String, dynamic>> reports;
  final List<Map<String, dynamic>> budgets;
  final List<Map<String, dynamic>> products;
  final VoidCallback onBudgetsSaved;
  final void Function(Map<String, dynamic> budget) onEditBudget;
  final void Function(int id) onDeleteBudget;

  @override
  Widget build(BuildContext context) {
    final generalReport = reports.firstWhere(
      (item) => item['equipment_id'] == null,
      orElse: () => <String, dynamic>{},
    );

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
            reportId: generalReport['id'] as int?,
            products: products,
            onSaved: onBudgetsSaved,
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
                        Text('orçamento #${budget['id']}',
                            style: Theme.of(context).textTheme.titleSmall),
                        Row(
                          children: [
                            Chip(
                                label: Text(budget['status']?.toString() ??
                                    'rascunho')),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  onEditBudget(budget);
                                } else if (value == 'delete') {
                                  onDeleteBudget(budget['id'] as int);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                    value: 'edit', child: Text('Editar')),
                                PopupMenuItem(
                                    value: 'delete', child: Text('Remover')),
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
                                Expanded(
                                    child: Text(
                                        item['description']?.toString() ??
                                            'Item')),
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
