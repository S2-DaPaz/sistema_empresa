import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/form_fields.dart';
import '../../widgets/signature_pad.dart';

class TaskSignaturesTab extends StatelessWidget {
  const TaskSignaturesTab({
    super.key,
    required this.taskId,
    required this.signatureMode,
    required this.signatureScope,
    required this.signatureClient,
    required this.signatureTech,
    required this.signaturePages,
    required this.signaturePageItems,
    required this.onSignatureModeChanged,
    required this.onSignatureScopeChanged,
    required this.onSignatureClientChanged,
    required this.onSignatureTechChanged,
    required this.onUpdateSignaturePage,
    required this.onSave,
  });

  final int? taskId;
  final String signatureMode;
  final String signatureScope;
  final String signatureClient;
  final String signatureTech;
  final Map<String, dynamic> signaturePages;
  final List<Map<String, String>> signaturePageItems;
  final ValueChanged<String> onSignatureModeChanged;
  final ValueChanged<String> onSignatureScopeChanged;
  final ValueChanged<String> onSignatureClientChanged;
  final ValueChanged<String> onSignatureTechChanged;
  final void Function(String key, String role, String value) onUpdateSignaturePage;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppTokens.space4),
      children: [
        if (taskId == null)
          const EmptyStateCard(
            title: 'Salve a tarefa para habilitar as assinaturas',
            subtitle: 'O fechamento do atendimento precisa da tarefa registrada.',
          ),
        if (taskId != null) ...[
          AppSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assinaturas e entrega',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Fechamento do atendimento, comprovação e envio de documento.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppTokens.space4),
                AppDropdownField<String>(
                  label: 'Assinaturas necessárias',
                  value: signatureMode,
                  items: const [
                    DropdownMenuItem(
                      value: 'none',
                      child: Text('Sem assinatura'),
                    ),
                    DropdownMenuItem(
                      value: 'client',
                      child: Text('Cliente'),
                    ),
                    DropdownMenuItem(
                      value: 'tech',
                      child: Text('Técnico'),
                    ),
                    DropdownMenuItem(
                      value: 'both',
                      child: Text('Cliente e técnico'),
                    ),
                  ],
                  onChanged: (value) => onSignatureModeChanged(value ?? 'none'),
                ),
                const SizedBox(height: AppTokens.space4),
                AppDropdownField<String>(
                  label: 'Aplicação',
                  value: signatureScope,
                  items: const [
                    DropdownMenuItem(
                      value: 'last_page',
                      child: Text('Apenas ao final'),
                    ),
                    DropdownMenuItem(
                      value: 'all_pages',
                      child: Text('Todas as páginas'),
                    ),
                  ],
                  onChanged: (value) =>
                      onSignatureScopeChanged(value ?? 'last_page'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space4),
          if (signatureScope == 'last_page') ...[
            if (signatureMode == 'client' || signatureMode == 'both')
              AppSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assinatura do cliente',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppTokens.space4),
                    SignaturePadField(
                      label: 'Assinatura do cliente*',
                      value: signatureClient,
                      onChanged: onSignatureClientChanged,
                    ),
                    if (signatureClient.isNotEmpty)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => onSignatureClientChanged(''),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Remover assinatura'),
                        ),
                      ),
                  ],
                ),
              ),
            if (signatureMode == 'client' || signatureMode == 'both')
              const SizedBox(height: AppTokens.space4),
            if (signatureMode == 'tech' || signatureMode == 'both')
              AppSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assinatura do técnico',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppTokens.space4),
                    SignaturePadField(
                      label: 'Assinatura do técnico*',
                      value: signatureTech,
                      onChanged: onSignatureTechChanged,
                    ),
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
                ),
              ),
          ],
          if (signatureScope == 'all_pages' && signatureMode != 'none') ...[
            ...signaturePageItems.map((page) {
              final key = page['key']!;
              final label = page['label']!;
              final pageSignatures =
                  signaturePages[key] as Map<String, dynamic>? ?? {};
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: AppTokens.space4),
                      if (signatureMode == 'client' || signatureMode == 'both')
                        SignaturePadField(
                          label: 'Assinatura do cliente*',
                          value: pageSignatures['client']?.toString() ?? '',
                          onChanged: (value) =>
                              onUpdateSignaturePage(key, 'client', value),
                        ),
                      if ((signatureMode == 'client' ||
                              signatureMode == 'both') &&
                          (pageSignatures['client']?.toString() ?? '')
                              .isNotEmpty)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () =>
                                onUpdateSignaturePage(key, 'client', ''),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Remover assinatura'),
                          ),
                        ),
                      const SizedBox(height: AppTokens.space4),
                      if (signatureMode == 'tech' || signatureMode == 'both')
                        SignaturePadField(
                          label: 'Assinatura do técnico*',
                          value: pageSignatures['tech']?.toString() ?? '',
                          onChanged: (value) =>
                              onUpdateSignaturePage(key, 'tech', value),
                        ),
                      if ((signatureMode == 'tech' || signatureMode == 'both') &&
                          (pageSignatures['tech']?.toString() ?? '')
                              .isNotEmpty)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () =>
                                onUpdateSignaturePage(key, 'tech', ''),
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
          const SizedBox(height: AppTokens.space5),
          ElevatedButton(
            onPressed: onSave,
            child: const Text('Salvar assinaturas'),
          ),
        ],
      ],
    );
  }
}
