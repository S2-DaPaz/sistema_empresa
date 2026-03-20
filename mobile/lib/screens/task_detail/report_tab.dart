import 'dart:convert';

import 'package:flutter/material.dart';

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
      padding: const EdgeInsets.all(16),
      children: [
        if (taskId == null)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Salve a tarefa para habilitar o Relatório.'),
            ),
          ),
        if (taskId != null && !selectedTemplateExists)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Este tipo de tarefa não possui modelo de Relatório.'),
            ),
          ),
        if (taskId != null && selectedTemplateExists)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Relatórios da tarefa',
                          style: Theme.of(context).textTheme.titleSmall),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton(onPressed: onCreateReport, child: const Text('Adicionar')),
                          OutlinedButton(onPressed: onDeleteReport, child: const Text('Excluir')),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  AppDropdownField<int>(
                    label: 'Relatório',
                    value: activeReportId,
                    items: reportOptions,
                    onChanged: onActiveReportChanged,
                  ),
                  const SizedBox(height: 8),
                  equipmentField,
                  const SizedBox(height: 8),
                  AppDropdownField<String>(
                    label: 'Status',
                    value: reportStatus,
                    items: const [
                      DropdownMenuItem(value: 'rascunho', child: Text('Rascunho')),
                      DropdownMenuItem(value: 'enviado', child: Text('Enviado')),
                      DropdownMenuItem(value: 'finalizado', child: Text('Finalizado')),
                    ],
                    onChanged: (value) => onReportStatusChanged(value ?? 'rascunho'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Fotos', style: Theme.of(context).textTheme.titleSmall),
                      OutlinedButton(onPressed: onAddPhotos, child: const Text('Adicionar')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (reportPhotos.isEmpty) const Text('Sem fotos anexadas.'),
                  if (reportPhotos.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: reportPhotos
                          .map((photo) => SizedBox(
                                width: 120,
                                child: Column(
                                  children: [
                                    Image.memory(
                                      base64Decode(photo['dataUrl']
                                          .toString()
                                          .split(',')
                                          .last),
                                      height: 90,
                                      fit: BoxFit.cover,
                                    ),
                                    TextButton(
                                      onPressed: () => onRemovePhoto(photo['id'].toString()),
                                      child: const Text('Remover'),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  const SizedBox(height: 12),
                  Text('Formulario', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  if (reportSections.isEmpty) const Text('Este modelo ainda não possui campos.'),
                  ...reportSections.map((section) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                section['title']?.toString() ?? 'Seção',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 8),
                              ...buildReportFields(section),
                            ],
                          ),
                        ),
                      )),
                  if (reportMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        reportMessage!,
                        style: const TextStyle(color: Colors.blueGrey),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton(onPressed: onSaveReport, child: const Text('Salvar Relatório')),
                      OutlinedButton(onPressed: onSendReportEmail, child: const Text('Enviar e-mail')),
                      OutlinedButton(onPressed: onSharePublicLink, child: const Text('Compartilhar link')),
                      OutlinedButton(onPressed: onOpenPublicPage, child: const Text('Abrir PDF')),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
