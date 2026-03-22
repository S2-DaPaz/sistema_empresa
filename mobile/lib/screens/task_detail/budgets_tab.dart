import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_ui.dart';
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
      padding: const EdgeInsets.all(AppTokens.space4),
      children: [
        if (taskId == null)
          const EmptyStateCard(
            title: 'Salve a tarefa para liberar os orçamentos',
            subtitle: 'O vínculo comercial depende da tarefa e do relatório geral.',
          ),
        if (taskId != null) ...[
          AppSurface(
            child: BudgetForm(
              clientId: clientId,
              taskId: taskId,
              reportId: generalReportId,
              products: products,
              onSaved: onBudgetSaved,
            ),
          ),
          const SizedBox(height: AppTokens.space5),
          const AppSectionBlock(
            title: 'Orçamentos vinculados',
            subtitle: 'Pipeline comercial conectado a esta execução.',
          ),
          const SizedBox(height: AppTokens.space4),
          if (budgets.isEmpty)
            const EmptyStateCard(
              title: 'Nenhum orçamento vinculado',
              subtitle: 'Crie uma proposta para registrar valores, itens e aprovação.',
            ),
          ...budgets.map((budget) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Orçamento #${budget['id']}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        AppStatusPill(
                          label: budget['status']?.toString() ?? 'rascunho',
                        ),
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
                    const SizedBox(height: 6),
                    Text(
                      'Total: ${formatCurrency(budget['total'] ?? 0)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    ...(budget['items'] as List<dynamic>? ?? [])
                        .cast<Map<String, dynamic>>()
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    item['description']?.toString() ?? 'Item',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(formatCurrency(item['total'] ?? 0)),
                              ],
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
        ],
      ],
    );
  }
}
