/// Constrói o texto plano de um relatório para compartilhamento.
String construirTextoRelatorio({
  required String tituloRelatorio,
  required String tituloTarefa,
  String? nomeCliente,
  String? nomeEquipamento,
  required List<dynamic> secoes,
  required Map<String, dynamic> respostas,
}) {
  String formatarResposta(Map<String, dynamic> campo, dynamic valor) {
    final tipo = campo['type'];
    if (tipo == 'checkbox') return valor == true ? 'Sim' : 'Não';
    if (tipo == 'yesno') {
      if (valor == 'sim') return 'Sim';
      if (valor == 'nao') return 'Não';
      return '-';
    }
    if (valor == 0 || valor == '0') return '0';
    return valor?.toString() ?? '-';
  }

  final linhas = <String>[];
  final titulo = tituloRelatorio.isNotEmpty ? tituloRelatorio : tituloTarefa;
  linhas.add('Relatório: $titulo');
  if (nomeCliente != null && nomeCliente.isNotEmpty) {
    linhas.add('Cliente: $nomeCliente');
  }
  if (nomeEquipamento != null && nomeEquipamento.isNotEmpty) {
    linhas.add('Equipamento: $nomeEquipamento');
  }
  linhas.add('');

  for (final secao in secoes) {
    if (secao is! Map<String, dynamic>) continue;
    linhas.add((secao['title'] ?? 'Seção').toString());
    final campos = secao['fields'];
    if (campos is List) {
      for (final campo in campos) {
        if (campo is! Map<String, dynamic>) continue;
        final rotulo = campo['label']?.toString() ?? 'Campo';
        final valor = respostas[campo['id']?.toString() ?? ''];
        linhas.add('- $rotulo: ${formatarResposta(campo, valor)}');
      }
    }
    linhas.add('');
  }

  return linhas.join('\n');
}
