import 'dart:convert';

class VisitorDemoService {
  VisitorDemoService._() {
    reset();
  }

  static final VisitorDemoService instance = VisitorDemoService._();

  late List<Map<String, dynamic>> _clients;
  late List<Map<String, dynamic>> _products;
  late List<Map<String, dynamic>> _taskTypes;
  late List<Map<String, dynamic>> _templates;
  late List<Map<String, dynamic>> _equipments;
  late List<Map<String, dynamic>> _tasks;
  late List<Map<String, dynamic>> _reports;
  late List<Map<String, dynamic>> _budgets;

  int _nextClientId = 1000;
  int _nextProductId = 2000;
  int _nextTaskTypeId = 3000;
  int _nextTemplateId = 4000;
  int _nextEquipmentId = 5000;
  int _nextTaskId = 6000;
  int _nextReportId = 7000;
  int _nextBudgetId = 8000;

  void reset() {
    _clients = [
      {
        'id': 101,
        'name': 'Clinica Sao Lucas',
        'cnpj': '12.345.678/0001-10',
        'address': 'Av. dos Holandeses, 1440 - Sao Luis/MA',
        'contact': 'contato@saolucas.demo | 98981112233',
      },
      {
        'id': 102,
        'name': 'Laboratorio Delta',
        'cnpj': '98.765.432/0001-55',
        'address': 'Rua das Palmeiras, 82 - Imperatriz/MA',
        'contact': 'suporte@delta.demo | 98991234567',
      },
      {
        'id': 103,
        'name': 'Escola Horizonte',
        'cnpj': '45.987.321/0001-90',
        'address': 'Rua do Sol, 210 - Sao Jose de Ribamar/MA',
        'contact': 'administrativo@horizonte.demo | 98982345678',
      },
    ];

    _products = [
      {
        'id': 201,
        'name': 'Gas refrigerante R410A',
        'sku': 'R410A-13KG',
        'unit': 'cil',
        'price': 420.0,
      },
      {
        'id': 202,
        'name': 'Filtro secador 3/8',
        'sku': 'FSEC-38',
        'unit': 'un',
        'price': 36.5,
      },
      {
        'id': 203,
        'name': 'Capacitor 45uf',
        'sku': 'CAP-45UF',
        'unit': 'un',
        'price': 58.9,
      },
    ];

    _templates = [
      {
        'id': 301,
        'name': 'Relatorio tecnico padrao',
        'description': 'Modelo base para manutencao e atendimento preventivo.',
        'structure': {
          'sections': [
            {
              'id': 'dados_gerais',
              'title': 'Dados gerais',
              'fields': [
                {
                  'id': 'problema',
                  'label': 'Problema relatado',
                  'type': 'textarea',
                  'required': true,
                  'options': <String>[],
                },
                {
                  'id': 'acao',
                  'label': 'Acao executada',
                  'type': 'textarea',
                  'required': false,
                  'options': <String>[],
                },
              ],
            },
            {
              'id': 'checklist',
              'title': 'Checklist',
              'fields': [
                {
                  'id': 'limpeza',
                  'label': 'Limpeza realizada',
                  'type': 'checkbox',
                  'required': false,
                  'options': <String>[],
                },
                {
                  'id': 'funcionando',
                  'label': 'Equipamento funcionando',
                  'type': 'yesno',
                  'required': false,
                  'options': <String>[],
                },
                {
                  'id': 'retorno',
                  'label': 'Data sugerida de retorno',
                  'type': 'date',
                  'required': false,
                  'options': <String>[],
                },
              ],
            },
          ],
          'layout': {
            'sectionColumns': 1,
            'fieldColumns': 1,
          },
        },
      },
      {
        'id': 302,
        'name': 'Instalacao e comissionamento',
        'description': 'Modelo demonstrativo para entregas e validacao final.',
        'structure': {
          'sections': [
            {
              'id': 'entrega',
              'title': 'Entrega',
              'fields': [
                {
                  'id': 'configuracao',
                  'label': 'Configuracao aplicada',
                  'type': 'textarea',
                  'required': false,
                  'options': <String>[],
                },
                {
                  'id': 'treinamento',
                  'label': 'Treinamento concluido',
                  'type': 'yesno',
                  'required': false,
                  'options': <String>[],
                },
              ],
            },
          ],
          'layout': {
            'sectionColumns': 1,
            'fieldColumns': 1,
          },
        },
      },
    ];

    _taskTypes = [
      {
        'id': 401,
        'name': 'Manutencao preventiva',
        'description': 'Rotina de revisao e limpeza.',
        'report_template_id': 301,
      },
      {
        'id': 402,
        'name': 'Instalacao',
        'description': 'Instalacao e liberacao tecnica.',
        'report_template_id': 302,
      },
    ];

    _equipments = [
      {
        'id': 501,
        'client_id': 101,
        'name': 'Split recepcao',
        'model': 'EcoCool 18000 BTUs',
        'serial': 'EC18-001',
        'description': 'Equipamento principal da recepcao.',
      },
      {
        'id': 502,
        'client_id': 102,
        'name': 'Camara fria laboratorio',
        'model': 'ColdLab CL-900',
        'serial': 'CL900-77',
        'description': 'Camara de insumos sensiveis.',
      },
      {
        'id': 503,
        'client_id': 103,
        'name': 'Ar da diretoria',
        'model': 'Ventus Inverter 12000',
        'serial': 'VIN12-45',
        'description': 'Atende a sala administrativa.',
      },
    ];

    _tasks = [
      {
        'id': 601,
        'title': 'Manutencao preventiva mensal',
        'description': 'Revisao completa do sistema de climatizacao.',
        'client_id': 101,
        'user_id': null,
        'task_type_id': 401,
        'status': 'em_andamento',
        'priority': 'alta',
        'start_date': _isoDate(daysOffset: -1),
        'due_date': _isoDate(daysOffset: 1),
        'created_at': _isoDateTime(daysOffset: -2),
        'signature_mode': 'both',
        'signature_scope': 'last_page',
        'signature_client': '',
        'signature_tech': '',
        'signature_pages': <String, dynamic>{},
      },
      {
        'id': 602,
        'title': 'Instalacao de evaporadora nova',
        'description': 'Configuracao e testes de pressao.',
        'client_id': 102,
        'user_id': null,
        'task_type_id': 402,
        'status': 'aberta',
        'priority': 'media',
        'start_date': _isoDate(daysOffset: 0),
        'due_date': _isoDate(daysOffset: 2),
        'created_at': _isoDateTime(daysOffset: -1),
        'signature_mode': 'none',
        'signature_scope': 'last_page',
        'signature_client': '',
        'signature_tech': '',
        'signature_pages': <String, dynamic>{},
      },
      {
        'id': 603,
        'title': 'Diagnostico de ruido intermitente',
        'description': 'Analise tecnica de vibracao e suporte.',
        'client_id': 103,
        'user_id': null,
        'task_type_id': 401,
        'status': 'concluida',
        'priority': 'baixa',
        'start_date': _isoDate(daysOffset: -4),
        'due_date': _isoDate(daysOffset: -3),
        'created_at': _isoDateTime(daysOffset: -5),
        'signature_mode': 'client',
        'signature_scope': 'last_page',
        'signature_client': '',
        'signature_tech': '',
        'signature_pages': <String, dynamic>{},
      },
    ];

    _reports = [
      _buildReport(
        id: 701,
        taskId: 601,
        clientId: 101,
        templateId: 301,
        equipmentId: 501,
        title: 'Relatorio tecnico principal',
        status: 'enviado',
        answers: {
          'problema': 'Oscilacao de rendimento em horario de pico.',
          'acao': 'Limpeza de serpentina e ajuste de pressao.',
          'limpeza': true,
          'funcionando': 'sim',
          'retorno': _isoDate(daysOffset: 20),
        },
      ),
      _buildReport(
        id: 702,
        taskId: 602,
        clientId: 102,
        templateId: 302,
        title: 'Comissionamento inicial',
        status: 'rascunho',
        answers: {
          'configuracao': 'Tubulacao validada e parametros iniciais definidos.',
          'treinamento': 'nao',
        },
      ),
      _buildReport(
        id: 703,
        taskId: 603,
        clientId: 103,
        templateId: 301,
        title: 'Relatorio de encerramento',
        status: 'finalizado',
        answers: {
          'problema': 'Ruido causado por fixacao frouxa.',
          'acao': 'Aperto estrutural e novo teste de carga.',
          'limpeza': false,
          'funcionando': 'sim',
          'retorno': _isoDate(daysOffset: 45),
        },
      ),
    ];

    _budgets = [
      {
        'id': 801,
        'client_id': 101,
        'task_id': 601,
        'report_id': 701,
        'status': 'em_andamento',
        'notes': 'Troca de filtro secador e recarga parcial.',
        'internal_note': 'Aguardando aprovacao do financeiro.',
        'proposal_validity': '15 dias',
        'payment_terms': 'Boleto 15 dias',
        'service_deadline': '24 horas',
        'product_validity': '60 dias',
        'discount': 0,
        'tax': 0,
        'signature_mode': 'none',
        'signature_scope': 'last_page',
        'signature_client': '',
        'signature_tech': '',
        'signature_pages': <String, dynamic>{},
        'created_at': _isoDateTime(daysOffset: -1),
        'items': [
          {
            'id': 'b1',
            'description': 'Filtro secador 3/8',
            'qty': 2,
            'unit_price': 36.5,
            'product_id': 202,
            'total': 73.0,
          },
          {
            'id': 'b2',
            'description': 'Gas refrigerante R410A',
            'qty': 1,
            'unit_price': 420.0,
            'product_id': 201,
            'total': 420.0,
          },
        ],
      },
      {
        'id': 802,
        'client_id': 102,
        'task_id': 602,
        'report_id': 702,
        'status': 'aprovado',
        'notes': 'Material complementar para conclusao da instalacao.',
        'internal_note': '',
        'proposal_validity': '30 dias',
        'payment_terms': 'A vista',
        'service_deadline': '03 dias',
        'product_validity': '90 dias',
        'discount': 20.0,
        'tax': 0,
        'signature_mode': 'none',
        'signature_scope': 'last_page',
        'signature_client': '',
        'signature_tech': '',
        'signature_pages': <String, dynamic>{},
        'created_at': _isoDateTime(daysOffset: -3),
        'items': [
          {
            'id': 'b3',
            'description': 'Capacitor 45uf',
            'qty': 1,
            'unit_price': 58.9,
            'product_id': 203,
            'total': 58.9,
          },
        ],
      },
    ];

    _nextClientId = 1000;
    _nextProductId = 2000;
    _nextTaskTypeId = 3000;
    _nextTemplateId = 4000;
    _nextEquipmentId = 5000;
    _nextTaskId = 6000;
    _nextReportId = 7000;
    _nextBudgetId = 8000;
  }

