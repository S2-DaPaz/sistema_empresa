/// Aba "Relatório" da tela de tarefa.
///
/// Gerencia: seleção de relatório ativo, vínculo com equipamento,
/// status do relatório, galeria de fotos (base64) e formulário
/// dinâmico de campos (text, textarea, select, yesno, checkbox, date).
///
/// Toda mutação de estado é delegada ao parent via callbacks
/// (ex: [onReportAnswerChanged], [onAddPhotos]).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../utils/formatters.dart';
import '../widgets/form_fields.dart';
import 'task_detail_options.dart';

class TaskDetailReportTab extends StatelessWidget {
  const TaskDetailReportTab({
    super.key,
    required this.taskId,
    required this.clientId,
    required this.activeReportId,
    required this.reports,
    required this.reportSections,
    required this.reportAnswers,
    required this.reportPhotos,
    required this.reportStatus,
    required this.reportMessage,
    required this.reportEquipmentId,
    required this.equipments,
    required this.equipmentsLoading,
    required this.equipmentsError,
    required this.selectedTemplate,
    required this.onActiveReportChanged,
    required this.onReportStatusChanged,
    required this.onReportAnswerChanged,
    required this.onEquipmentChanged,
    required this.onAddPhotos,
    required this.onRemovePhoto,
    required this.onCreateReport,
    required this.onDeleteReport,
    required this.onSaveReport,
    required this.onSendEmail,
    required this.onShareLink,
    required this.onOpenPdf,
    required this.onRetryEquipments,
  });

  final int? taskId;
  final int? clientId;
  final int? activeReportId;
  final List<Map<String, dynamic>> reports;
  final List<Map<String, dynamic>> reportSections;
  final Map<String, dynamic> reportAnswers;
  final List<Map<String, dynamic>> reportPhotos;
  final String reportStatus;
  final String? reportMessage;
  final int? reportEquipmentId;
  final List<Map<String, dynamic>> equipments;
  final bool equipmentsLoading;
  final String? equipmentsError;
  final Map<String, dynamic>? selectedTemplate;
  final ValueChanged<int?> onActiveReportChanged;
  final ValueChanged<String?> onReportStatusChanged;
  final void Function(String fieldId, dynamic value) onReportAnswerChanged;
  final ValueChanged<int?> onEquipmentChanged;
  final VoidCallback onAddPhotos;
  final void Function(String photoId) onRemovePhoto;
  final VoidCallback onCreateReport;
  final VoidCallback onDeleteReport;
  final VoidCallback onSaveReport;
  final VoidCallback onSendEmail;
  final VoidCallback onShareLink;
  final VoidCallback onOpenPdf;
  final VoidCallback onRetryEquipments;

  ButtonStyle get _compactOutlinedButtonStyle => OutlinedButton.styleFrom(
        minimumSize: const Size(0, 42),
      );

  ButtonStyle get _compactElevatedButtonStyle => ElevatedButton.styleFrom(
        minimumSize: const Size(0, 42),
      );

