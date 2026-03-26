import '../../../core/network/api_service.dart';
import '../../../core/network/json_utils.dart';

class TaskDetailBootstrapData {
  const TaskDetailBootstrapData({
    required this.clients,
    required this.users,
    required this.types,
    required this.templates,
    required this.products,
    this.task,
  });

  final List<Map<String, dynamic>> clients;
  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> types;
  final List<Map<String, dynamic>> templates;
  final List<Map<String, dynamic>> products;
  final Map<String, dynamic>? task;
}

/// Repositório da tela de tarefa.
///
/// Mantém a compatibilidade com o contrato atual da API, mas concentra os
/// acessos remotos em uma única fronteira para reduzir acoplamento na tela.
class TaskDetailRepository {
  TaskDetailRepository({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;

  Future<TaskDetailBootstrapData> loadBootstrap({
    required int? taskId,
    required bool includeUsers,
  }) async {
    final results = await Future.wait([
      _api.get('/clients'),
      includeUsers ? _api.get('/users') : Future.value(<dynamic>[]),
      _api.get('/task-types'),
      _api.get('/report-templates'),
      _api.get('/products'),
      if (taskId != null) _api.get('/tasks/$taskId'),
    ]);

    return TaskDetailBootstrapData(
      clients: castJsonMapList(results[0]),
      users: castJsonMapList(results[1]),
      types: castJsonMapList(results[2]),
      templates: castJsonMapList(results[3]),
      products: castJsonMapList(results[4]),
      task: taskId == null ? null : castJsonMap(results[5]),
    );
  }

  Future<List<Map<String, dynamic>>> loadClientEquipments(int clientId) async {
    return castJsonMapList(await _api.get('/equipments?clientId=$clientId'));
  }

  Future<List<Map<String, dynamic>>> loadReports(int taskId) async {
    return castJsonMapList(await _api.get('/reports?taskId=$taskId'));
  }

  Future<List<Map<String, dynamic>>> loadBudgetsByTask(int taskId) async {
    return castJsonMapList(await _api.get('/budgets?taskId=$taskId'));
  }

  Future<List<Map<String, dynamic>>> loadBudgetsByReport(int reportId) async {
    return castJsonMapList(await _api.get('/budgets?reportId=$reportId'));
  }

  Future<Map<String, dynamic>> loadBudgetDetail(int budgetId) async {
    return castJsonMap(await _api.get('/budgets/$budgetId'));
  }

  Future<Map<String, dynamic>> createTask(Map<String, dynamic> payload) async {
    return castJsonMap(await _api.post('/tasks', payload));
  }

  Future<void> updateTask(int taskId, Map<String, dynamic> payload) async {
    await _api.put('/tasks/$taskId', payload);
  }

  Future<void> updateReport(int reportId, Map<String, dynamic> payload) async {
    await _api.put('/reports/$reportId', payload);
  }

  Future<Map<String, dynamic>> createReport(Map<String, dynamic> payload) async {
    return castJsonMap(await _api.post('/reports', payload));
  }

  Future<void> deleteReport(int reportId) async {
    await _api.delete('/reports/$reportId');
  }

  Future<void> updateReportEquipment(int reportId, int? equipmentId) async {
    await _api.put('/reports/$reportId', {'equipment_id': equipmentId});
  }

  Future<void> deleteBudget(int budgetId) async {
    await _api.delete('/budgets/$budgetId');
  }

  Future<String> createTaskPublicLink(int taskId) async {
    final response = castJsonMap(await _api.post('/tasks/$taskId/public-link', {}));
    return response['url']?.toString() ?? '';
  }

  Future<String> sendReportEmailLink({
    required int taskId,
    required String email,
    required int? reportId,
  }) async {
    final response = castJsonMap(await _api.post('/tasks/$taskId/email-link', {
      'email': email,
      'reportId': reportId,
    }));
    return response['message']?.toString() ??
        'Relatório enviado por e-mail com sucesso.';
  }
}
