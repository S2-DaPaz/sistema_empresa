/// Aba "Detalhes" da tela de tarefa.
///
/// Exibe: card de resumo da tarefa, card do cliente (contato rápido),
/// barra de progresso (tarefa → relatório → orçamento → assinatura)
/// e o formulário de edição dos campos principais.
///
/// Recebe todo o estado e callbacks do [TaskDetailScreen] (parent).
/// Não possui estado próprio — é um widget puramente declarativo.
library;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../utils/contact_utils.dart';
import '../utils/formatters.dart';
import '../utils/label_mappers.dart';
import '../widgets/avatar_initials.dart';
import '../widgets/empty_state.dart';
import '../widgets/form_fields.dart';
import '../widgets/section_header.dart';
import '../widgets/status_chip.dart';
import 'task_detail_options.dart';

class TaskDetailDetailsTab extends StatelessWidget {
  const TaskDetailDetailsTab({
    super.key,
    required this.taskId,
    required this.status,
    required this.priority,
    required this.clientId,
    required this.userId,
    required this.taskTypeId,
    required this.titleController,
    required this.descriptionController,
    required this.startDateController,
    required this.dueDateController,
    required this.error,
    required this.clients,
    required this.users,
    required this.types,
    required this.reports,
    required this.budgets,
    required this.signatureMode,
    required this.signatureClient,
    required this.signatureTech,
    required this.signaturePages,
    required this.onStatusChanged,
    required this.onPriorityChanged,
    required this.onClientChanged,
    required this.onUserChanged,
    required this.onTaskTypeChanged,
    required this.onPickStartDate,
    required this.onPickDueDate,
    required this.onSaveTask,
    required this.onStartWork,
    required this.onLaunchContact,
  });

  final int? taskId;
  final String status;
  final String priority;
  final int? clientId;
  final int? userId;
  final int? taskTypeId;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController startDateController;
  final TextEditingController dueDateController;
  final String? error;
  final List<Map<String, dynamic>> clients;
  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> types;
  final List<Map<String, dynamic>> reports;
  final List<Map<String, dynamic>> budgets;
  final String signatureMode;
  final String signatureClient;
  final String signatureTech;
  final Map<String, dynamic> signaturePages;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onPriorityChanged;
  final ValueChanged<int?> onClientChanged;
  final ValueChanged<int?> onUserChanged;
  final ValueChanged<int?> onTaskTypeChanged;
  final VoidCallback onPickStartDate;
  final VoidCallback onPickDueDate;
  final VoidCallback onSaveTask;
  final VoidCallback? onStartWork;
  final void Function(String scheme, String value) onLaunchContact;

  Map<String, dynamic>? get _selectedClient {
    for (final client in clients) {
      if (client['id'] == clientId) return client;
    }
    return null;
  }

  List<Map<String, String>> _progressItems() {
    final hasTask = taskId != null;
    final hasReport = reports.isNotEmpty;
    final hasBudget = budgets.isNotEmpty;
    final hasSignature = signatureMode != 'none' &&
        ((signatureClient.isNotEmpty || signatureTech.isNotEmpty) ||
            signaturePages.isNotEmpty);

    return [
      {
        'title': 'Tarefa criada',
        'status': hasTask ? 'Concluído' : 'Pendente',
      },
      {
        'title': 'Relatório iniciado',
        'status': hasReport ? 'Concluído' : 'Pendente',
      },
      {
        'title': 'Orçamento vinculado',
        'status': hasBudget ? 'Concluído' : 'Pendente',
      },
      {
        'title': 'Assinaturas',
        'status': hasSignature ? 'Concluído' : 'Pendente',
      },
    ];
  }

  ButtonStyle get _compactOutlinedButtonStyle => OutlinedButton.styleFrom(
        minimumSize: const Size(0, 42),
      );

