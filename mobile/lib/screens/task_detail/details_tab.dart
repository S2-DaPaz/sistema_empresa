import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/form_fields.dart';

class TaskDetailsTab extends StatelessWidget {
  const TaskDetailsTab({
    super.key,
    required this.titleController,
    required this.descriptionController,
    required this.startDateController,
    required this.dueDateController,
    required this.status,
    required this.priority,
    required this.clientId,
    required this.userId,
    required this.taskTypeId,
    required this.clients,
    required this.users,
    required this.types,
    required this.error,
    required this.onStatusChanged,
    required this.onPriorityChanged,
    required this.onClientChanged,
    required this.onUserChanged,
    required this.onTaskTypeChanged,
    required this.onPickStartDate,
    required this.onPickDueDate,
    required this.onSave,
  });

  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController startDateController;
  final TextEditingController dueDateController;
  final String status;
  final String priority;
  final int? clientId;
  final int? userId;
  final int? taskTypeId;
  final List<Map<String, dynamic>> clients;
  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> types;
  final String? error;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onPriorityChanged;
  final ValueChanged<int?> onClientChanged;
  final ValueChanged<int?> onUserChanged;
  final ValueChanged<int?> onTaskTypeChanged;
  final VoidCallback onPickStartDate;
  final VoidCallback onPickDueDate;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppTokens.space4),
      children: [
        const AppSectionBlock(
          title: 'Resumo operacional',
          subtitle: 'Cliente, prioridade, responsável e janela de atendimento.',
        ),
        const SizedBox(height: AppTokens.space4),
        AppSurface(
          child: Column(
            children: [
              AppTextField(
                label: 'Título da tarefa',
                controller: titleController,
                hintText: 'Descreva o atendimento ou a demanda',
              ),
              const SizedBox(height: AppTokens.space4),
              Row(
                children: [
                  Expanded(
                    child: AppDropdownField<String>(
                      label: 'Status',
                      value: status,
                      items: const [
                        DropdownMenuItem(value: 'aberta', child: Text('Aberta')),
                        DropdownMenuItem(
                          value: 'em_andamento',
                          child: Text('Em andamento'),
                        ),
                        DropdownMenuItem(
                          value: 'concluida',
                          child: Text('Concluída'),
                        ),
                      ],
                      onChanged: (value) => onStatusChanged(value ?? 'aberta'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppDropdownField<String>(
                      label: 'Prioridade',
                      value: priority,
                      items: const [
                        DropdownMenuItem(value: 'alta', child: Text('Alta')),
                        DropdownMenuItem(value: 'media', child: Text('Média')),
                        DropdownMenuItem(value: 'baixa', child: Text('Baixa')),
                      ],
                      onChanged: (value) => onPriorityChanged(value ?? 'media'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.space4),
              AppDropdownField<int>(
                label: 'Cliente',
                value: clientId,
                items: clients
                    .map(
                      (client) => DropdownMenuItem<int>(
                        value: client['id'] as int?,
                        child: Text(client['name']?.toString() ?? 'Cliente'),
                      ),
                    )
                    .toList(),
                onChanged: onClientChanged,
              ),
              if (users.isNotEmpty) ...[
                const SizedBox(height: AppTokens.space4),
                AppDropdownField<int>(
                  label: 'Responsável',
                  value: userId,
                  items: users
                      .map(
                        (user) => DropdownMenuItem<int>(
                          value: user['id'] as int?,
                          child: Text(user['name']?.toString() ?? 'Usuário'),
                        ),
                      )
                      .toList(),
                  onChanged: onUserChanged,
                ),
              ],
              const SizedBox(height: AppTokens.space4),
              AppDropdownField<int>(
                label: 'Tipo de tarefa',
                value: taskTypeId,
                items: types
                    .map(
                      (type) => DropdownMenuItem<int>(
                        value: type['id'] as int?,
                        child: Text(type['name']?.toString() ?? 'Tipo'),
                      ),
                    )
                    .toList(),
                onChanged: onTaskTypeChanged,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.space4),
        AppSurface(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: AppDateField(
                      key: ValueKey(startDateController.text),
                      label: 'Início',
                      value: startDateController.text,
                      onTap: onPickStartDate,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppDateField(
                      key: ValueKey(dueDateController.text),
                      label: 'Fim',
                      value: dueDateController.text,
                      onTap: onPickDueDate,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.space4),
              AppTextField(
                label: 'Descrição',
                controller: descriptionController,
                maxLines: 4,
                hintText: 'Contexto, orientação técnica e observações iniciais',
              ),
            ],
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: AppTokens.space4),
          AppMessageBanner(
            message: error!,
            icon: Icons.error_outline_rounded,
            toneColor: Theme.of(context).colorScheme.error,
          ),
        ],
        const SizedBox(height: AppTokens.space5),
        ElevatedButton(
          onPressed: onSave,
          child: const Text('Salvar tarefa'),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
