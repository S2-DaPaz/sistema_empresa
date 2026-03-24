String extractEmail(String? value) {
  if (value == null || value.trim().isEmpty) return '';
  final match = RegExp(
    r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}',
    caseSensitive: false,
  ).firstMatch(value);
  return match?.group(0) ?? '';
}

String extractPhone(String? value) {
  if (value == null || value.trim().isEmpty) return '';
  final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length < 10) return '';
  if (digits.length == 11) {
    return '(${digits.substring(0, 2)}) ${digits.substring(2, 7)}-${digits.substring(7)}';
  }
  return '(${digits.substring(0, 2)}) ${digits.substring(2, 6)}-${digits.substring(6)}';
}

String firstNameOf(String? value) {
  final trimmed = (value ?? '').trim();
  if (trimmed.isEmpty) return 'Equipe';
  return trimmed.split(RegExp(r'\s+')).first;
}