  @override
  Widget build(BuildContext context) {
    final client = _selectedClient;
    final clientName = client?['name']?.toString() ?? 'Sem cliente';
    final clientEmail = extrairEmail(client?['contact']?.toString());
    final clientPhone = extrairTelefone(client?['contact']?.toString());
    final clientAddress = client?['address']?.toString() ?? '';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusChip(
                      label: taskId == null
                          ? 'Nova tarefa'
                          : '#${taskId ?? '--'}',
                      compact: true,
                    ),
                    StatusChip(
                      label: labelStatusTarefa(status),
                      compact: true,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  titleController.text.isEmpty
                      ? 'Nova tarefa'
                      : titleController.text,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${formatarEntradaData(startDateController.text).isEmpty ? 'Sem início' : formatarEntradaData(startDateController.text)} • ${formatarEntradaData(dueDateController.text).isEmpty ? 'Sem prazo' : formatarEntradaData(dueDateController.text)}',
                      ),
                    ),
                  ],
                ),
                if (clientAddress.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(clientAddress)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AvatarInitials(name: clientName),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(clientName,
                              style: Theme.of(context).textTheme.titleMedium),
                          if (clientEmail.isNotEmpty)
                            Text(clientEmail,
                                style: Theme.of(context).textTheme.bodySmall),
                          if (clientPhone.isNotEmpty)
                            Text(clientPhone,
                                style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      style: _compactOutlinedButtonStyle,
                      onPressed: clientPhone.isEmpty
                          ? null
                          : () => onLaunchContact(
                                'tel:',
                                clientPhone.replaceAll(RegExp(r'[^0-9]'), ''),
                              ),
                      child: const Text('Ligar'),
                    ),
                    OutlinedButton(
                      style: _compactOutlinedButtonStyle,
                      onPressed: clientEmail.isEmpty
                          ? null
                          : () => onLaunchContact('mailto:', clientEmail),
                      child: const Text('E-mail'),
                    ),
                    OutlinedButton(
                      style: _compactOutlinedButtonStyle,
                      onPressed: clientPhone.isEmpty
                          ? null
                          : () => onLaunchContact(
                                'https://wa.me/',
                                clientPhone.replaceAll(RegExp(r'[^0-9]'), ''),
                              ),
                      child: const Text('WhatsApp'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const SectionHeader(
          title: 'Progresso',
          subtitle: 'Etapas ligadas à execução da tarefa',
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: _progressItems()
                  .map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Icon(
                              item['status'] == 'Concluído'
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: item['status'] == 'Concluído'
                                  ? AppColors.success
                                  : AppColors.muted,
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(item['title'] ?? 'Etapa')),
                            StatusChip(
                              label: item['status'] ?? 'Pendente',
                              compact: true,
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const SectionHeader(
          title: 'Editar tarefa',
          subtitle: 'Ajuste as informações operacionais',
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                AppTextField(label: 'Título', controller: titleController),
                const SizedBox(height: 8),
                AppDropdownField<String>(
                  label: 'Status',
                  value: status,
                  items: TaskDetailOptions.taskStatusItems,
                  onChanged: onStatusChanged,
                ),
                const SizedBox(height: 8),
                AppDropdownField<String>(
                  label: 'Prioridade',
                  value: priority,
                  items: TaskDetailOptions.taskPriorityItems,
                  onChanged: onPriorityChanged,
                ),
                const SizedBox(height: 8),
                AppDropdownField<int>(
                  label: 'Cliente',
                  value: clientId,
                  items: clients
                      .map((c) => DropdownMenuItem<int>(
                            value: c['id'] as int?,
                            child:
                                Text(c['name']?.toString() ?? 'Cliente'),
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
                              child:
                                  Text(user['name']?.toString() ?? 'Usuário'),
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
                Row(
                  children: [
                    Expanded(
                      child: AppDateField(
                        key: ValueKey(startDateController.text),
                        label: 'Data inicial',
                        value: formatarEntradaData(startDateController.text),
                        onTap: onPickStartDate,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppDateField(
                        key: ValueKey(dueDateController.text),
                        label: 'Prazo',
                        value: formatarEntradaData(dueDateController.text),
                        onTap: onPickDueDate,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                AppTextField(
                    label: 'Descrição',
                    controller: descriptionController,
                    maxLines: 4),
              ],
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child:
                Text(error!, style: const TextStyle(color: Colors.redAccent)),
          ),
        const SizedBox(height: 12),
        if (taskId == null &&
            titleController.text.isEmpty &&
            clientId == null &&
            descriptionController.text.isEmpty)
          const EmptyState(
            title: 'Preencha os dados principais',
            message:
                'Assim que salvar a tarefa você libera relatório, orçamento e assinaturas.',
            icon: Icons.assignment_outlined,
          ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onStartWork,
                child: const Text('Iniciar trabalho'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: onSaveTask,
                child: Text(
                    taskId == null ? 'Salvar tarefa' : 'Atualizar tarefa'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