  dynamic handle({
    required String method,
    required String path,
    Map<String, dynamic>? body,
  }) {
    final uri = Uri.parse('https://visitor.demo$path');
    final normalizedMethod = method.toUpperCase();

    return switch (normalizedMethod) {
      'GET' => _handleGet(uri),
      'POST' => _handlePost(uri, body ?? const {}),
      'PUT' => _handlePut(uri, body ?? const {}),
      'DELETE' => _handleDelete(uri),
      _ => null,
    };
  }

  bool supports({
    required String method,
    required String path,
  }) {
    final uri = Uri.parse('https://visitor.demo$path');
    final normalizedMethod = method.toUpperCase();
    final route = uri.path;

    return switch (normalizedMethod) {
      'GET' => _supportedGet(route),
      'POST' => _supportedPost(route),
      'PUT' => _supportedPut(route),
      'DELETE' => _supportedDelete(route),
      _ => false,
    };
  }

  dynamic _handleGet(Uri uri) {
    final path = uri.path;

    if (path == '/summary') {
      return _buildSummaryPayload();
    }
    if (path == '/clients') {
      return _clone(_clients);
    }
    if (path == '/products') {
      return _clone(_products);
    }
    if (path == '/task-types') {
      return _clone(_taskTypes);
    }
    if (path == '/report-templates') {
      return _clone(_templates);
    }
    if (path == '/roles' || path == '/users') {
      return <Map<String, dynamic>>[];
    }
    if (path == '/tasks') {
      final clientId = _queryInt(uri, 'clientId');
      final tasks = _tasks.where((task) {
        if (clientId != null) {
          return task['client_id'] == clientId;
        }
        return true;
      }).map(_presentTask).toList();
      return _clone(tasks);
    }
    if (path == '/budgets') {
      return _clone(_queryBudgets(uri));
    }
    if (path == '/reports') {
      final taskId = _queryInt(uri, 'taskId');
      final reports = _reports
          .where((report) => taskId == null || report['task_id'] == taskId)
          .map(_presentReport)
          .toList();
      return _clone(reports);
    }
    if (path == '/equipments') {
      final clientId = _queryInt(uri, 'clientId');
      final equipments = _equipments
          .where((item) => clientId == null || item['client_id'] == clientId)
          .map(_presentEquipment)
          .toList();
      return _clone(equipments);
    }

    final clientId = _extractId(path, RegExp(r'^/clients/(\d+)$'));
    if (clientId != null) {
      return _clone(_presentClient(_findById(_clients, clientId)));
    }

    final taskId = _extractId(path, RegExp(r'^/tasks/(\d+)$'));
    if (taskId != null) {
      return _clone(_presentTask(_findById(_tasks, taskId)));
    }

    final budgetId = _extractId(path, RegExp(r'^/budgets/(\d+)$'));
    if (budgetId != null) {
      return _clone(_presentBudget(_findById(_budgets, budgetId)));
    }

    final reportId = _extractId(path, RegExp(r'^/reports/(\d+)$'));
    if (reportId != null) {
      return _clone(_presentReport(_findById(_reports, reportId)));
    }

    final equipmentId = _extractId(path, RegExp(r'^/equipments/(\d+)$'));
    if (equipmentId != null) {
      return _clone(_presentEquipment(_findById(_equipments, equipmentId)));
    }

    return null;
  }

