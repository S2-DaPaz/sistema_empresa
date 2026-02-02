import 'package:intl/intl.dart';

final _currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _dateFormatter = DateFormat('dd/MM/yyyy', 'pt_BR');
final _isoDateFormatter = DateFormat('yyyy-MM-dd', 'en_US');

String formatCurrency(num? value) {
  return _currencyFormatter.format(value ?? 0);
}

String formatDate(String? value) {
  if (value == null || value.isEmpty) return '-';
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  return _dateFormatter.format(date);
}

String formatDateInput(String? value) {
  if (value == null || value.isEmpty) return '';
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  return _dateFormatter.format(date);
}

String formatDateFromDate(DateTime date) {
  return _dateFormatter.format(date);
}

String parseDateBrToIso(String? value) {
  if (value == null || value.isEmpty) return '';
  final normalized = value.trim();
  final brMatch = RegExp(r'^(\d{2})\/(\d{2})\/(\d{4})$').firstMatch(normalized);
  if (brMatch != null) {
    final day = brMatch.group(1)!;
    final month = brMatch.group(2)!;
    final year = brMatch.group(3)!;
    return '$year-$month-$day';
  }
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(normalized)) {
    return normalized;
  }
  final parsed = DateTime.tryParse(normalized);
  if (parsed != null) {
    return _isoDateFormatter.format(parsed);
  }
  return normalized;
}

String formatDateKey(String? value) {
  if (value == null || value.isEmpty) return '';
  return value.length >= 10 ? value.substring(0, 10) : value;
}

String formatMonthLabel(DateTime date) {
  return DateFormat('MMMM yyyy', 'pt_BR').format(date);
}
