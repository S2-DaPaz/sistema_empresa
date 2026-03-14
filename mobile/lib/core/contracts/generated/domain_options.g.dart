// GENERATED CODE - DO NOT MODIFY BY HAND.
// Source: packages/contracts/domain-options.json

class DomainOption {
  const DomainOption({required this.value, required this.label});

  final String value;
  final String label;
}

const Map<String, List<DomainOption>> kDomainOptions = {
  'taskStatus': [
      DomainOption(value: 'aberta', label: 'Aberta'),
      DomainOption(value: 'em_andamento', label: 'Em andamento'),
      DomainOption(value: 'concluida', label: 'Concluída'),
  ],
  'taskPriority': [
      DomainOption(value: 'alta', label: 'Alta'),
      DomainOption(value: 'media', label: 'Média'),
      DomainOption(value: 'baixa', label: 'Baixa'),
  ],
  'reportStatus': [
      DomainOption(value: 'rascunho', label: 'Rascunho'),
      DomainOption(value: 'enviado', label: 'Enviado'),
      DomainOption(value: 'finalizado', label: 'Finalizado'),
  ],
  'budgetStatus': [
      DomainOption(value: 'em_andamento', label: 'Em andamento'),
      DomainOption(value: 'aprovado', label: 'Aprovado'),
      DomainOption(value: 'recusado', label: 'Recusado'),
  ],
  'signatureMode': [
      DomainOption(value: 'none', label: 'Sem assinatura'),
      DomainOption(value: 'client', label: 'Cliente'),
      DomainOption(value: 'tech', label: 'Técnico'),
      DomainOption(value: 'both', label: 'Cliente e técnico'),
  ],
  'signatureScope': [
      DomainOption(value: 'all_pages', label: 'Todas as páginas'),
      DomainOption(value: 'last_page', label: 'Apenas ao final'),
  ],
};
