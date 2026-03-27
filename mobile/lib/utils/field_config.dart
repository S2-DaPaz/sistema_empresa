/// Tipos de campo suportados pelo formulário genérico de entidades.
enum TipoCampo {
  text,
  number,
  select,
  textarea,
  checkbox,
  date,
}

/// Opção individual de um campo do tipo select.
class OpcaoCampo {
  OpcaoCampo({required this.value, required this.label});
  final dynamic value;
  final String label;
}

/// Configuração de um campo de formulário (nome, rótulo, tipo e opções).
class ConfiguracaoCampo {
  ConfiguracaoCampo({
    required this.name,
    required this.label,
    required this.type,
    this.options = const [],
    this.formatter,
  });

  final String name;
  final String label;
  final TipoCampo type;
  final List<OpcaoCampo> options;
  final String Function(dynamic value)? formatter;
}
