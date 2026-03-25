/// Mapeamento centralizado de valores de domínio para labels de exibição.
///
/// Fonte única de verdade: [kDomainOptions] (gerado a partir de
/// packages/contracts/domain-options.json). Substitui as funções
/// _statusLabel / _priorityLabel que estavam duplicadas em 5+ telas.
library;

import '../core/contracts/generated/domain_options.g.dart';

/// Busca o label legível de [value] dentro da lista [optionKey].
/// Retorna [fallback] se o valor for nulo, vazio ou não encontrado.
String _resolve(String optionKey, String? value, String fallback) {
  if (value == null || value.isEmpty) return fallback;
  final options = kDomainOptions[optionKey];
  if (options == null) return fallback;
  for (final opt in options) {
    if (opt.value == value) return opt.label;
  }
  return fallback;
}

/// Ex: 'em_andamento' → 'Em andamento', null → 'Aberta'
String taskStatusLabel(String? value) =>
    _resolve('taskStatus', value, 'Aberta');

/// Ex: 'alta' → 'Alta', null → 'Média'
String taskPriorityLabel(String? value) =>
    _resolve('taskPriority', value, 'Média');

/// Ex: 'aprovado' → 'Aprovado', null → 'Em andamento'
String budgetStatusLabel(String? value) =>
    _resolve('budgetStatus', value, 'Em andamento');

/// Ex: 'finalizado' → 'Finalizado', null → 'Rascunho'
String reportStatusLabel(String? value) =>
    _resolve('reportStatus', value, 'Rascunho');

/// Ex: 'both' → 'Cliente e técnico', null → 'Sem assinatura'
String signatureModeLabel(String? value) =>
    _resolve('signatureMode', value, 'Sem assinatura');

/// Ex: 'all_pages' → 'Todas as páginas', null → 'Apenas ao final'
String signatureScopeLabel(String? value) =>
    _resolve('signatureScope', value, 'Apenas ao final');

/// Status da conta do usuário. Não está em domain-options.json
/// pois é exclusivo da tela de perfil (more_screen).
String accountStatusLabel(String? value) {
  switch (value) {
    case 'blocked':
      return 'Bloqueada';
    case 'pending_verification':
      return 'Pendente';
    default:
      return 'Ativa';
  }
}
