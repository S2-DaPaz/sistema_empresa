/// Aba "Assinaturas" da tela de tarefa.
///
/// Configuração: modo (cliente, técnico, ambos), escopo (última página
/// ou todas) e os pads de assinatura correspondentes.
///
/// Quando escopo = "all_pages", renderiza um pad por relatório/orçamento.
/// Quando escopo = "last_page", renderiza apenas os pads globais.
library;

import 'package:flutter/material.dart';

import '../widgets/form_fields.dart';
import '../widgets/signature_pad.dart';
import 'task_detail_options.dart';

class TaskDetailSignaturesTab extends StatelessWidget {
  const TaskDetailSignaturesTab({
    super.key,
    required this.taskId,
    required this.signatureMode,
    required this.signatureScope,
    required this.signatureClient,
    required this.signatureTech,
    required this.signaturePages,
    required this.reports,
    required this.budgets,
    required this.onSignatureModeChanged,
    required this.onSignatureScopeChanged,
    required this.onSignatureClientChanged,
    required this.onSignatureTechChanged,
    required this.onSignaturePageChanged,
    required this.onSave,
  });

  final int? taskId;
  final String signatureMode;
  final String signatureScope;
  final String signatureClient;
  final String signatureTech;
  final Map<String, dynamic> signaturePages;
  final List<Map<String, dynamic>> reports;
  final List<Map<String, dynamic>> budgets;
  final ValueChanged<String?> onSignatureModeChanged;
  final ValueChanged<String?> onSignatureScopeChanged;
  final ValueChanged<String> onSignatureClientChanged;
  final ValueChanged<String> onSignatureTechChanged;
  final void Function(String key, String role, String value)
      onSignaturePageChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final signaturePageItems = [
      ...reports.map((report) => {
            'key': 'report:${report['id']}',
            'label': report['title']?.toString() ??
                (report['equipment_name'] != null
                    ? 'Relatório - ${report['equipment_name']}'
                    : 'Relatório'),
          }),
      ...budgets.map((budget) => {
            'key': 'budget:${budget['id']}',
            'label': 'orçamento #${budget['id']}',
          }),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (taskId == null)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Salve a tarefa para configurar Assinaturas.'),
            ),
          ),
        if (taskId != null) ...[
          AppDropdownField<String>(
            label: 'Assinaturas',
            value: signatureMode,
            items: TaskDetailOptions.signatureModeItems,
            onChanged: onSignatureModeChanged,
          ),
          const SizedBox(height: 8),
          AppDropdownField<String>(
            label: 'Aplicação',
            value: signatureScope,
            items: TaskDetailOptions.signatureScopeItems,
            onChanged: onSignatureScopeChanged,
          ),
          const SizedBox(height: 12),
          if (signatureScope == 'last_page') ...[
            if (signatureMode == 'client' || signatureMode == 'both')
              SignaturePadField(
                label: 'Assinatura do cliente*',
                value: signatureClient,
                onChanged: onSignatureClientChanged,
              ),
            if (signatureMode == 'client' || signatureMode == 'both')
              if (signatureClient.isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => onSignatureClientChanged(''),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remover assinatura'),
                  ),
                ),
            const SizedBox(height: 12),
            if (signatureMode == 'tech' || signatureMode == 'both')
              SignaturePadField(
                label: 'Assinatura do técnico*',
                value: signatureTech,
                onChanged: onSignatureTechChanged,
              ),
            if (signatureMode == 'tech' || signatureMode == 'both')
              if (signatureTech.isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => onSignatureTechChanged(''),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remover assinatura'),
                  ),
                ),
          ],
          if (signatureScope == 'all_pages' && signatureMode != 'none') ...[
            ...signaturePageItems.map((page) {
              final key = page['key'] as String;
              final label = page['label'] as String;
              final pageSignatures =
                  signaturePages[key] as Map<String, dynamic>? ?? {};
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      if (signatureMode == 'client' || signatureMode == 'both')
                        SignaturePadField(
                          label: 'Assinatura do cliente*',
                          value: pageSignatures['client']?.toString() ?? '',
                          onChanged: (value) =>
                              onSignaturePageChanged(key, 'client', value),
                        ),
                      if (signatureMode == 'client' || signatureMode == 'both')
                        if ((pageSignatures['client']?.toString() ?? '')
                            .isNotEmpty)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () =>
                                  onSignaturePageChanged(key, 'client', ''),
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Remover assinatura'),
                            ),
                          ),
                      const SizedBox(height: 12),
                      if (signatureMode == 'tech' || signatureMode == 'both')
                        SignaturePadField(
                          label: 'Assinatura do técnico*',
                          value: pageSignatures['tech']?.toString() ?? '',
                          onChanged: (value) =>
                              onSignaturePageChanged(key, 'tech', value),
                        ),
                      if (signatureMode == 'tech' || signatureMode == 'both')
                        if ((pageSignatures['tech']?.toString() ?? '')
                            .isNotEmpty)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () =>
                                  onSignaturePageChanged(key, 'tech', ''),
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Remover assinatura'),
                            ),
                          ),
                    ],
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onSave,
            child: const Text('Salvar assinaturas'),
          ),
        ],
      ],
    );
  }
}