  dynamic _handlePost(Uri uri, Map<String, dynamic> body) {
    final path = uri.path;

    if (path == '/clients') {
      final created = _buildClient({
        ...body,
        'id': _nextClientId++,
      });
      _clients.add(created);
      return _clone(created);
    }

    if (path == '/products') {
      final created = {
        'id': _nextProductId++,
        'name': body['name']?.toString() ?? 'Produto demo',
        'sku': body['sku']?.toString() ?? '',
        'unit': body['unit']?.toString() ?? 'un',
        'price': _toNum(body['price']),
      };
      _products.add(created);
      return _clone(created);
    }

    if (path == '/task-types') {
      final created = {
        'id': _nextTaskTypeId++,
        'name': body['name']?.toString() ?? 'Tipo demo',
        'description': body['description']?.toString() ?? '',
        'report_template_id': _toNullableInt(body['report_template_id']),
      };
      _taskTypes.add(created);
      return _clone(created);
    }

    if (path == '/report-templates') {
      final created = {
        'id': _nextTemplateId++,
        'name': body['name']?.toString() ?? 'Template demo',
        'description': body['description']?.toString() ?? '',
        'structure': _clone(body['structure'] ?? const <String, dynamic>{}),
      };
      _templates.add(created);
      return _clone(created);
    }

    if (path == '/equipments') {
      final created = {
        'id': _nextEquipmentId++,
        'client_id': _toNullableInt(body['client_id']),
        'name': body['name']?.toString() ?? 'Equipamento demo',
        'model': body['model']?.toString() ?? '',
        'serial': body['serial']?.toString() ?? '',
        'description': body['description']?.toString() ?? '',
      };
      _equipments.add(created);
      return _clone(created);
    }

    if (path == '/tasks') {
      final created = {
        'id': _nextTaskId++,
        'title': body['title']?.toString() ?? 'Nova tarefa demo',
        'description': body['description']?.toString() ?? '',
        'client_id': _toNullableInt(body['client_id']),
        'user_id': _toNullableInt(body['user_id']),
        'task_type_id': _toNullableInt(body['task_type_id']),
        'status': body['status']?.toString() ?? 'aberta',
        'priority': body['priority']?.toString() ?? 'media',
        'start_date': body['start_date']?.toString() ?? _isoDate(),
        'due_date': body['due_date']?.toString() ?? _isoDate(daysOffset: 1),
        'created_at': _isoDateTime(),
        'signature_mode': body['signature_mode']?.toString() ?? 'none',
        'signature_scope': body['signature_scope']?.toString() ?? 'last_page',
        'signature_client': body['signature_client']?.toString() ?? '',
        'signature_tech': body['signature_tech']?.toString() ?? '',
        'signature_pages':
            _clone(body['signature_pages'] ?? const <String, dynamic>{}),
      };
      _tasks.add(created);
      _ensureGeneralReportForTask(created);
      return _clone(_presentTask(created));
    }

    if (path == '/reports') {
      final created = _buildReport(
        id: _nextReportId++,
        taskId: _toNullableInt(body['task_id']) ?? 0,
        clientId: _toNullableInt(body['client_id']) ?? 0,
        templateId: _toNullableInt(body['template_id']) ?? 301,
        equipmentId: _toNullableInt(body['equipment_id']),
        title: body['title']?.toString() ?? 'Relatorio demo',
        status: body['status']?.toString() ?? 'rascunho',
        content: _clone(body['content'] ?? const <String, dynamic>{}),
      );
      _reports.add(created);
      return _clone(_presentReport(created));
    }

    if (path == '/budgets') {
      final created = _buildBudget({
        ...body,
        'id': _nextBudgetId++,
        'created_at': _isoDateTime(),
      });
      _budgets.add(created);
      return _clone(_presentBudget(created));
    }

    final taskPublicId =
        _extractId(path, RegExp(r'^/tasks/(\d+)/public-link$'));
    if (taskPublicId != null) {
      return {
        'url': 'https://demo.rv/public/task/$taskPublicId',
      };
    }

    final taskMailId = _extractId(path, RegExp(r'^/tasks/(\d+)/email-link$'));
    if (taskMailId != null) {
      return {
        'message':
            'Relatorio demo #$taskMailId enviado em modo demonstracao.',
      };
    }

    final budgetPublicId =
        _extractId(path, RegExp(r'^/budgets/(\d+)/public-link$'));
    if (budgetPublicId != null) {
      return {
        'url': 'https://demo.rv/public/budget/$budgetPublicId',
      };
    }

    final budgetMailId =
        _extractId(path, RegExp(r'^/budgets/(\d+)/email-link$'));
    if (budgetMailId != null) {
      return {
        'message':
            'Orcamento demo #$budgetMailId enviado em modo demonstracao.',
      };
    }

    return null;
  }

