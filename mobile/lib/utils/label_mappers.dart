/// Mapeamento centralizado de valores de domínio para labels de exibição.
///
/// Fonte única de verdade: [kDomainOptions] (gerado a partir de
/// packages/contracts/domain-options.json). Substitui as funções
/// _statusLabel / _priorityLabel que estavam duplicadas em 5+ telas.
library;

import '../core/contracts/generated/domain_options.g.dart';

/// Busca o label legível de [valor] dentro da lista [chaveOpcao].
/// Retorna [padrao] se o valor for nulo, vazio ou não encontrado.
String _resolver(String chaveOpcao, String? valor, String padrao) {
  if (valor == null || valor.isEmpty) return padrao;
  final opcoes = kDomainOptions[chaveOpcao];
  if (opcoes == null) return padrao;
  for (final opt in opcoes) {
    if (opt.value == valor) return opt.label;
  }
  return padrao;
}

/// Ex: 'em_andamento' → 'Em andamento', null → 'Aberta'
String labelStatusTarefa(String? valor) =>
    _resolver('taskStatus', valor, 'Aberta');

/// Ex: 'alta' → 'Alta', null → 'Média'
String labelPrioridadeTarefa(String? valor) =>
    _resolver('taskPriority', valor, 'Média');

/// Ex: 'aprovado' → 'Aprovado', null → 'Em andamento'
String labelStatusOrcamento(String? valor) =>
    _resolver('budgetStatus', valor, 'Em andamento');

/// Ex: 'finalizado' → 'Finalizado', null → 'Rascunho'
String labelStatusRelatorio(String? valor) =>
    _resolver('reportStatus', valor, 'Rascunho');

/// Ex: 'both' → 'Cliente e técnico', null → 'Sem assinatura'
String labelModoAssinatura(String? valor) =>
    _resolver('signatureMode', valor, 'Sem assinatura');

/// Ex: 'all_pages' → 'Todas as páginas', null → 'Apenas ao final'
String labelEscopoAssinatura(String? valor) =>
    _resolver('signatureScope', valor, 'Apenas ao final');

/// Status da conta do usuário. Não está em domain-options.json
/// pois é exclusivo da tela de perfil (more_screen).
String labelStatusConta(String? valor) {
  switch (valor) {
    case 'blocked':
      return 'Bloqueada';
    case 'pending_verification':
      return 'Pendente';
    default:
      return 'Ativa';
  }
}
