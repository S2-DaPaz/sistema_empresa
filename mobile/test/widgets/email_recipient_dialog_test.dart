import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rv_sistema_mobile/widgets/email_recipient_dialog.dart';

void main() {
  testWidgets('dialog valida e retorna o email informado', (tester) async {
    String? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showEmailRecipientDialog(
                  context,
                  title: 'Enviar relatorio por e-mail',
                  message: 'Confirme o destinatario.',
                  confirmLabel: 'Enviar',
                  initialEmail: 'cliente@empresa.com',
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Enviar relatorio por e-mail'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);

    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();

    expect(result, 'cliente@empresa.com');
    expect(tester.takeException(), isNull);
  });

  testWidgets('dialog nao fecha com email invalido', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showEmailRecipientDialog(
                  context,
                  title: 'Enviar orcamento por e-mail',
                  message: 'Confirme o destinatario.',
                  confirmLabel: 'Enviar',
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'email-invalido');
    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();

    expect(find.text('Informe um endereco de e-mail valido.'), findsOneWidget);
    expect(find.text('Enviar orcamento por e-mail'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