  dynamic _handlePut(Uri uri, Map<String, dynamic> body) {
    final path = uri.path;

    final clientId = _extractId(path, RegExp(r'^/clients/(\d+)$'));
    if (clientId != null) {
      return _clone(_mergeById(_clients, clientId, _buildClient(body)));
    }

    final productId = _extractId(path, RegExp(r'^/products/(\d+)$'));
    if (productId != null) {
      return _clone(_mergeById(_products, productId, {
        'name': body['name']?.toString(),
        'sku': body['sku']?.toString(),
        'unit': body['unit']?.toString(),
        'price': _toNum(body['price']),
      }));
    }

    final taskTypeId = _extractId(path, RegExp(r'^/task-types/(\d+)$'));
    if (taskTypeId != null) {
      return _clone(_mergeById(_taskTypes, taskTypeId, {
        'name': body['name']?.toString(),
        'description': body['description']?.toString(),
        'report_template_id': _toNullableInt(body['report_template_id']),
      }));
    }

    final templateId = _extractId(path, RegExp(r'^/report-templates/(\d+)$'));
    if (templateId != null) {
      return _clone(_mergeById(_templates, templateId, {
        'name': body['name']?.toString(),
        'description': body['description']?.toString(),
        'structure': _clone(body['structure'] ?? const <String, dynamic>{}),
      }));
    }

    final equipmentId = _extractId(path, RegExp(r'^/equipments/(\d+)$'));
    if (equipmentId != null) {
      return _clone(_mergeById(_equipments, equipmentId, {
        'client_id': _toNullableInt(body['client_id']),
        'name': body['name']?.toString(),
        'model': body['model']?.toString(),
        'serial': body['serial']?.toString(),
        'description': body['description']?.toString(),
      }));
    }

    final taskId = _extractId(path, RegExp(r'^/tasks/(\d+)$'));
    if (taskId != null) {
      final updated = _mergeById(_tasks, taskId, {
        'title': body['title']?.toString(),
        'description': body['description']?.toString(),
        'client_id': _toNullableInt(body['client_id']),
        'user_id': _toNullableInt(body['user_id']),
        'task_type_id': _toNullableInt(body['task_type_id']),
        'status': body['status']?.toString(),
        'priority': body['priority']?.toString(),
        'start_date': body['start_date']?.toString(),
        'due_date': body['due_date']?.toString(),
        'signature_mode': body['signature_mode']?.toString(),
        'signature_scope': body['signature_scope']?.toString(),
        'signature_client': body['signature_client']?.toString(),
        'signature_tech': body['signature_tech']?.toString(),
        'signature_pages':
            _clone(body['signature_pages'] ?? const <String, dynamic>{}),
      });
      _ensureGeneralReportForTask(updated);
      return _clone(_presentTask(updated));
    }

    final reportId = _extractId(path, RegExp(r'^/reports/(\d+)$'));
    if (reportId != null) {
      final updated = _mergeById(_reports, reportId, {
        'title': body['title']?.toString(),
        'task_id': _toNullableInt(body['task_id']),
        'client_id': _toNullableInt(body['client_id']),
        'template_id': _toNullableInt(body['template_id']),
        'equipment_id': _toNullableInt(body['equipment_id']),
        'status': body['status']?.toString(),
        'content': _clone(body['content'] ?? const <String, dynamic>{}),
      });
      return _clone(_presentReport(updated));
    }

    final budgetId = _extractId(path, RegExp(r'^/budgets/(\d+)$'));
    if (budgetId != null) {
      final updated = _mergeById(_budgets, budgetId, _buildBudget(body));
      return _clone(_presentBudget(updated));
    }

    return null;
  }

