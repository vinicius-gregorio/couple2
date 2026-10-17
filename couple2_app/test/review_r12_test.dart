import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('load error is the message and retry, not the skeleton height', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const message = 'Sem conexão. Verifique a internet e tente de novo.';
    final skeleton = await _height(
      tester,
      const CardSkeleton(lines: 4, minHeight: 460),
    );
    final error = await _height(
      tester,
      LoadErrorCard(message: message, onRetry: () {}),
    );
    expect(skeleton, 460);
    expect(error, lessThan(skeleton));
    expect(find.text(message), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
  });

  testWidgets('picker arrows are enabled buttons with PT-BR names', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: LoadingButton(
                onPressed: () {
                  showAppDatePicker(
                    context: context,
                    initialDate: DateTime(2026, 6, 15),
                    firstDate: DateTime(1900),
                    lastDate: DateTime(2026, 12, 31),
                  );
                },
                child: const Text('Abrir'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    for (final label in ['Mês anterior', 'Próximo mês', 'Ano anterior']) {
      _expectArrow(tester, label, navigable: true);
    }
    _expectArrow(tester, 'Próximo ano', navigable: false);
    } finally {
      handle.dispose();
    }
  });
}

void _expectArrow(WidgetTester tester, String label, {required bool navigable}) {
  final data = tester.getSemantics(find.bySemanticsLabel(label)).getSemanticsData();
  expect(data.label, label);
  expect(data.flagsCollection.isButton, isTrue, reason: label);
  expect(data.flagsCollection.hasEnabledState, isTrue, reason: label);
  expect(data.flagsCollection.isEnabled, navigable, reason: label);
  expect(data.flagsCollection.isFocusable, navigable, reason: label);
  expect(data.hasAction(SemanticsAction.tap), navigable, reason: label);
}

Future<double> _height(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: lightTheme,
      home: Scaffold(body: ListView(children: [child])),
    ),
  );
  await tester.pump();
  return tester.getSize(find.byWidget(child)).height;
}
