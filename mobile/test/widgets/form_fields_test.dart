import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rv_sistema_mobile/widgets/form_fields.dart';

void main() {
  testWidgets('AppDropdownField nao quebra com valor fora da lista',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppDropdownField<String>(
            label: 'Status',
            value: 'valor_legado',
            items: const [
              DropdownMenuItem<String>(
                value: 'rascunho',
                child: Text('Rascunho'),
              ),
              DropdownMenuItem<String>(
                value: 'enviado',
                child: Text('Enviado'),
              ),
            ],
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Status'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
