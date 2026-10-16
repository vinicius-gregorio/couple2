import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('load error matches the skeleton height of each home card', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const cases = <(int, double)>[
      (4, 460),
      (2, 160),
      (2, 112),
      (3, 220),
    ];
    for (final entry in cases) {
      final lines = entry.$1;
      final height = entry.$2;
      final skeleton = await _height(
        tester,
        CardSkeleton(lines: lines, minHeight: height),
      );
      final error = await _height(
        tester,
        LoadErrorCard(
          message: 'Sem conexão. Verifique a internet e tente de novo.',
          onRetry: () {},
          minHeight: height,
        ),
      );
      expect(skeleton, height, reason: 'skeleton $height');
      expect(error, skeleton, reason: 'height $height');
    }
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
      final node = tester.getSemantics(find.bySemanticsLabel(label));
      expect(node.label, label);
      expect(node.flagsCollection.isButton, isTrue, reason: label);
      expect(node.flagsCollection.isEnabled, isTrue, reason: label);
    }
    final nextYear = tester.getSemantics(find.bySemanticsLabel('Próximo ano'));
    expect(nextYear.label, 'Próximo ano');
    expect(nextYear.flagsCollection.isButton, isTrue);
    expect(nextYear.flagsCollection.isEnabled, isFalse);
    } finally {
      handle.dispose();
    }
  });
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
