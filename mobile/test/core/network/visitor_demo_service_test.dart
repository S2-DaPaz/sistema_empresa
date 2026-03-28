import 'package:flutter_test/flutter_test.dart';

import 'package:rv_sistema_mobile/core/network/visitor_demo_service.dart';

void main() {
  setUp(() {
    VisitorDemoService.instance.reset();
  });

  test('retorna resumo demonstrativo para o painel', () {
    final payload = VisitorDemoService.instance.handle(
      method: 'GET',
      path: '/summary',
    ) as Map<String, dynamic>;

    expect(payload['summary'], isA<Map<String, dynamic>>());
    expect(payload['recentTasks'], isA<List<dynamic>>());
    expect((payload['summary'] as Map<String, dynamic>)['tasks'], greaterThan(0));
  });

  test('cria cliente demo sem persistir no backend real', () {
    final created = VisitorDemoService.instance.handle(
      method: 'POST',
      path: '/clients',
      body: {
        'name': 'Cliente Sandbox',
        'cnpj': '00.000.000/0001-00',
        'address': 'Rua Demo, 10',
        'contact': 'sandbox@demo.local | 98999999999',
      },
    ) as Map<String, dynamic>;

    final clients = VisitorDemoService.instance.handle(
      method: 'GET',
      path: '/clients',
    ) as List<dynamic>;

    expect(created['id'], isNotNull);
    expect(
      clients.any((item) => (item as Map<String, dynamic>)['name'] == 'Cliente Sandbox'),
      isTrue,
    );
  });

  test('gera e atualiza tarefa demo com relatorio principal', () {
    final created = VisitorDemoService.instance.handle(
      method: 'POST',
      path: '/tasks',
      body: {
        'title': 'Tarefa Sandbox',
        'description': 'Fluxo completo em modo demonstracao.',
        'client_id': 101,
        'task_type_id': 401,
      },
    ) as Map<String, dynamic>;

    final reports = VisitorDemoService.instance.handle(
      method: 'GET',
      path: '/reports?taskId=${created['id']}',
    ) as List<dynamic>;

    VisitorDemoService.instance.handle(
      method: 'PUT',
      path: '/tasks/${created['id']}',
      body: {
        'title': 'Tarefa Sandbox Atualizada',
        'client_id': 101,
        'task_type_id': 401,
      },
    );

    final updated = VisitorDemoService.instance.handle(
      method: 'GET',
      path: '/tasks/${created['id']}',
    ) as Map<String, dynamic>;

    expect(reports, isNotEmpty);
    expect(updated['title'], 'Tarefa Sandbox Atualizada');
  });

  test('reset restaura o dataset demonstrativo original', () {
    VisitorDemoService.instance.handle(
      method: 'POST',
      path: '/clients',
      body: {
        'name': 'Cliente Temporario',
        'cnpj': '11.111.111/0001-11',
        'address': 'Rua Transitória, 1',
        'contact': 'temp@demo.local | 98990000000',
      },
    );

    VisitorDemoService.instance.reset();

    final clients = VisitorDemoService.instance.handle(
      method: 'GET',
      path: '/clients',
    ) as List<dynamic>;

    expect(
      clients.any(
        (item) => (item as Map<String, dynamic>)['name'] == 'Cliente Temporario',
      ),
      isFalse,
    );
    expect(clients.length, 3);
  });
}
