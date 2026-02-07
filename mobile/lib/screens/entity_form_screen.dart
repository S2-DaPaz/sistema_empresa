import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/entity_config.dart';
import '../utils/field_config.dart';
import '../utils/formatters.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/form_fields.dart';

class EntityFormScreen extends StatefulWidget {
  const EntityFormScreen({super.key, required this.config, this.item});

  final EntityConfig config;
  final Map<String, dynamic>? item;

  @override
  State<EntityFormScreen> createState() => _EntityFormScreenState();
}

class _EntityFormScreenState extends State<EntityFormScreen> {
  final ApiService _api = ApiService();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, dynamic> _values = {};
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.item != null && widget.item?['id'] != null;

  @override
  void initState() {
    super.initState();
    _initFields();
  }

  void _initFields() {
    for (final field in widget.config.fields) {
      final rawValue = widget.item?[field.name];
      switch (field.type) {
        case FieldType.text:
        case FieldType.textarea:
        case FieldType.number:
        case FieldType.date:
          _controllers[field.name] =
              TextEditingController(text: formatDateInput(rawValue?.toString()));
          break;
        case FieldType.select:
          _values[field.name] = rawValue;
          break;
        case FieldType.checkbox:
          _values[field.name] = rawValue == true;
          break;
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    final payload = <String, dynamic>{};
    for (final field in widget.config.fields) {
      switch (field.type) {
        case FieldType.text:
        case FieldType.textarea:
        case FieldType.date:
          payload[field.name] = parseDateBrToIso(_controllers[field.name]?.text.trim());
          break;
        case FieldType.number:
          final raw = _controllers[field.name]?.text.trim();
          payload[field.name] = raw == null || raw.isEmpty ? 0 : num.tryParse(raw) ?? 0;
          break;
        case FieldType.select:
          payload[field.name] = _values[field.name];
          break;
        case FieldType.checkbox:
          payload[field.name] = _values[field.name] == true;
          break;
      }
    }

    try {
      if (_isEdit) {
        await _api.put('${widget.config.endpoint}/${widget.item?['id']}', payload);
      } else {
        await _api.post(widget.config.endpoint, payload);
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _pickDate(FieldConfig field) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      initialDate: now,
    );
    if (selected == null) return;
    final formatted = formatDateFromDate(selected);
    _controllers[field.name]?.text = formatted;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _isEdit ? 'Editar ${widget.config.title}' : 'Novo ${widget.config.title}',
      body: ListView(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ...widget.config.fields.map((field) {
                    Widget fieldWidget;
                    switch (field.type) {
                      case FieldType.text:
                        fieldWidget = AppTextField(
                          label: field.label,
                          controller: _controllers[field.name],
                        );
                        break;
                      case FieldType.textarea:
                        fieldWidget = AppTextField(
                          label: field.label,
                          controller: _controllers[field.name],
                          maxLines: 4,
                        );
                        break;
                      case FieldType.number:
                        fieldWidget = AppTextField(
                          label: field.label,
                          controller: _controllers[field.name],
                          keyboardType: TextInputType.number,
                        );
                        break;
                      case FieldType.select:
                        fieldWidget = AppDropdownField<dynamic>(
                          label: field.label,
                          value: _values[field.name],
                          items: field.options
                              .map(
                                (option) => DropdownMenuItem(
                                  value: option.value,
                                  child: Text(option.label),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setState(() => _values[field.name] = value),
                        );
                        break;
                      case FieldType.checkbox:
                        fieldWidget = AppCheckboxField(
                          label: field.label,
                          value: _values[field.name] == true,
                          onChanged: (value) => setState(() => _values[field.name] = value ?? false),
                        );
                        break;
                      case FieldType.date:
                        fieldWidget = AppDateField(
                          key: ValueKey(_controllers[field.name]?.text ?? ''),
                          label: field.label,
                          value: formatDateInput(_controllers[field.name]?.text ?? ''),
                          onTap: () => _pickDate(field),
                        );
                        break;
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: fieldWidget,
                    );
                  }),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? 'Salvando...' : 'Salvar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
