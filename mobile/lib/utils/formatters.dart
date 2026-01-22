import 'package:intl/intl.dart';

final _currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _dateFormatter = DateFormat('dd/MM/yyyy', 'pt_BR');

String formatCurrency(num? value) {
  return _currencyFormatter.format(value ?? 0);
}

String formatDate(String? value) {
  if (value == null || value.isEmpty) return '-';
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  return _dateFormatter.format(date);
}

String formatDateKey(String? value) {
  if (value == null || value.isEmpty) return '';
  return value.length >= 10 ? value.substring(0, 10) : value;
}

String formatMonthLabel(DateTime date) {
  return DateFormat('MMMM yyyy', 'pt_BR').format(date);
}