  dynamic _handleDelete(Uri uri) {
    final path = uri.path;

    final clientId = _extractId(path, RegExp(r'^/clients/(\d+)$'));
    if (clientId != null) {
      _clients.removeWhere((item) => item['id'] == clientId);
      _tasks.removeWhere((item) => item['client_id'] == clientId);
      _budgets.removeWhere((item) => item['client_id'] == clientId);
      _reports.removeWhere((item) => item['client_id'] == clientId);
      _equipments.removeWhere((item) => item['client_id'] == clientId);
      return null;
    }

    final productId = _extractId(path, RegExp(r'^/products/(\d+)$'));
    if (productId != null) {
      _products.removeWhere((item) => item['id'] == productId);
      return null;
    }

    final taskTypeId = _extractId(path, RegExp(r'^/task-types/(\d+)$'));
    if (taskTypeId != null) {
      _taskTypes.removeWhere((item) => item['id'] == taskTypeId);
      return null;
    }

    final templateId = _extractId(path, RegExp(r'^/report-templates/(\d+)$'));
    if (templateId != null) {
      _templates.removeWhere((item) => item['id'] == templateId);
      return null;
    }

    final equipmentId = _extractId(path, RegExp(r'^/equipments/(\d+)$'));
    if (equipmentId != null) {
      _equipments.removeWhere((item) => item['id'] == equipmentId);
      for (final report in _reports) {
        if (report['equipment_id'] == equipmentId) {
          report['equipment_id'] = null;
        }
      }
      return null;
    }

    final reportId = _extractId(path, RegExp(r'^/reports/(\d+)$'));
    if (reportId != null) {
      _reports.removeWhere((item) => item['id'] == reportId);
      _budgets.removeWhere((item) => item['report_id'] == reportId);
      return null;
    }

    final budgetId = _extractId(path, RegExp(r'^/budgets/(\d+)$'));
    if (budgetId != null) {
      _budgets.removeWhere((item) => item['id'] == budgetId);
      return null;
    }

    final taskId = _extractId(path, RegExp(r'^/tasks/(\d+)$'));
    if (taskId != null) {
      _tasks.removeWhere((item) => item['id'] == taskId);
      _reports.removeWhere((item) => item['task_id'] == taskId);
      _budgets.removeWhere((item) => item['task_id'] == taskId);
      return null;
    }

    return null;
  }

