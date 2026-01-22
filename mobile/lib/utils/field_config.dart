enum FieldType {
  text,
  number,
  select,
  textarea,
  checkbox,
  date,
}

class FieldOption {
  FieldOption({required this.value, required this.label});
  final dynamic value;
  final String label;
}

class FieldConfig {
  FieldConfig({
    required this.name,
    required this.label,
    required this.type,
    this.options = const [],
  });

  final String name;
  final String label;
  final FieldType type;
  final List<FieldOption> options;
}
