String buildBudgetEmailText(Map<String, dynamic> budget, Map<String, dynamic> client) {
  final lines = <String>[];
  lines.add('Orçamento #${budget['id']}');
  if (client['name'] != null) {
    lines.add('Cliente: ${client['name']}');
  }
  lines.add('');
  final items = budget['items'] as List<dynamic>? ?? [];
  for (final item in items) {
    if (item is! Map<String, dynamic>) continue;
    lines.add('- ${item['description']}: ${item['qty']} x ${item['unit_price']} = ${item['total']}');
  }
  lines.add('');
  lines.add('Total: ${budget['total'] ?? 0}');
  return lines.join('\n');
}

String extractEmail(String text) {
  final regex = RegExp(r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}', caseSensitive: false);
  final match = regex.firstMatch(text);
  return match?.group(0) ?? '';
}
