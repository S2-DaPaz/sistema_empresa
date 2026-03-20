import 'package:flutter/material.dart';

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
      padding: const EdgeInsets.all(16),
      children: [
        AppTextField(label: 'Título', controller: titleController),
        const SizedBox(height: 8),
        AppDropdownField<String>(
          label: 'Status',
          value: status,
          items: const [
            DropdownMenuItem(value: 'aberta', child: Text('Aberta')),
            DropdownMenuItem(value: 'em_andamento', child: Text('Em andamento')),
            DropdownMenuItem(value: 'concluida', child: Text('Concluída')),
          ],
          onChanged: (value) => onStatusChanged(value ?? 'aberta'),
        ),
        const SizedBox(height: 8),
        AppDropdownField<String>(
          label: 'Prioridade',
          value: priority,
          items: const [
            DropdownMenuItem(value: 'alta', child: Text('Alta')),
            DropdownMenuItem(value: 'media', child: Text('Média')),
            DropdownMenuItem(value: 'baixa', child: Text('Baixa')),
          ],
          onChanged: (value) => onPriorityChanged(value ?? 'media'),
        ),
        const SizedBox(height: 8),
        AppDropdownField<int>(
          label: 'Cliente',
          value: clientId,
          items: clients
              .map((client) => DropdownMenuItem<int>(
                    value: client['id'] as int?,
                    child: Text(client['name']?.toString() ?? 'Cliente'),
                  ))
              .toList(),
          onChanged: onClientChanged,
        ),
        const SizedBox(height: 8),
        if (users.isNotEmpty) ...[
          AppDropdownField<int>(
            label: 'Responsável',
            value: userId,
            items: users
                .map((user) => DropdownMenuItem<int>(
                      value: user['id'] as int?,
                      child: Text(user['name']?.toString() ?? 'Usuário'),
                    ))
                .toList(),
            onChanged: onUserChanged,
          ),
          const SizedBox(height: 8),
        ],
        AppDropdownField<int>(
          label: 'Tipo de tarefa',
          value: taskTypeId,
          items: types
              .map((type) => DropdownMenuItem<int>(
                    value: type['id'] as int?,
                    child: Text(type['name']?.toString() ?? 'Tipo'),
                  ))
              .toList(),
          onChanged: onTaskTypeChanged,
        ),
        const SizedBox(height: 8),
        AppDateField(
          key: ValueKey(startDateController.text),
          label: 'Inicio',
          value: startDateController.text,
          onTap: onPickStartDate,
        ),
        const SizedBox(height: 8),
        AppDateField(
          key: ValueKey(dueDateController.text),
          label: 'Fim',
          value: dueDateController.text,
          onTap: onPickDueDate,
        ),
        const SizedBox(height: 8),
        AppTextField(label: 'Descrição', controller: descriptionController, maxLines: 3),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(error!, style: const TextStyle(color: Colors.redAccent)),
          ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: onSave,
          child: const Text('Salvar tarefa'),
        ),
      ],
    );
  }
}
