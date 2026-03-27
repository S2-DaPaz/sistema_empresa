/// Utilitários para extração de dados de contato a partir de strings livres.
library;

/// Extrai o primeiro endereço de e-mail encontrado em [valor].
String extrairEmail(String? valor) {
  if (valor == null || valor.trim().isEmpty) return '';
  final match = RegExp(
    r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}',
    caseSensitive: false,
  ).firstMatch(valor);
  return match?.group(0) ?? '';
}

/// Extrai e formata o primeiro telefone encontrado em [valor].
String extrairTelefone(String? valor) {
  if (valor == null || valor.trim().isEmpty) return '';
  final digitos = valor.replaceAll(RegExp(r'[^0-9]'), '');
  if (digitos.length < 10) return '';
  if (digitos.length == 11) {
    return '(${digitos.substring(0, 2)}) ${digitos.substring(2, 7)}-${digitos.substring(7)}';
  }
  return '(${digitos.substring(0, 2)}) ${digitos.substring(2, 6)}-${digitos.substring(6)}';
}

/// Retorna o primeiro nome de [valor], ou 'Equipe' se vazio.
String primeiroNomeDe(String? valor) {
  final limpo = (valor ?? '').trim();
  if (limpo.isEmpty) return 'Equipe';
  return limpo.split(RegExp(r'\s+')).first;
}
