import 'dart:async';

import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows a spinner and ignores a second tap while in flight', (
    tester,
  ) async {
    final gate = Completer<void>();
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme,
        home: Scaffold(
          body: LoadingButton(
            onPressed: () {
              taps++;
              return gate.future;
            },
            child: const Text('Salvar'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Salvar'));
    await tester.pump();

    expect(taps, 1);
    expect(find.byKey(LoadingButton.spinnerKey), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );

    await tester.tap(find.text('Salvar'));
    await tester.pump();
    expect(taps, 1);

    gate.complete();
    await tester.pump();
    expect(find.byKey(LoadingButton.spinnerKey), findsNothing);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('external loading disables the button before a second tap', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme,
        home: Scaffold(
          body: LoadingButton(
            loading: true,
            onPressed: () => taps++,
            child: const Text('Enviar'),
          ),
        ),
      ),
    );

    expect(find.byKey(LoadingButton.spinnerKey), findsOneWidget);
    await tester.tap(find.text('Enviar'));
    await tester.pump();
    expect(taps, 0);
  });

  testWidgets('enabled and disabled fills are different', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme,
        home: Scaffold(
          body: Column(
            children: [
              LoadingButton(onPressed: () {}, child: const Text('On')),
              const LoadingButton(onPressed: null, child: Text('Off')),
            ],
          ),
        ),
      ),
    );

    Color? fillOf(String label) {
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.widgetWithText(ElevatedButton, label),
              matching: find.byType(Material),
            )
            .first,
      );
      return material.color;
    }

    final enabled = fillOf('On');
    final disabled = fillOf('Off');
    expect(enabled, lightColorScheme.primary);
    expect(disabled, lightColorScheme.surfaceContainerHighest);
    expect(enabled, isNot(disabled));
  });

  testWidgets('delete icon on a filled button is onPrimary', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme,
        home: Scaffold(
          body: LoadingIconButton(
            tooltip: 'Excluir lista',
            onPressed: () {},
            icon: const Icon(Icons.delete_outline),
          ),
        ),
      ),
    );

    final icon = tester.widget<Icon>(find.byIcon(Icons.delete_outline));
    final theme = IconTheme.of(
      tester.element(find.byIcon(Icons.delete_outline)),
    );
    expect(icon.color ?? theme.color, lightColorScheme.onPrimary);

    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(LoadingIconButton),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.color, lightColorScheme.primary);
  });

  testWidgets('a disabled filled icon uses the disabled fill', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme,
        home: const Scaffold(
          body: LoadingIconButton(onPressed: null, icon: Icon(Icons.add)),
        ),
      ),
    );

    final button = tester.widget<IconButton>(find.byType(IconButton));
    expect(button.onPressed, isNull);
    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(LoadingIconButton),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.color, lightColorScheme.surfaceContainerHighest);
  });
}
