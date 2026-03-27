import 'field_config.dart';

/// Configuração completa de uma entidade genérica (título, endpoint, campos).
class ConfiguracaoEntidade {
  ConfiguracaoEntidade({
    required this.title,
    required this.endpoint,
    required this.primaryField,
    required this.fields,
    this.hint,
    this.emptyMessage,
  });

  final String title;
  final String endpoint;
  final String primaryField;
  final List<ConfiguracaoCampo> fields;
  final String? hint;
  final String? emptyMessage;
}