  Map<String, dynamic> _buildSummaryPayload() {
    final taskMetrics = {
      'total': _tasks.length,
      'open': _tasks.where((item) => item['status'] == 'aberta').length,
      'inProgress':
          _tasks.where((item) => item['status'] == 'em_andamento').length,
      'completed':
          _tasks.where((item) => item['status'] == 'concluida').length,
      'today': _tasks.where((item) => item['start_date'] == _isoDate()).length,
    };
    final budgetMetrics = {
      'total': _budgets.length,
      'inProgress':
          _budgets.where((item) => item['status'] == 'em_andamento').length,
      'approved': _budgets.where((item) => item['status'] == 'aprovado').length,
      'rejected': _budgets.where((item) => item['status'] == 'recusado').length,
    };

    return {
      'summary': {
        'clients': _clients.length,
        'tasks': _tasks.length,
        'reports': _reports.length,
        'budgets': _budgets.length,
        'products': _products.length,
        'users': 0,
      },
      'taskMetrics': taskMetrics,
      'budgetMetrics': budgetMetrics,
      'recentTasks': _tasks
          .map(_presentTask)
          .toList()
        ..sort(_sortByCreatedAtDesc),
      'recentBudgets': _budgets
          .map(_presentBudget)
          .toList()
        ..sort(_sortByCreatedAtDesc),
      'recentReports': _reports
          .map(_presentReport)
          .toList()
        ..sort(_sortByCreatedAtDesc),
      'notificationCount': taskMetrics['open']! + taskMetrics['inProgress']!,
    };
  }

  List<Map<String, dynamic>> _queryBudgets(Uri uri) {
    final clientId = _queryInt(uri, 'clientId');
    final taskId = _queryInt(uri, 'taskId');
    final reportId = _queryInt(uri, 'reportId');

    return _budgets.where((budget) {
      if (clientId != null && budget['client_id'] != clientId) return false;
      if (taskId != null && budget['task_id'] != taskId) return false;
      if (reportId != null && budget['report_id'] != reportId) return false;
      return true;
    }).map(_presentBudget).toList();
  }

  Map<String, dynamic> _presentClient(Map<String, dynamic> client) {
    return {
      ...client,
    };
  }

  Map<String, dynamic> _presentTask(Map<String, dynamic> task) {
    final client = _findById(_clients, task['client_id']);
    final type = _findById(_taskTypes, task['task_type_id']);
    return {
      ...task,
      'client_name': client['name'],
      'client_address': client['address'],
      'task_type_name': type['name'],
    };
  }

  Map<String, dynamic> _presentReport(Map<String, dynamic> report) {
    final equipment = _findById(_equipments, report['equipment_id']);
    final task = _findById(_tasks, report['task_id']);
    final client = _findById(_clients, report['client_id']);
    return {
      ...report,
      'equipment_name': equipment['name'],
      'task_title': task['title'],
      'client_name': client['name'],
      'created_at': report['created_at'] ?? task['created_at'],
    };
  }

