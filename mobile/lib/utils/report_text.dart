String buildReportText({
  required String reportTitle,
  required String taskTitle,
  String? clientName,
  String? equipmentName,
  required List<dynamic> sections,
  required Map<String, dynamic> answers,
}) {
  String formatAnswer(Map<String, dynamic> field, dynamic value) {
    final type = field['type'];
    if (type == 'checkbox') return value == true ? 'Sim' : 'Não';
    if (type == 'yesno') {
      if (value == 'sim') return 'Sim';
      if (value == 'nao') return 'Não';
      return '-';
    }
    if (value == 0 || value == '0') return '0';
    return value?.toString() ?? '-';
  }

  final lines = <String>[];
  final title = reportTitle.isNotEmpty ? reportTitle : taskTitle;
  lines.add('Relatório: $title');
  if (clientName != null && clientName.isNotEmpty) {
    lines.add('Cliente: $clientName');
  }
  if (equipmentName != null && equipmentName.isNotEmpty) {
    lines.add('Equipamento: $equipmentName');
  }
  lines.add('');

  for (final section in sections) {
    if (section is! Map<String, dynamic>) continue;
    lines.add((section['title'] ?? 'Seção').toString());
    final fields = section['fields'];
    if (fields is List) {
      for (final field in fields) {
        if (field is! Map<String, dynamic>) continue;
        final label = field['label']?.toString() ?? 'Campo';
        final value = answers[field['id']?.toString() ?? ''];
        lines.add('- $label: ${formatAnswer(field, value)}');
      }
    }
    lines.add('');
  }

  return lines.join('\n');
}
