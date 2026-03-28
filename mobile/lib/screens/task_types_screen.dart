import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/permissions.dart';
import '../utils/entity_config.dart';
import '../utils/field_config.dart';
import '../widgets/access_restricted_state.dart';
import '../widgets/app_scaffold.dart';
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
  List<OpcaoCampo> _templateOptions = [];
  bool get _canView => Permissions.canViewModuleData(AppModule.taskTypes);

  @override
  void initState() {
    super.initState();
    if (!_canView) {
      _loading = false;
      return;
    }
    _load();
  }

  Future<void> _load() async {
    if (!_canView) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }
    try {
      final data = await _api.get('/report-templates') as List<dynamic>;
      final options = data
          .map((item) => OpcaoCampo(
                value: (item as Map<String, dynamic>)['id'],
                label: item['name']?.toString() ?? 'Modelo',
              ))
          .toList();
      if (!mounted) return;
      setState(() => _templateOptions = options);
    } catch (_) {
      // Templates are optional for task types; proceed with empty list.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_canView) {
      return const AppScaffold(
        title: 'Tipos de tarefa',
        body: AccessRestrictedState(
          title: 'Tipos de tarefa protegidos para este perfil',
          message:
              'O perfil visitante pode acessar a tela, mas não pode visualizar classificações nem modelos vinculados.',
        ),
      );
    }

    if (_loading) {
      return const AppScaffold(title: 'Tipos de tarefa', body: LoadingView());
    }

    return EntityListScreen(
      config: ConfiguracaoEntidade(
        title: 'Tipos de tarefa',
        endpoint: '/task-types',
        primaryField: 'name',
        hint: 'Defina os tipos e amarre um modelo de relatório.',
        fields: [
          ConfiguracaoCampo(name: 'name', label: 'Nome', type: TipoCampo.text),
          ConfiguracaoCampo(
              name: 'description',
              label: 'Descrição',
              type: TipoCampo.textarea),
          ConfiguracaoCampo(
            name: 'report_template_id',
            label: 'Modelo de relatório',
            type: TipoCampo.select,
            options: _templateOptions,
          ),
        ],
      ),
    );
  }
}
