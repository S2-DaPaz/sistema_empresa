/// Constrói o texto do e-mail de orçamento para envio ao cliente.
String construirTextoEmailOrcamento(
    Map<String, dynamic> orcamento, Map<String, dynamic> cliente) {
  final linhas = <String>[];
  linhas.add('Orçamento #${orcamento['id']}');
  if (cliente['name'] != null) {
    linhas.add('Cliente: ${cliente['name']}');
  }
  linhas.add('');
  final itens = orcamento['items'] as List<dynamic>? ?? [];
  for (final item in itens) {
    if (item is! Map<String, dynamic>) continue;
    linhas.add(
        '- ${item['description']}: ${item['qty']} x ${item['unit_price']} = ${item['total']}');
  }
  linhas.add('');
  linhas.add('Total: ${orcamento['total'] ?? 0}');
  return linhas.join('\n');
}

/// Extrai o primeiro e-mail encontrado em [texto].
String extrairEmailDeTexto(String texto) {
  final regex =
      RegExp(r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}', caseSensitive: false);
  final match = regex.firstMatch(texto);
  return match?.group(0) ?? '';
}