  Map<String, dynamic> _presentBudget(Map<String, dynamic> budget) {
    final client = _findById(_clients, budget['client_id']);
    final task = _findById(_tasks, budget['task_id']);
    final items = List<Map<String, dynamic>>.from(
      (budget['items'] as List<dynamic>? ?? const <dynamic>[]).map(
        (item) => Map<String, dynamic>.from(item as Map),
      ),
    );
    final total = items.fold<double>(
      0,
      (sum, item) =>
          sum + ((_toNum(item['total']) > 0)
              ? _toNum(item['total'])
              : (_toNum(item['qty']) * _toNum(item['unit_price']))),
    );
    final discount = _toNum(budget['discount']);
    final tax = _toNum(budget['tax']);
    return {
      ...budget,
      'client_name': client['name'],
      'task_title': task['title'],
      'items': items.map((item) {
        final total = (_toNum(item['total']) > 0)
            ? _toNum(item['total'])
            : _toNum(item['qty']) * _toNum(item['unit_price']);
        return {
          ...item,
          'total': total,
        };
      }).toList(),
      'total': total - discount + tax,
    };
  }

  Map<String, dynamic> _presentEquipment(Map<String, dynamic> equipment) {
    final client = _findById(_clients, equipment['client_id']);
    return {
      ...equipment,
      'client_name': client['name'],
    };
  }

  Map<String, dynamic> _buildClient(Map<String, dynamic> data) {
    return {
      'id': data['id'],
      'name': data['name']?.toString() ?? 'Cliente demo',
      'cnpj': data['cnpj']?.toString() ?? '',
      'address': data['address']?.toString() ?? '',
      'contact': data['contact']?.toString() ?? '',
    };
  }

  Map<String, dynamic> _buildBudget(Map<String, dynamic> data) {
    return {
      'id': data['id'],
      'client_id': _toNullableInt(data['client_id']),
      'task_id': _toNullableInt(data['task_id']),
      'report_id': _toNullableInt(data['report_id']),
      'status': data['status']?.toString() ?? 'em_andamento',
      'notes': data['notes']?.toString() ?? '',
      'internal_note': data['internal_note']?.toString() ?? '',
      'proposal_validity': data['proposal_validity']?.toString() ?? '30 dias',
      'payment_terms': data['payment_terms']?.toString() ?? 'A vista',
      'service_deadline': data['service_deadline']?.toString() ?? '03 dias',
      'product_validity': data['product_validity']?.toString() ?? '90 dias',
      'discount': _toNum(data['discount']),
      'tax': _toNum(data['tax']),
      'signature_mode': data['signature_mode']?.toString() ?? 'none',
      'signature_scope': data['signature_scope']?.toString() ?? 'last_page',
      'signature_client': data['signature_client']?.toString() ?? '',
      'signature_tech': data['signature_tech']?.toString() ?? '',
      'signature_pages':
          _clone(data['signature_pages'] ?? const <String, dynamic>{}),
      'created_at': data['created_at']?.toString() ?? _isoDateTime(),
      'items': ((data['items'] as List<dynamic>?) ?? const <dynamic>[])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .map((item) => {
                ...item,
                'qty': _toNum(item['qty'] ?? item['quantity']),
                'unit_price': _toNum(item['unit_price'] ?? item['unitPrice']),
                'total': (_toNum(item['qty'] ?? item['quantity']) *
                    _toNum(item['unit_price'] ?? item['unitPrice'])),
              })
          .toList(),
    };
  }

  Map<String, dynamic> _buildReport({
    required int id,
    required int taskId,
    required int clientId,
    required int templateId,
    int? equipmentId,
    String title = 'Relatorio demo',
    String status = 'rascunho',
    Map<String, dynamic>? content,
    Map<String, dynamic>? answers,
  }) {
    final template = _findById(_templates, templateId);
    final structure = Map<String, dynamic>.from(
      template['structure'] as Map? ?? const <String, dynamic>{},
    );
    final rawContent = Map<String, dynamic>.from(content ?? const {});
    final nextContent = rawContent.isNotEmpty
        ? rawContent
        : {
            'sections': _clone(structure['sections'] ?? const <dynamic>[]),
            'layout': _clone(structure['layout'] ?? const <String, dynamic>{}),
            'answers': _clone(answers ?? const <String, dynamic>{}),
            'photos': <Map<String, dynamic>>[],
          };
    nextContent.putIfAbsent(
      'sections',
      () => _clone(structure['sections'] ?? const <dynamic>[]),
    );
    nextContent.putIfAbsent(
      'layout',
      () => _clone(structure['layout'] ?? const <String, dynamic>{}),
    );
    nextContent.putIfAbsent('answers', () => _clone(answers ?? const {}));
    nextContent.putIfAbsent('photos', () => <Map<String, dynamic>>[]);

    return {
      'id': id,
      'task_id': taskId,
      'client_id': clientId,
      'template_id': templateId,
      'equipment_id': equipmentId,
      'title': title,
      'status': status,
      'created_at': _isoDateTime(),
      'content': nextContent,
    };
  }

