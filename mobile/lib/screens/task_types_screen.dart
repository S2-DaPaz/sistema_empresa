import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/entity_config.dart';
import '../utils/field_config.dart';
import '../widgets/loading_view.dart';
import 'entity_list_screen.dart';

class TaskTypesScreen extends StatefulWidget {
  const TaskTypesScreen({super.key});

  @override
  State<TaskTypesScreen> createState() => _TaskTypesScreenState();
}

class _TaskTypesScreenState extends State<TaskTypesScreen> {
  final ApiService _api = ApiService();
  bool _loading = true;
  List<FieldOption> _templateOptions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _api.get('/report-templates') as List<dynamic>;
      final options = data
          .map((item) => FieldOption(
                value: (item as Map<String, dynamic>)['id'],
                label: item['name']?.toString() ?? 'Modelo',
              ))
          .toList();
      setState(() => _templateOptions = options);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: LoadingView());
    }

    return EntityListScreen(
      config: EntityConfig(
        title: 'Tipos de tarefa',
        endpoint: '/task-types',
        primaryField: 'name',
        hint: 'Defina os tipos e amarre um modelo de relatório.',
        fields: [
          FieldConfig(name: 'name', label: 'Nome', type: FieldType.text),
          FieldConfig(name: 'description', label: 'Descrição', type: FieldType.textarea),
          FieldConfig(
            name: 'report_template_id',
            label: 'Modelo de relatório',
            type: FieldType.select,
            options: _templateOptions,
          ),
        ],
      ),
    );
  }
}
