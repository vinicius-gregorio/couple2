import 'dart:async';
import 'dart:io';

import 'package:couple2_app/app/provider_load.dart';
import 'package:couple2_app/core/errors/user_facing_error.dart';
import 'package:couple2_app/core/external/http_client/exceptions/cpl_http_no_internet_connection_exception.dart';
import 'package:couple2_app/design_system/design_system.dart';
import 'package:couple2_app/modules/lists/domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lib checkables stay inside MutationCheckbox and MutationSwitch', () {
    final pattern = RegExp(
      r'\b(Checkbox|Switch|CheckboxListTile|SwitchListTile)\b',
    );
    const allow = {'lib/design_system/widgets/mutation_check.dart'};
    final hits = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final normalized = entity.path.replaceAll('\\', '/');
      final rel = normalized.substring(normalized.indexOf('lib/'));
      if (allow.contains(rel)) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (pattern.hasMatch(lines[i])) {
          hits.add('$rel:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });

  test('session loads do not retry and share one in-flight call', () async {
    expect(noProviderRetry(0, Exception('offline')), isNull);
    expect(noProviderRetry(12, Exception('offline')), isNull);
    Future<int>? slot;
    var calls = 0;
    Future<int> start() async {
      calls++;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return 7;
    }

    final first = shareInFlight(
      current: slot,
      read: () => slot,
      store: (flight) => slot = flight,
      start: start,
    );
    final second = shareInFlight(
      current: slot,
      read: () => slot,
      store: (flight) => slot = flight,
      start: start,
    );
    expect(await first, 7);
    expect(await second, 7);
    expect(calls, 1);
    expect(slot, isNull);
  });

  test('an explicit empty list replaces local items', () {
    final local = [
      _list(items: [_item('bread', 'Pão')]),
    ];
    final omitted = [
      _list(items: const [], itemsIncluded: false),
    ];
    expect(preserveLocalItems(local, omitted).single.items, hasLength(1));

    final emptied = [
      _list(items: const []),
    ];
    expect(preserveLocalItems(local, emptied).single.items, isEmpty);
  });

  testWidgets('spinner keeps a fixed ring and the button keeps its size', (
    tester,
  ) async {
    final gate = Completer<void>();
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme,
        home: Scaffold(
          body: LoadingButton(
            onPressed: () => gate.future,
            child: const Text('Salvar'),
          ),
        ),
      ),
    );
    final button = find.widgetWithText(FilledButton, 'Salvar');
    final idle = tester.getSize(button);
    await tester.tap(button);
    await tester.pump();
    final spinner = find.byKey(LoadingButton.spinnerKey);
    expect(tester.getSize(spinner).shortestSide, greaterThanOrEqualTo(22));
    final indicator = tester.widget<CircularProgressIndicator>(
      find.descendant(
        of: spinner,
        matching: find.byType(CircularProgressIndicator),
      ),
    );
    expect(indicator.strokeWidth, greaterThanOrEqualTo(2));
    expect(tester.getSize(button), idle);
    expect(find.text('Salvar'), findsOneWidget);
    gate.complete();
    await tester.pump();
  });

  testWidgets('a load failure uses the shared Portuguese message', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AsyncBody(
          isLoading: false,
          error: CPLHttpNoInternetConnectionException(),
          errorMessage: 'Não foi possível carregar as listas.',
          child: Text('dados'),
        ),
      ),
    );
    expect(find.text(offlineUserMessage), findsOneWidget);
    expect(find.text('Não foi possível carregar as listas.'), findsNothing);
    expect(find.text('dados'), findsNothing);
  });

  testWidgets('an error overlay does not move the next row', (tester) async {
    const line = Key('next-row');
    Widget page(String? message) {
      return MaterialApp(
        theme: lightTheme,
        home: Scaffold(
          body: Column(
            children: [
              MutationErrorBanner(message: message),
              const SizedBox(key: line, height: 24, child: Text('linha')),
            ],
          ),
        ),
      );
    }

    await tester.pumpWidget(page(null));
    await tester.pump();
    expect(tester.getSize(find.byType(MutationErrorBanner)).height, 0);
    final before = tester.getTopLeft(find.byKey(line));

    await tester.pumpWidget(page(offlineUserMessage));
    await tester.pump();
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(line)), before);
    expect(find.text(offlineUserMessage), findsOneWidget);
    expect(tester.getSize(find.byType(MutationErrorBanner)).height, 0);
  });
}

PartnerList _list({
  required List<ListItem> items,
  bool itemsIncluded = true,
}) {
  return PartnerList(
    id: 'list-1',
    type: 'SHOPPING_CART',
    name: 'Mercado',
    ownerId: 'ada',
    items: items,
    createdAt: DateTime.utc(2026, 1, 1),
    itemsIncluded: itemsIncluded,
  );
}

ListItem _item(String id, String content) {
  return ListItem(
    id: id,
    listId: 'list-1',
    content: content,
    isCompleted: false,
    addedById: 'ada',
    createdAt: DateTime.utc(2026, 1, 2),
  );
}