  void _ensureGeneralReportForTask(Map<String, dynamic> task) {
    final taskId = task['id'] as int?;
    final clientId = task['client_id'] as int?;
    final templateId = _templateIdForTaskType(task['task_type_id'] as int?);
    if (taskId == null || clientId == null || templateId == null) {
      return;
    }
    final exists = _reports.any(
      (report) => report['task_id'] == taskId && report['equipment_id'] == null,
    );
    if (exists) return;
    _reports.add(
      _buildReport(
        id: _nextReportId++,
        taskId: taskId,
        clientId: clientId,
        templateId: templateId,
        title: 'Relatorio principal',
      ),
    );
  }

  int? _templateIdForTaskType(int? taskTypeId) {
    final type = _findById(_taskTypes, taskTypeId);
    return type['report_template_id'] as int?;
  }

  Map<String, dynamic> _mergeById(
    List<Map<String, dynamic>> items,
    int id,
    Map<String, dynamic> patch,
  ) {
    final index = items.indexWhere((item) => item['id'] == id);
    if (index == -1) {
      return patch;
    }
    final current = Map<String, dynamic>.from(items[index]);
    for (final entry in patch.entries) {
      if (entry.value != null) {
        current[entry.key] = entry.value;
      }
    }
    items[index] = current;
    return current;
  }

  Map<String, dynamic> _findById(List<Map<String, dynamic>> items, dynamic id) {
    for (final item in items) {
      if (item['id'] == id) return item;
    }
    return <String, dynamic>{};
  }

  int? _extractId(String path, RegExp expression) {
    final match = expression.firstMatch(path);
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }

  bool _supportedGet(String path) {
    return path == '/summary' ||
        path == '/clients' ||
        path == '/products' ||
        path == '/task-types' ||
        path == '/report-templates' ||
        path == '/roles' ||
        path == '/users' ||
        path == '/tasks' ||
        path == '/budgets' ||
        path == '/reports' ||
        path == '/equipments' ||
        RegExp(r'^/(clients|tasks|budgets|reports|equipments)/\d+$')
            .hasMatch(path);
  }

  bool _supportedPost(String path) {
    return path == '/clients' ||
        path == '/products' ||
        path == '/task-types' ||
        path == '/report-templates' ||
        path == '/equipments' ||
        path == '/tasks' ||
        path == '/reports' ||
        path == '/budgets' ||
        RegExp(r'^/tasks/\d+/(public-link|email-link)$').hasMatch(path) ||
        RegExp(r'^/budgets/\d+/(public-link|email-link)$').hasMatch(path);
  }

  bool _supportedPut(String path) {
    return RegExp(
      r'^/(clients|products|task-types|report-templates|equipments|tasks|reports|budgets)/\d+$',
    ).hasMatch(path);
  }

  bool _supportedDelete(String path) {
    return _supportedPut(path);
  }

  int? _queryInt(Uri uri, String key) {
    return int.tryParse(uri.queryParameters[key] ?? '');
  }

  double _toNum(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0;
  }

  int? _toNullableInt(dynamic value) {
    if (value == null || value.toString().isEmpty) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static int _sortByCreatedAtDesc(
    Map<String, dynamic> left,
    Map<String, dynamic> right,
  ) {
    final leftValue = DateTime.tryParse(left['created_at']?.toString() ?? '');
    final rightValue =
        DateTime.tryParse(right['created_at']?.toString() ?? '');
    return (rightValue ?? DateTime.fromMillisecondsSinceEpoch(0))
        .compareTo(leftValue ?? DateTime.fromMillisecondsSinceEpoch(0));
  }

  static dynamic _clone(dynamic value) {
    return jsonDecode(jsonEncode(value));
  }

  static String _isoDate({int daysOffset = 0}) {
    final date = DateTime.now().add(Duration(days: daysOffset));
    return DateTime(date.year, date.month, date.day).toIso8601String();
  }

  static String _isoDateTime({int daysOffset = 0}) {
    return DateTime.now().add(Duration(days: daysOffset)).toIso8601String();
  }
}