  Uint8List? _tryDecodePhoto(String? dataUrl) {
    if (dataUrl == null || dataUrl.isEmpty) return null;
    try {
      return base64Decode(dataUrl.split(',').last);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportOptions = reports
        .map((report) => DropdownMenuItem<int>(
              value: report['id'] as int?,
              child: Text(
                report['title']?.toString() ??
                    (report['equipment_name'] != null
                        ? 'Relatório - ${report['equipment_name']}'
                        : 'Relatório'),
              ),
            ))
        .toList();

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
        if (taskId != null && selectedTemplate == null)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child:
                  Text('Este tipo de tarefa não possui modelo de Relatório.'),
            ),
          ),
        if (taskId != null && selectedTemplate != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Relatórios da tarefa',
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                              style: _compactOutlinedButtonStyle,
                              onPressed: onCreateReport,
                              child: const Text('Adicionar')),
                          OutlinedButton(
                              style: _compactOutlinedButtonStyle,
                              onPressed: onDeleteReport,
                              child: const Text('Excluir')),
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
                  _buildEquipmentField(context),
                  const SizedBox(height: 8),
                  AppDropdownField<String>(
                    label: 'Status',
                    value: reportStatus,
                    items: TaskDetailOptions.reportStatusItems,
                    onChanged: onReportStatusChanged,
                  ),
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Fotos',
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      OutlinedButton(
                          style: _compactOutlinedButtonStyle,
                          onPressed: onAddPhotos,
                          child: const Text('Adicionar')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (reportPhotos.isEmpty) const Text('Sem fotos anexadas.'),
                  if (reportPhotos.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: reportPhotos
                          .map((photo) => _buildPhotoTile(context, photo))
                          .toList(),
                    ),
                  const SizedBox(height: 12),
                  Text('Formulario',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  if (reportSections.isEmpty)
                    const Text('Este modelo ainda não possui campos.'),
                  ...reportSections.map((section) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(section['title']?.toString() ?? 'Seção',
                                  style:
                                      Theme.of(context).textTheme.titleSmall),
                              const SizedBox(height: 8),
                              ..._buildFormFields(context, section),
                            ],
                          ),
                        ),
                      )),
                  if (reportMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(reportMessage!,
                          style: const TextStyle(color: Colors.blueGrey)),
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton(
                          style: _compactElevatedButtonStyle,
                          onPressed: onSaveReport,
                          child: const Text('Salvar Relatório')),
                      OutlinedButton(
                          style: _compactOutlinedButtonStyle,
                          onPressed: onSendEmail,
                          child: const Text('Enviar e-mail')),
                      OutlinedButton(
                        style: _compactOutlinedButtonStyle,
                        onPressed: onShareLink,
                        child: const Text('Compartilhar link'),
                      ),
                      OutlinedButton(
                        style: _compactOutlinedButtonStyle,
                        onPressed: onOpenPdf,
                        child: const Text('Abrir PDF'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEquipmentField(BuildContext context) {
    final shouldDisable =
        clientId == null || equipmentsLoading || equipmentsError != null;
    final items = <DropdownMenuItem<int?>>[
      const DropdownMenuItem<int?>(value: null, child: Text('Sem equipamento')),
      ...equipments.map(
        (equipment) => DropdownMenuItem<int?>(
          value: equipment['id'] as int?,
          child: Text(equipment['name']?.toString() ?? 'Equipamento'),
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Opacity(
          opacity: shouldDisable ? 0.55 : 1,
          child: AbsorbPointer(
            absorbing: shouldDisable || activeReportId == null,
            child: AppDropdownField<int?>(
              label: 'Equipamento',
              value: reportEquipmentId,
              items: items,
              onChanged: onEquipmentChanged,
            ),
          ),
        ),
        if (clientId == null)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Selecione um cliente primeiro.'),
          ),
        if (activeReportId == null && clientId != null)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Selecione um relatório para vincular o equipamento.'),
          ),
        if (equipmentsLoading)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: LinearProgressIndicator(),
          ),
        if (clientId != null && !equipmentsLoading && equipmentsError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                const Expanded(child: Text('Erro ao carregar equipamentos.')),
                TextButton(
                  onPressed: onRetryEquipments,
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        if (clientId != null &&
            !equipmentsLoading &&
            equipmentsError == null &&
            equipments.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Nenhum equipamento encontrado para este cliente.'),
          ),
      ],
    );
  }

  Widget _buildPhotoTile(BuildContext context, Map<String, dynamic> photo) {
    final bytes = _tryDecodePhoto(photo['dataUrl']?.toString());

    return SizedBox(
      width: 120,
      child: Column(
        children: [
          Container(
            height: 90,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            clipBehavior: Clip.antiAlias,
            child: bytes == null
                ? Icon(
                    Icons.broken_image_outlined,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )
                : Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.broken_image_outlined,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
          ),
          TextButton(
            onPressed: () => onRemovePhoto(photo['id'].toString()),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFormFields(
      BuildContext context, Map<String, dynamic> section) {
    final fields = (section['fields'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    return fields.map((field) {
      final fieldId = field['id']?.toString() ?? '';
      final label = field['label']?.toString() ?? 'Campo';
      final type = field['type']?.toString() ?? 'text';
      final value = reportAnswers[fieldId];

      if (type == 'textarea') {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppTextField(
            key: ValueKey('field-${activeReportId ?? "new"}-$fieldId'),
            label: label,
            initialValue: value?.toString() ?? '',
            maxLines: 3,
            onChanged: (val) => onReportAnswerChanged(fieldId, val),
          ),
        );
      }
      if (type == 'select') {
        final options = (field['options'] as List<dynamic>? ?? [])
            .map((option) => DropdownMenuItem<String>(
                  value: option.toString(),
                  child: Text(
                    option.toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ))
            .toList();
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppDropdownField<String>(
            label: label,
            value: value?.toString(),
            items: options,
            onChanged: (val) => onReportAnswerChanged(fieldId, val),
          ),
        );
      }
      if (type == 'yesno') {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppDropdownField<String>(
            label: label,
            value: value?.toString(),
            items: const [
              DropdownMenuItem(value: 'sim', child: Text('Sim')),
              DropdownMenuItem(value: 'nao', child: Text('não')),
            ],
            onChanged: (val) => onReportAnswerChanged(fieldId, val),
          ),
        );
      }
      if (type == 'checkbox') {
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          value: value == true,
          onChanged: (val) => onReportAnswerChanged(fieldId, val),
        );
      }
      if (type == 'date') {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppDateField(
            key: ValueKey(
                'date-${activeReportId ?? "new"}-$fieldId-${value ?? ""}'),
            label: label,
            value: formatarEntradaData(value?.toString()),
            onTap: () async {
              final now = DateTime.now();
              final selected = await showDatePicker(
                context: context,
                firstDate: DateTime(now.year - 5),
                lastDate: DateTime(now.year + 5),
                initialDate: now,
              );
              if (selected == null) return;
              final formatted = formatarDataDeDate(selected);
              onReportAnswerChanged(fieldId, formatted);
            },
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AppTextField(
          key: ValueKey('field-${activeReportId ?? "new"}-$fieldId'),
          label: label,
          initialValue: value?.toString() ?? '',
          onChanged: (val) => onReportAnswerChanged(fieldId, val),
        ),
      );
    }).toList();
  }
}
