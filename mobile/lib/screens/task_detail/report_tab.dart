import 'dart:convert';

import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/form_fields.dart';

class TaskReportTab extends StatelessWidget {
  const TaskReportTab({
    super.key,
    required this.taskId,
    required this.selectedTemplateExists,
    required this.reportOptions,
    required this.activeReportId,
    required this.onActiveReportChanged,
    required this.reportStatus,
    required this.onReportStatusChanged,
    required this.equipmentField,
    required this.reportPhotos,
    required this.onAddPhotos,
    required this.onRemovePhoto,
    required this.reportSections,
    required this.buildReportFields,
    required this.reportMessage,
    required this.onCreateReport,
    required this.onDeleteReport,
    required this.onSaveReport,
    required this.onSendReportEmail,
    required this.onSharePublicLink,
    required this.onOpenPublicPage,
  });

  final int? taskId;
  final bool selectedTemplateExists;
  final List<DropdownMenuItem<int>> reportOptions;
  final int? activeReportId;
  final ValueChanged<int?> onActiveReportChanged;
  final String reportStatus;
  final ValueChanged<String> onReportStatusChanged;
  final Widget equipmentField;
  final List<Map<String, dynamic>> reportPhotos;
  final VoidCallback onAddPhotos;
  final ValueChanged<String> onRemovePhoto;
  final List<Map<String, dynamic>> reportSections;
  final List<Widget> Function(Map<String, dynamic> section) buildReportFields;
  final String? reportMessage;
  final VoidCallback onCreateReport;
  final VoidCallback onDeleteReport;
  final VoidCallback onSaveReport;
  final VoidCallback onSendReportEmail;
  final VoidCallback onSharePublicLink;
  final VoidCallback onOpenPublicPage;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppTokens.space4),
      children: [
        if (taskId == null)
          const EmptyStateCard(
            title: 'Salve a tarefa para começar',
            subtitle: 'O relatório técnico é liberado depois que a tarefa recebe um registro.',
          ),
        if (taskId != null && !selectedTemplateExists)
          const EmptyStateCard(
            title: 'Nenhum modelo disponível',
            subtitle: 'Este tipo de tarefa ainda não possui um modelo de relatório aplicado.',
          ),
        if (taskId != null && selectedTemplateExists) ...[
          AppSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Relatório técnico',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    OutlinedButton(
                      onPressed: onCreateReport,
                      child: const Text('Adicionar'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: onDeleteReport,
                      child: const Text('Excluir'),
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.space4),
                AppDropdownField<int>(
                  label: 'Relatório ativo',
                  value: activeReportId,
                  items: reportOptions,
                  onChanged: onActiveReportChanged,
                ),
                const SizedBox(height: AppTokens.space4),
                equipmentField,
                const SizedBox(height: AppTokens.space4),
                AppDropdownField<String>(
                  label: 'Status do relatório',
                  value: reportStatus,
                  items: const [
                    DropdownMenuItem(value: 'rascunho', child: Text('Rascunho')),
                    DropdownMenuItem(value: 'enviado', child: Text('Enviado')),
                    DropdownMenuItem(
                      value: 'finalizado',
                      child: Text('Finalizado'),
                    ),
                  ],
                  onChanged: (value) => onReportStatusChanged(value ?? 'rascunho'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space4),
          AppSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Evidências',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    OutlinedButton(
                      onPressed: onAddPhotos,
                      child: const Text('Adicionar foto'),
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.space4),
                if (reportPhotos.isEmpty)
                  const Text('Nenhuma evidência anexada até o momento.'),
                if (reportPhotos.isNotEmpty)
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: reportPhotos
                        .map(
                          (photo) => SizedBox(
                            width: 120,
                            child: AppSurface(
                              padding: const EdgeInsets.all(8),
                              radius: AppTokens.radiusSm,
                              shadow: const [],
                              child: Column(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.memory(
                                      base64Decode(
                                        photo['dataUrl']
                                            .toString()
                                            .split(',')
                                            .last,
                                      ),
                                      height: 90,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () =>
                                        onRemovePhoto(photo['id'].toString()),
                                    child: const Text('Remover'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space4),
          const AppSectionBlock(
            title: 'Formulário técnico',
            subtitle: 'Campos estruturados para diagnóstico, execução e evidências.',
          ),
          const SizedBox(height: AppTokens.space4),
          if (reportSections.isEmpty)
            const EmptyStateCard(
              title: 'Modelo sem campos configurados',
              subtitle: 'Ajuste o template para liberar o preenchimento do relatório.',
            ),
          ...reportSections.map(
            (section) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section['title']?.toString() ?? 'Seção',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppTokens.space4),
                    ...buildReportFields(section),
                  ],
                ),
              ),
            ),
          ),
          if (reportMessage != null) ...[
            const SizedBox(height: AppTokens.space3),
            Text(
              reportMessage!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AppTokens.space5),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton(
                onPressed: onSaveReport,
                child: const Text('Salvar relatório'),
              ),
              OutlinedButton(
                onPressed: onSendReportEmail,
                child: const Text('Enviar por e-mail'),
              ),
              OutlinedButton(
                onPressed: onSharePublicLink,
                child: const Text('Compartilhar'),
              ),
              OutlinedButton(
                onPressed: onOpenPublicPage,
                child: const Text('Abrir PDF'),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }
}
