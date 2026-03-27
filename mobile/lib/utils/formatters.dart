import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Formatadores reutilizáveis de moeda e data para o padrão brasileiro (pt-BR).

final _formatadorMoeda =
    NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _formatadorData = DateFormat('dd/MM/yyyy', 'pt_BR');
final _formatadorDataHora = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');
final _formatadorDataIso = DateFormat('yyyy-MM-dd', 'en_US');

/// Formata um valor numérico como moeda brasileira (R$).
String formatarMoeda(num? valor) {
  return _formatadorMoeda.format(valor ?? 0);
}

/// Formata uma string ISO em data legível (dd/MM/yyyy). Retorna '-' se vazio.
String formatarData(String? valor) {
  if (valor == null || valor.isEmpty) return '-';
  final data = DateTime.tryParse(valor);
  if (data == null) return valor;
  return _formatadorData.format(data);
}

/// Formata uma string ISO em data e hora legíveis (dd/MM/yyyy HH:mm).
String formatarDataHora(String? valor) {
  if (valor == null || valor.isEmpty) return '-';
  final data = DateTime.tryParse(valor);
  if (data == null) return valor;
  return _formatadorDataHora.format(data);
}

/// Formata data para exibição em campos de entrada; retorna vazio em vez de '-'.
String formatarEntradaData(String? valor) {
  if (valor == null || valor.isEmpty) return '';
  final data = DateTime.tryParse(valor);
  if (data == null) return valor;
  return _formatadorData.format(data);
}

/// Formata um objeto DateTime diretamente em string dd/MM/yyyy.
String formatarDataDeDate(DateTime data) {
  return _formatadorData.format(data);
}

/// Converte uma string de moeda formatada (ex.: "R$ 1.234,56") em double.
double converterMoeda(String valor) {
  if (valor.isEmpty) return 0;
  // Remove tudo que não é dígito para extrair o valor em centavos
  final digitos = valor.replaceAll(RegExp(r'[^\d]'), '');
  if (digitos.isEmpty) return 0;
  return (int.parse(digitos) / 100);
}

/// Formatter para campos de texto que aplica máscara de moeda em tempo real.
class FormatadorEntradaMoeda extends TextInputFormatter {
  FormatadorEntradaMoeda({NumberFormat? formatador})
      : _formatador = formatador ?? _formatadorMoeda;

  final NumberFormat _formatador;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue valorAntigo,
    TextEditingValue valorNovo,
  ) {
    // Extrai apenas os dígitos da entrada para recalcular o valor monetário
    final digitos = valorNovo.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digitos.isEmpty) {
      return const TextEditingValue(text: '');
    }
    final valor = int.parse(digitos) / 100;
    final textoFormatado = _formatador.format(valor);
    return TextEditingValue(
      text: textoFormatado,
      selection: TextSelection.collapsed(offset: textoFormatado.length),
    );
  }
}

/// Converte data no formato BR (dd/MM/yyyy) ou outros formatos para ISO (yyyy-MM-dd).
String converterDataBrParaIso(String? valor) {
  if (valor == null || valor.isEmpty) return '';
  final normalizado = valor.trim();

  // Tenta fazer match com formato brasileiro dd/MM/yyyy
  final matchBr = RegExp(r'^(\d{2})\/(\d{2})\/(\d{4})$').firstMatch(normalizado);
  if (matchBr != null) {
    final dia = matchBr.group(1)!;
    final mes = matchBr.group(2)!;
    final ano = matchBr.group(3)!;
    return '$ano-$mes-$dia';
  }

  // Se já está em formato ISO, retorna como está
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(normalizado)) {
    return normalizado;
  }

  // Tenta parse genérico como fallback
  final dataParsed = DateTime.tryParse(normalizado);
  if (dataParsed != null) {
    return _formatadorDataIso.format(dataParsed);
  }
  return normalizado;
}

/// Extrai a parte da data (primeiros 10 caracteres, yyyy-MM-dd) de uma string ISO.
String formatarChaveData(String? valor) {
  if (valor == null || valor.isEmpty) return '';
  return valor.length >= 10 ? valor.substring(0, 10) : valor;
}

/// Formata um DateTime como rótulo de mês por extenso (ex.: "março 2026").
String formatarRotuloMes(DateTime data) {
  return DateFormat('MMMM yyyy', 'pt_BR').format(data);
}
