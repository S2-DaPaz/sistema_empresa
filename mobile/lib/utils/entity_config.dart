import 'field_config.dart';

class EntityConfig {
  EntityConfig({
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
  final List<FieldConfig> fields;
  final String? hint;
  final String? emptyMessage;
}
