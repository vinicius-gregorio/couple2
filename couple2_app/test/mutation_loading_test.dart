import 'dart:async';
import 'dart:io';

import 'package:couple2_app/core/errors/user_facing_error.dart';
import 'package:couple2_app/core/external/http_client/exceptions/cpl_http_no_internet_connection_exception.dart';
import 'package:couple2_app/app/session.dart';
import 'package:couple2_app/app/session_provider.dart';
import 'package:couple2_app/design_system/design_system.dart';
import 'package:couple2_app/modules/couple/data/couple_providers.dart';
import 'package:couple2_app/modules/couple/data/couple_repository.dart';
import 'package:couple2_app/modules/couple/domain/domain.dart';
import 'package:couple2_app/modules/couple/ui/pages/couple_settings/couple_settings_page.dart';
import 'package:couple2_app/modules/couple/ui/pages/important_dates/important_dates_page.dart';
import 'package:couple2_app/modules/couple/ui/widgets/profile_sheet.dart';
import 'package:couple2_app/modules/daily_question/data/daily_question_providers.dart';
import 'package:couple2_app/modules/daily_question/data/daily_question_repository.dart';
import 'package:couple2_app/modules/daily_question/domain/domain.dart';
import 'package:couple2_app/modules/daily_question/ui/pages/history/question_history_page.dart';
import 'package:couple2_app/modules/daily_question/ui/pages/today/today_question_page.dart';
import 'package:couple2_app/modules/date_plans/data/date_plans_providers.dart';
import 'package:couple2_app/modules/date_plans/data/date_plans_repository.dart';
import 'package:couple2_app/modules/date_plans/domain/domain.dart';
import 'package:couple2_app/modules/date_plans/ui/pages/date_plan_detail/date_plan_detail_page.dart';
import 'package:couple2_app/modules/date_plans/ui/pages/date_plan_form/date_plan_form_page.dart';
import 'package:couple2_app/modules/lists/data/lists_providers.dart';
import 'package:couple2_app/modules/lists/data/lists_repository.dart';
import 'package:couple2_app/modules/lists/domain/domain.dart';
import 'package:couple2_app/modules/lists/ui/pages/list_detail/list_detail_page.dart';
import 'package:couple2_app/modules/lists/ui/pages/lists/lists_page.dart';
import 'package:couple2_app/modules/mood/data/mood_providers.dart';
import 'package:couple2_app/modules/mood/data/mood_repository.dart';
import 'package:couple2_app/modules/mood/data/nudges_repository.dart';
import 'package:couple2_app/modules/mood/domain/domain.dart';
import 'package:couple2_app/modules/mood/ui/widgets/mood_home_card.dart';
import 'package:couple2_app/modules/mood/ui/widgets/mood_picker_sheet.dart';
import 'package:couple2_app/modules/notifications/data/notifications_providers.dart';
import 'package:couple2_app/modules/notifications/data/notifications_repository.dart';
import 'package:couple2_app/modules/notifications/domain/domain.dart';
import 'package:couple2_app/modules/notifications/ui/pages/notification_preferences/notification_preferences_page.dart';
import 'package:couple2_app/modules/pairing/data/pairing_providers.dart';
import 'package:couple2_app/modules/pairing/data/pairing_repository.dart';
import 'package:couple2_app/modules/pairing/domain/domain.dart';
import 'package:couple2_app/modules/pairing/ui/pages/enter_code/enter_code_page.dart';
import 'package:couple2_app/modules/pairing/ui/pages/waiting/waiting_page.dart';
import 'package:couple2_app/modules/pairing/ui/widgets/generate_pairing_code_button.dart';
import 'package:couple2_app/modules/pairing/ui/widgets/unpair_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A request that stays pending until [error] so a test can tap twice.
class Gate {
  final _done = Completer<void>();
  var calls = 0;

  Future<T> hang<T>() {
    calls++;
    return _done.future.then((_) => throw StateError('unreachable'));
  }

  void error() {
    if (!_done.isCompleted) _done.completeError(Exception('fail'));
  }

  void fail(Object error) {
    if (!_done.isCompleted) _done.completeError(error);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('list item text has no edit endpoint', () {
    // PATCH /lists/items/:id only toggles completion. There is no content edit.
    final source = File(
      'lib/modules/lists/data/lists_repository.dart',
    ).readAsStringSync();
    expect(source.contains('updateItem'), isFalse);
    expect(source.contains('Future<ListItem> addItem'), isTrue);
    expect(source.contains('toggleItem'), isTrue);
    expect(source.contains('deleteItem'), isTrue);
  });

  testWidgets('slow add locks every control on the list and sends once', (
    tester,
  ) async {
    final gate = Gate();
    await _pump(
      tester,
      _listsScope(
        _ListsRepo(
          gate,
          op: 'add',
          lists: [
            _list(items: [_item('a', 'Pão'), _item('b', 'Leite')]),
          ],
        ),
        const ListDetailPage(listId: 'list-1'),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Café');
    await tester.pump();
    await _doubleTap(tester, find.byTooltip('Adicionar'));
    expect(gate.calls, 1);
    IconButton icon(String tooltip) {
      return tester.widget<IconButton>(
        find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == tooltip,
        ),
      );
    }

    expect(icon('Voltar').onPressed, isNull);
    expect(icon('Adicionar').onPressed, isNull);
    for (final button in tester.widgetList<IconButton>(
      find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'Excluir item',
      ),
    )) {
      expect(button.onPressed, isNull);
    }
    expect(find.byTooltip('Excluir item'), findsNWidgets(3));
    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.enabled, isFalse);
    }
    gate.error();
    await _settle(tester);
  });

  testWidgets('add list item shows a pending row, locks, and rolls back', (
    tester,
  ) async {
    final gate = Gate();
    await _pump(
      tester,
      _listsScope(
        _ListsRepo(gate, op: 'add', lists: [_list()]),
        const ListDetailPage(listId: 'list-1'),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Leite');
    await tester.pump();
    await _doubleTap(tester, find.byTooltip('Adicionar'));
    expect(gate.calls, 1);
    expect(find.text('Leite'), findsWidgets);
    expect(find.text('Salvando…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(_icon(tester, 'Adicionar').onPressed, isNull);
    gate.error();
    await _settle(tester);
    expectInlineError(tester, fallbackUserMessage);
    expect(find.text('Salvando…'), findsNothing);
    expect(find.text('Leite'), findsOneWidget);
    expect(find.text('Nenhum item ainda.'), findsOneWidget);
  });

  testWidgets('check list item flips, locks, and restores on failure', (
    tester,
  ) async {
    final gate = Gate();
    await _pump(
      tester,
      _listsScope(
        _ListsRepo(
          gate,
          op: 'toggle',
          lists: [
            _list(items: [_item('bread', 'Pão')]),
          ],
        ),
        const ListDetailPage(listId: 'list-1'),
      ),
    );
    await _doubleTap(tester, find.byType(Checkbox));
    expect(gate.calls, 1);
    expect(find.byKey(const Key('item-pending')), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    gate.error();
    await _settle(tester);
    expectInlineError(tester, fallbackUserMessage);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    expect(find.text('Pão'), findsOneWidget);
  });

  testWidgets('slow check locks every control and keeps the row height', (
    tester,
  ) async {
    final gate = Gate();
    await _pump(
      tester,
      _listsScope(
        _ListsRepo(
          gate,
          op: 'toggle',
          lists: [
            _list(items: [_item('a', 'Pão'), _item('b', 'Leite')]),
          ],
        ),
        const ListDetailPage(listId: 'list-1'),
      ),
    );
    final row = find.byKey(const Key('list-item-a'));
    final before = tester.getSize(row);
    await tester.tap(find.byType(Checkbox).first);
    await tester.tap(find.byType(Checkbox).first, warnIfMissed: false);
    await tester.pump();
    expect(gate.calls, 1);
    expect(tester.getSize(row), before);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final other = tester.widget<Checkbox>(find.byType(Checkbox));
    final otherContext = tester.element(find.byType(Checkbox));
    final scheme = Theme.of(otherContext).colorScheme;
    final side = Theme.of(otherContext).checkboxTheme.side;
    final border = side is WidgetStateBorderSide
        ? side.resolve({WidgetState.disabled})
        : side;
    expect(other.onChanged, isNull);
    expect(border?.color, isNot(scheme.primary));
    expect(
      tester.widget<IconButton>(
        find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == 'Voltar',
        ),
      ).onPressed,
      isNull,
    );
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
    for (final button in tester.widgetList<IconButton>(
      find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'Excluir item',
      ),
    )) {
      expect(button.onPressed, isNull);
    }
    gate.error();
    await _settle(tester);
    expect(find.text(offlineUserMessage), findsNothing);
    expect(tester.widgetList<Checkbox>(find.byType(Checkbox)), hasLength(2));
    expect(
      tester.widgetList<Checkbox>(find.byType(Checkbox)).first.value,
      isFalse,
    );
  });

  testWidgets('delete list item stays pending and comes back on failure', (
    tester,
  ) async {
    final gate = Gate();
    await _pump(
      tester,
      _listsScope(
        _ListsRepo(
          gate,
          op: 'delete',
          lists: [
            _list(items: [_item('bread', 'Pão')]),
          ],
        ),
        const ListDetailPage(listId: 'list-1'),
      ),
    );
    await tester.tap(find.byTooltip('Excluir item'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(gate.calls, 0);
    expect(find.text('Excluir item?'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.text('Cancelar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(gate.calls, 0);
    expect(find.text('Pão'), findsOneWidget);
    await tester.tap(find.byTooltip('Excluir item'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('confirm-delete-bread')));
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('confirm-delete-bread')),
      warnIfMissed: false,
    );
    expect(gate.calls, 1);
    expect(find.text('Pão'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    gate.error();
    await _settle(tester);
    expectInlineError(tester, fallbackUserMessage);
    expect(find.text('Pão'), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
  });

  testWidgets('create list locks the button and keeps the sheet on failure', (
    tester,
  ) async {
    final gate = Gate();
    await _pump(
      tester,
      _listsScope(_ListsRepo(gate, op: 'create'), const ListsPage()),
    );
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField), 'Mercado');
    await tester.pump();
    await _doubleTap(tester, find.text('Criar'));
    expect(gate.calls, 1);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(_filled(tester, 'Criar').onPressed, isNull);
    gate.error();
    await _settle(tester);
    expectInlineError(tester, fallbackUserMessage, count: findsWidgets);
    expect(find.text('Nova lista'), findsOneWidget);
  });

  testWidgets('delete list keeps the card and shows a PT-BR error', (
    tester,
  ) async {
    final gate = Gate();
    await _pump(
      tester,
      _listsScope(
        _ListsRepo(
          gate,
          op: 'delete-list',
          lists: [_list(name: 'Mercado')],
        ),
        const ListsPage(),
      ),
    );
    expect(find.text('Mercado'), findsOneWidget);
    await tester.tap(find.byTooltip('Excluir lista'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(gate.calls, 0);
    expect(find.text('Excluir lista?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-delete-list')));
    await tester.pump();
    expect(_icon(tester, 'Excluir lista').onPressed, isNull);
    expect(gate.calls, 1);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    gate.error();
    await _settle(tester);
    expectInlineError(tester, fallbackUserMessage);
    expect(find.text('Mercado'), findsOneWidget);
  });

  testWidgets('slow list delete locks every control and sends once', (
    tester,
  ) async {
    final gate = Gate();
    await _pump(
      tester,
      _listsScope(
        _ListsRepo(
          gate,
          op: 'delete-list',
          lists: [
            _list(name: 'Mercado'),
            _list(id: 'list-2', type: 'MOVIES', name: 'Filmes'),
          ],
        ),
        const ListsPage(),
      ),
    );
    expect(find.text('Mercado'), findsOneWidget);
    expect(find.text('Filmes'), findsOneWidget);
    final deletes = find.ancestor(
      of: find.byTooltip('Excluir lista'),
      matching: find.byType(IconButton),
    );
    expect(deletes, findsNWidgets(2));
    await tester.tap(deletes.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(gate.calls, 0);
    expect(find.text('Excluir lista?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-delete-list')));
    await tester.pump();
    expect(gate.calls, 1);
    expect(_icon(tester, 'Voltar').onPressed, isNull);
    expect(
      tester
          .widget<FloatingActionButton>(find.byType(FloatingActionButton))
          .onPressed,
      isNull,
    );
    expect(
      tester.widgetList<IconButton>(deletes).every(
        (button) => button.onPressed == null,
      ),
      isTrue,
    );
    expect(
      tester
          .widgetList<InkWell>(
            find.descendant(
              of: find.byType(Card),
              matching: find.byType(InkWell),
            ),
          )
          .every((ink) => ink.onTap == null),
      isTrue,
    );
    await tester.tap(deletes.at(1), warnIfMissed: false);
    await tester.pump();
    expect(gate.calls, 1);
    gate.error();
    await _settle(tester);
    expectInlineError(tester, fallbackUserMessage);
    expect(find.text('Mercado'), findsOneWidget);
    expect(find.text('Filmes'), findsOneWidget);
  });

  testWidgets('gift idea add locks and rolls the draft back', (tester) async {
    final gate = Gate();
    final repo = _ListsRepo(
      gate,
      op: 'add',
      lists: [_list(type: 'GIFT_IDEAS', name: 'Presentes')],
    );
    await _pump(
      tester,
      _listsScope(repo, const ListDetailPage(listId: 'list-1')),
    );
    await tester.enterText(find.byType(TextField).at(0), '12,50');
    await tester.enterText(find.byType(TextField).last, 'Flores');
    await tester.pump();
    await _doubleTap(tester, find.byTooltip('Adicionar'));
    expect(gate.calls, 1);
    expect(repo.lastMetadata?['price'], 12.5);
    expect(find.text('Salvando…'), findsOneWidget);
    gate.error();
    await _settle(tester);
    expectInlineError(tester, fallbackUserMessage);
    expect(find.text('Flores'), findsOneWidget);
    expect(find.text('Salvando…'), findsNothing);
  });

  testWidgets('carinho shows a spinner and does not send twice', (
    tester,
  ) async {
    final gate = Gate();
    await _pump(
      tester,
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(_Session.new),
          currentMoodProvider.overrideWith((ref) async => _lowMood),
          nudgesRepositoryProvider.overrideWithValue(_NudgesRepo(gate)),
        ],
        child: const MaterialApp(home: Scaffold(body: MoodHomeCard())),
      ),
    );
    await tester.pump();
    await _doubleTap(tester, find.text('💗 Pensando em você'));
    expect(gate.calls, 1);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(_filled(tester, '💗 Pensando em você').onPressed, isNull);
    gate.error();
    await _settle(tester);
    expectInlineError(tester, fallbackUserMessage);
    expect(find.text('💗 Pensando em você'), findsOneWidget);
  });

  testWidgets('mood save stays open and shows a PT-BR error', (tester) async {
    final gate = Gate();
    await _pump(
      tester,
      ProviderScope(
        overrides: [moodRepositoryProvider.overrideWithValue(_MoodRepo(gate))],
        child: const MaterialApp(home: Scaffold(body: MoodPickerSheet())),
      ),
    );
    await tester.enterText(find.byType(TextField), 'saudade');
    await tester.pump();
    await _doubleTap(tester, find.text('Compartilhar'));
    expect(gate.calls, 1);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(_filled(tester, 'Compartilhar').onPressed, isNull);
    final sheet = tester.getSize(find.byType(MoodPickerSheet));
    gate.error();
    await _settle(tester);
    expectInlineError(tester, fallbackUserMessage);
    expect(find.text('Como você está?'), findsOneWidget);
    expect(find.text('saudade'), findsOneWidget);
    expect(tester.getSize(find.byType(MoodPickerSheet)), sheet);
    expect(find.text('Fechar'), findsOneWidget);
  });

  testWidgets('question answer locks the field and keeps the draft', (
    tester,
  ) async {
    final gate = Gate();
    await _pump(
      tester,
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(_Session.new),
          dailyQuestionRepositoryProvider.overrideWithValue(
            _QuestionRepo(gate, answered: false),
          ),
        ],
        child: const MaterialApp(home: TodayQuestionPage()),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'O café');
    await tester.pump();
    await _doubleTap(tester, find.text('Enviar'));
    expect(gate.calls, 1);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(_filled(tester, 'Enviar').onPressed, isNull);
    gate.error();
    await _settle(tester);
    expectInlineError(tester, fallbackUserMessage);
    expect(find.text('O café'), findsOneWidget);
    expect(find.text('Enviar'), findsOneWidget);
  });

  testWidgets('editing a past answer rolls back to the saved text', (
    tester,
  ) async {
    final gate = Gate();
    await _pump(
      tester,
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(_Session.new),
          dailyQuestionRepositoryProvider.overrideWithValue(
            _QuestionRepo(gate, answered: true),
          ),
        ],
        child: const MaterialApp(home: QuestionHistoryPage()),
      ),
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Editar'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Texto novo');
    await tester.pump();
    await _doubleTap(tester, find.widgetWithText(FilledButton, 'Salvar'));
    expect(gate.calls, 1);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    gate.error();
    await _settle(tester);
    expectInlineError(tester, fallbackUserMessage);
    expect(find.text('Texto novo'), findsOneWidget);
  });

  testWidgets('creating a date locks Salvar and stays on the form', (
    tester,
  ) async {
    final gate = Gate();
    await _pump(tester, _dateScope(gate, const DatePlanFormPage()));
    await tester.enterText(find.byType(TextField).first, 'Jantar');
    await tester.pump();
    await _doubleTap(tester, find.text('Salvar'));
    expect(gate.calls, 1);
    expect(_filled(tester, 'Salvar').onPressed, isNull);
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byTooltip('Voltar'),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNull,
    );
    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.enabled, isFalse);
    }
    gate.error();
    await _settle(tester);
    expectInlineError(tester, fallbackUserMessage);
    expect(find.text('Jantar'), findsOneWidget);
    expect(find.text('Planejar um encontro'), findsOneWidget);
  });

  testWidgets('editing a date keeps the form when the save fails', (
    tester,
  ) async {
    final gate = Gate();
    await _pump(
      tester,
      _dateScope(gate, DatePlanFormPage(existing: _plan(proposerId: 'ada'))),
    );
    await tester.enterText(find.byType(TextField).first, 'Jantar cedo');
    await tester.pump();
    await _doubleTap(tester, find.text('Salvar'));
    expect(gate.calls, 1);
    gate.error();
    await _settle(tester);
    expectInlineError(tester, fallbackUserMessage);
    expect(find.text('Editar o encontro'), findsOneWidget);
    expect(find.text('Jantar cedo'), findsOneWidget);
  });

  testWidgets('accepting a date locks every RSVP control', (tester) async {
    final gate = Gate();
    await _pumpDetail(tester, gate, _plan());
    await _doubleTap(tester, find.text('Aceitar'));
    expect(gate.calls, 1);
    expect(_filled(tester, 'Aceitar').onPressed, isNull);
    expect(_outlined(tester, 'Recusar').onPressed, isNull);
    gate.error();
    await _settle(tester);
    expectInlineError(tester, fallbackUserMessage);
    expect(find.text('Proposto'), findsOneWidget);
  });

  testWidgets('declining a date sends once and keeps the proposal', (
    tester,
  ) async {
    final gate = Gate();
    await _pumpDetail(tester, gate, _plan());
    await tester.tap(find.widgetWithText(OutlinedButton, 'Recusar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(FilledButton, 'Recusar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Recusar'),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(gate.calls, 1);
    gate.error();
    await _settle(tester);
    expectInlineError(tester, fallbackUserMessage);
    expect(find.text('Proposto'), findsOneWidget);
  });

  testWidgets('suggesting another time sends one counter', (tester) async {
    final gate = Gate();
    await _pumpDetail(tester, gate, _plan());
    await tester.tap(find.text('Sugerir outro horário'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final day = DateTime.now().add(const Duration(days: 10)).day.toString();
    await tester.tap(find.text(day).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('OK'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Sugerir'));
    await tester.pump();
    expect(gate.calls, 1);
    gate.error();
    await _settle(tester);
    expectInlineError(tester, fallbackUserMessage);
    expect(find.text('Proposto'), findsOneWidget);
  });

  testWidgets('cancelling a date keeps it on screen when the request fails', (
    tester,
  ) async {
    final gate = Gate();
    await _pumpDetail(tester, gate, _plan(proposerId: 'ada'));
    await tester.tap(find.text('Cancelar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(FilledButton), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Cancelar'));
    await tester.pump();
    expect(gate.calls, 1);
    expect(
      tester
          .widgetList<LoadingButton>(
            find.widgetWithText(LoadingButton, 'Cancelar'),
          )
          .where((button) => button.loading),
      hasLength(1),
    );
    expect(
      tester
          .widget<LoadingButton>(find.widgetWithText(LoadingButton, 'Editar'))
          .loading,
      isFalse,
    );
    gate.error();
    await _settle(tester);
    expectInlineError(tester, fallbackUserMessage);
    expect(find.text('Jantar'), findsOneWidget);
    expect(find.text('Proposto'), findsOneWidget);
  });

  testWidgets('marking a date done locks and restores the confirmed status', (
    tester,
  ) async {
    final gate = Gate();
    await _pumpDetail(
      tester,
      gate,
      _plan(status: DatePlanStatus.accepted, proposerId: 'ada'),
    );
    await _doubleTap(tester, find.text('Marcar como feito'));
    expect(gate.calls, 1);
    expect(_filled(tester, 'Marcar como feito').onPressed, isNull);
    gate.error();
    await _settle(tester);
    expectInlineError(tester, fallbackUserMessage);
    expect(find.text('Confirmado'), findsOneWidget);
  });

  testWidgets('creating an important date shows Salvando and rolls back', (
    tester,
  ) async {
    final gate = Gate();
    await _pump(tester, _coupleScope(gate, const ImportantDatesPage()));
    await tester.pump();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField), 'Lua de mel');
    await tester.pump();
    await tester.tap(find.text('Adicionar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byType(FloatingActionButton), warnIfMissed: false);
    expect(gate.calls, 1);
    expect(find.byKey(LoadingButton.spinnerKey), findsWidgets);
    expect(find.text('Adicionar'), findsWidgets);
    gate.error();
    await _settle(tester);
    expectInlineError(tester, fallbackUserMessage);
    expect(find.text('Lua de mel'), findsOneWidget);
    expect(find.text('Nova data'), findsOneWidget);
  });

  testWidgets('editing an important date restores the previous title', (
    tester,
  ) async {
    final gate = Gate();
    await _pump(
      tester,
      _coupleScope(
        gate,
        const ImportantDatesPage(),
        dates: [_coupleDate('Natal')],
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Editar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField), 'Natal cedo');
    await tester.pump();
    await tester.tap(find.text('Salvar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(gate.calls, 1);
    expect(find.byKey(LoadingButton.spinnerKey), findsWidgets);
    gate.error();
    await _settle(tester);
    expectInlineError(tester, fallbackUserMessage);
    expect(find.text('Editar data'), findsOneWidget);
    expect(find.text('Natal cedo'), findsOneWidget);
  });

  testWidgets('deleting an important date restores the row', (tester) async {
    final gate = Gate();
    await _pump(
      tester,
      _coupleScope(
        gate,
        const ImportantDatesPage(),
        dates: [_coupleDate('Natal')],
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Excluir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('confirm-delete-date')));
    await tester.pump();
    expect(gate.calls, 1);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    gate.error();
    await _settle(tester);
    expectInlineError(tester, fallbackUserMessage);
    expect(find.text('Natal'), findsWidgets);
  });

  testWidgets('slow date delete disables the other row in semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final gate = Gate();
    try {
    await _pump(
      tester,
      _coupleScope(
        gate,
        const ImportantDatesPage(),
        dates: [
          _coupleDate('Natal'),
          const CoupleDate(
            id: 'date-2',
            coupleId: 'couple-1',
            type: 'CUSTOM',
            title: 'Ano novo',
            date: '2026-01-01',
            recurrence: 'YEARLY',
            createdById: 'ada',
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Excluir').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('confirm-delete-date')));
    await tester.pump();
    expect(gate.calls, 1);
    final node = tester.getSemantics(
      find.byKey(const Key('date-row-date-2')),
    );
    expect(node.flagsCollection.isEnabled, isFalse);
    for (final button in tester.widgetList<IconButton>(
      find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'Editar',
      ),
    )) {
      expect(button.onPressed, isNull);
    }
    gate.error();
    await _settle(tester);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('profile birth date shows a spinner and an error', (
    tester,
  ) async {
    final gate = Gate();
    await _pump(
      tester,
      _coupleScope(
        gate,
        Scaffold(
          body: ProfileSheet(
            session: const Session(
              id: 'ada',
              email: 'ada@example.com',
              name: 'Ada',
              isPaired: true,
              coupleId: 'couple-1',
              birthDate: '1990-05-02',
            ),
          ),
        ),
      ),
    );
    await _doubleTap(tester, find.text('Salvar'));
    expect(gate.calls, 1);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    gate.error();
    await _settle(tester);
    expectInlineError(tester, fallbackUserMessage);
    expect(find.text('Ada'), findsOneWidget);
  });

  testWidgets('couple start date save locks and reports the error', (
    tester,
  ) async {
    final gate = Gate();
    await _pump(tester, _coupleScope(gate, const CoupleSettingsPage()));
    await tester.pump();
    await _doubleTap(tester, find.text('Salvar'));
    expect(gate.calls, 1);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    gate.error();
    await _settle(tester);
    expectInlineError(tester, fallbackUserMessage);
    expect(find.textContaining('Confira o fuso'), findsNothing);
    expect(find.text('Nosso começo'), findsOneWidget);
  });

  testWidgets('generating a pairing code locks and explains the failure', (
    tester,
  ) async {
    final gate = Gate();
    await _pump(
      tester,
      _pairingScope(
        gate,
        const Scaffold(body: GeneratePairingCodeButton()),
      ),
    );
    await _doubleTap(tester, find.text('Gerar código'));
    expect(gate.calls, 1);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    gate.error();
    await _settle(tester);
    expectInlineError(
      tester,
      'Não foi possível gerar o código. Tente de novo.',
    );
  });

  testWidgets('entering a partner code sends once', (tester) async {
    final gate = Gate();
    await _pump(tester, _pairingScope(gate, const EnterCodePage()));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'XYZ123');
    await tester.pump();
    await _doubleTap(tester, find.text('Enviar pedido'));
    expect(gate.calls, 1);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    gate.error();
    await _settle(tester);
    expectInlineError(tester, 'Não foi possível parear agora. Tente de novo.');
    expect(find.text('XYZ123'), findsOneWidget);
  });

  testWidgets('cancelling a pairing request locks and stays on the page', (
    tester,
  ) async {
    final gate = Gate();
    await _pump(
      tester,
      _pairingScope(gate, const WaitingPage(), pending: true),
    );
    await tester.pump();
    await tester.tap(find.text('Cancelar pedido'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(gate.calls, 0);
    expect(find.text('Cancelar pedido?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-cancel-pairing')));
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('confirm-cancel-pairing')),
      warnIfMissed: false,
    );
    expect(gate.calls, 1);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    gate.error();
    await _settle(tester);
    expectInlineError(
      tester,
      'Não foi possível cancelar o pedido. Tente de novo.',
    );
    expect(find.text('Aguardando confirmação'), findsOneWidget);
  });

  testWidgets('unpair confirms once and restores the button on failure', (
    tester,
  ) async {
    final gate = Gate();
    await _pump(
      tester,
      _pairingScope(gate, const Scaffold(body: UnpairButton())),
    );
    await tester.tap(find.text('Desfazer o par'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('confirm-unpair')));
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('unpair-button')),
      warnIfMissed: false,
    );
    expect(gate.calls, 1);
    expect(find.byKey(LoadingButton.spinnerKey), findsOneWidget);
    expect(find.text('Desfazer o par'), findsWidgets);
    expect(
      tester
          .widget<LoadingButton>(find.byKey(const Key('unpair-button')))
          .onPressed,
      isNull,
    );
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    gate.error();
    await _settle(tester);
    expectInlineError(tester, 'Não foi possível desfazer o par. Tente de novo.');
    expect(find.text('Desfazer o par'), findsOneWidget);
  });

  testWidgets('notification preference rolls back and disables the switch', (
    tester,
  ) async {
    final gate = Gate();
    await _pump(
      tester,
      ProviderScope(
        overrides: [
          notificationsRepositoryProvider.overrideWithValue(_NotesRepo(gate)),
        ],
        child: const MaterialApp(home: NotificationPreferencesPage()),
      ),
    );
    await tester.pump();
    final alertas = find.widgetWithText(MutationSwitch, 'Alertas');
    final before = tester.widget<MutationSwitch>(alertas).value;
    await tester.tap(find.text('Alertas'));
    await tester.pump();
    await tester.tap(find.text('Alertas'), warnIfMissed: false);
    expect(gate.calls, 1);
    expect(
      find.descendant(of: alertas, matching: find.byType(Switch)),
      findsNothing,
    );
    expect(find.byKey(LoadingButton.spinnerKey), findsWidgets);
    final other = tester.widget<Switch>(
      find.descendant(
        of: find.widgetWithText(MutationSwitch, 'Listas'),
        matching: find.byType(Switch),
      ),
    );
    expect(other.onChanged, isNull);
    gate.fail(const CPLHttpNoInternetConnectionException());
    await _settle(tester);
    expectInlineError(tester, offlineUserMessage);
    expect(tester.widget<MutationSwitch>(alertas).value, before);
    expect(
      tester
          .widget<Switch>(
            find.descendant(of: alertas, matching: find.byType(Switch)),
          )
          .value,
      before,
    );
  });
}

Future<void> _pump(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(900, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(app);
  await tester.pump();
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump();
}

/// Page failures stay a floating SnackBar. A sheet shows the same message
/// inline, above its send button, and does not cover the fields with a bar.
void expectInlineError(
  WidgetTester tester,
  String message, {
  Matcher count = findsOneWidget,
}) {
  expect(find.text(message), count);
  final inSheet = find.byType(AppSheetScope).evaluate().isNotEmpty;
  expect(find.byType(SnackBar), inSheet ? findsNothing : findsWidgets);
}

Future<void> _doubleTap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.tap(finder, warnIfMissed: false);
  await tester.pump();
}

FilledButton _filled(WidgetTester tester, String label) {
  return tester.widget<FilledButton>(find.widgetWithText(FilledButton, label));
}

OutlinedButton _outlined(WidgetTester tester, String label) {
  return tester.widget<OutlinedButton>(
    find.widgetWithText(OutlinedButton, label),
  );
}

IconButton _icon(WidgetTester tester, String tooltip) {
  return tester.widget<IconButton>(
    find.ancestor(
      of: find.byTooltip(tooltip),
      matching: find.byType(IconButton),
    ),
  );
}

Widget _listsScope(_ListsRepo repo, Widget home) {
  return ProviderScope(
    overrides: [listsRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(theme: lightTheme, home: home),
  );
}

Widget _dateScope(Gate gate, Widget home) {
  return ProviderScope(
    overrides: [
      sessionProvider.overrideWith(_Session.new),
      datePlansRepositoryProvider.overrideWithValue(_DatesRepo(gate)),
    ],
    child: MaterialApp(theme: lightTheme, home: home),
  );
}

Future<void> _pumpDetail(WidgetTester tester, Gate gate, DatePlan plan) async {
  await _pump(
    tester,
    ProviderScope(
      overrides: [
        sessionProvider.overrideWith(_Session.new),
        datePlansRepositoryProvider.overrideWithValue(
          _DatesRepo(gate, plan: plan),
        ),
      ],
      child: MaterialApp(
        theme: lightTheme,
        home: const DatePlanDetailPage(id: 'plan-1'),
      ),
    ),
  );
  for (var frame = 0; frame < 6; frame++) {
    final ready =
        find.text('Jantar').evaluate().isNotEmpty &&
        find.text('Entre de novo para responder.').evaluate().isEmpty &&
        (find.text('Aceitar').evaluate().isNotEmpty ||
            find.text('Editar').evaluate().isNotEmpty ||
            find.text('Marcar como feito').evaluate().isNotEmpty);
    if (ready) return;
    await tester.pump();
  }
}

Widget _coupleScope(
  Gate gate,
  Widget home, {
  List<CoupleDate> dates = const [],
}) {
  return ProviderScope(
    overrides: [
      sessionProvider.overrideWith(_Session.new),
      coupleProvider.overrideWith((ref) async => _couple),
      coupleRepositoryProvider.overrideWithValue(_CoupleRepo(gate, dates)),
    ],
    child: MaterialApp(theme: lightTheme, home: home),
  );
}

Widget _pairingScope(Gate gate, Widget home, {bool pending = false}) {
  return ProviderScope(
    overrides: [
      sessionProvider.overrideWith(_Session.new),
      pairingPollIntervalProvider.overrideWithValue(null),
      pairingRepositoryProvider.overrideWithValue(
        _PairingRepo(gate, pending: pending),
      ),
    ],
    child: MaterialApp(theme: lightTheme, home: home),
  );
}

class _Session extends SessionNotifier {
  @override
  Future<Session?> build() async {
    return const Session(
      id: 'ada',
      email: 'ada@example.com',
      name: 'Ada',
      isPaired: true,
      coupleId: 'couple-1',
      partnerName: 'Bruno',
    );
  }

  @override
  Future<void> refresh() async {}
}

PartnerList _list({
  String id = 'list-1',
  String type = 'SHOPPING_CART',
  String name = 'Mercado',
  List<ListItem> items = const [],
}) {
  return PartnerList(
    id: id,
    type: type,
    name: name,
    ownerId: 'ada',
    items: items,
    createdAt: DateTime.utc(2026, 1, 1),
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

DatePlan _plan({
  DatePlanStatus status = DatePlanStatus.proposed,
  String proposerId = 'partner',
}) {
  final when = DateTime.now().add(const Duration(days: 10));
  return DatePlan(
    id: 'plan-1',
    coupleId: 'couple-1',
    proposerId: proposerId,
    title: 'Jantar',
    scheduledAt: when,
    status: status,
    createdById: proposerId,
    createdAt: when,
    updatedAt: when,
  );
}

CoupleDate _coupleDate(String title) {
  return CoupleDate(
    id: 'date-1',
    coupleId: 'couple-1',
    type: 'CUSTOM',
    title: title,
    date: '2026-12-25',
    recurrence: 'YEARLY',
    createdById: 'ada',
  );
}

final _couple = Couple(
  id: 'couple-1',
  pairedAt: DateTime.utc(2024, 1, 1),
  anniversaryDate: '2024-01-01',
  timezone: 'America/Sao_Paulo',
  daysTogether: 650,
  partner: const CouplePartner(id: 'bruno', name: 'Bruno'),
  upcoming: const [],
);

final _lowMood = MoodCurrent(
  partner: MoodSnapshot(
    mood: MoodLevel.low,
    createdAt: DateTime.now(),
    stale: false,
  ),
);

class _ListsRepo implements IListsRepository {
  _ListsRepo(this.gate, {required this.op, this.lists = const []});

  final Gate gate;
  final String op;
  List<PartnerList> lists;
  Map<String, dynamic>? lastMetadata;

  Future<T> _maybe<T>(String name) {
    if (name == op) return gate.hang();
    throw StateError(name);
  }

  @override
  Future<List<PartnerList>> getLists() async => lists;

  @override
  Future<PartnerList> createList(
    String type,
    String name, {
    String? visibility,
  }) => _maybe('create');

  @override
  Future<ListItem> addItem(
    String listId,
    String content,
    Map<String, dynamic>? metadata,
  ) {
    lastMetadata = metadata;
    return _maybe('add');
  }

  @override
  Future<ListItem> toggleItem(String itemId) => _maybe('toggle');

  @override
  Future<void> deleteItem(String itemId) => _maybe('delete');

  @override
  Future<void> deleteList(String listId) => _maybe('delete-list');
}

class _DatesRepo implements IDatePlansRepository {
  _DatesRepo(this.gate, {this.plan});

  final Gate gate;
  final DatePlan? plan;

  @override
  Future<DatePlan> get(String id) async => plan!;

  @override
  Future<DatePlanPage> list({required String scope, String? cursor}) async {
    return const DatePlanPage(items: []);
  }

  @override
  Future<DatePlan> create({
    required String title,
    required DateTime scheduledAt,
    String? location,
    String? description,
    String? sourceListItemId,
  }) => gate.hang();

  @override
  Future<DatePlan> update(
    String id, {
    String? title,
    DateTime? scheduledAt,
    String? location,
    String? description,
    String? sourceListItemId,
    bool clearLocation = false,
    bool clearDescription = false,
    bool clearSource = false,
  }) => gate.hang();

  @override
  Future<DatePlan> accept(String id) => gate.hang();

  @override
  Future<DatePlan> decline(String id, {String? note}) => gate.hang();

  @override
  Future<DatePlan> counter(
    String id, {
    required DateTime scheduledAt,
    String? note,
  }) => gate.hang();

  @override
  Future<DatePlan> cancel(String id, {String? note}) => gate.hang();

  @override
  Future<DatePlan> done(String id) => gate.hang();
}

class _CoupleRepo implements ICoupleRepository {
  _CoupleRepo(this.gate, this.dates);

  final Gate gate;
  final List<CoupleDate> dates;

  @override
  Future<Couple> getCouple() async => _couple;

  @override
  Future<List<CoupleDate>> getDates() async => dates;

  @override
  Future<Couple> updateCouple({String? anniversaryDate, String? timezone}) =>
      gate.hang();

  @override
  Future<CoupleDate> createDate({
    required String title,
    required String date,
    String? recurrence,
  }) => gate.hang();

  @override
  Future<CoupleDate> updateDate(
    String id, {
    String? title,
    String? date,
    String? recurrence,
  }) => gate.hang();

  @override
  Future<void> deleteDate(String id) => gate.hang();

  @override
  Future<void> updateMyBirthDate(String? birthDate) => gate.hang();
}

class _QuestionRepo implements IDailyQuestionRepository {
  _QuestionRepo(this.gate, {required this.answered});

  final Gate gate;
  final bool answered;

  CoupleQuestion get _question {
    return CoupleQuestion(
      id: 'q1',
      date: '2026-10-15',
      question: const QuestionPrompt(
        text: 'O que te fez sorrir?',
        category: 'FUN',
      ),
      partnerAnswered: false,
      answerable: true,
      myAnswer: answered
          ? QuestionAnswer(
              text: 'antiga',
              createdAt: DateTime.utc(2026, 10, 15),
              updatedAt: DateTime.utc(2026, 10, 15),
            )
          : null,
    );
  }

  @override
  Future<CoupleQuestion> getToday() async => _question;

  @override
  Future<QuestionHistoryPageResult> history({
    String? cursor,
    int limit = 20,
  }) async {
    return QuestionHistoryPageResult(items: [_question]);
  }

  @override
  Future<CoupleQuestion> answer(String coupleQuestionId, String text) =>
      gate.hang();
}

class _MoodRepo implements IMoodRepository {
  _MoodRepo(this.gate);

  final Gate gate;

  @override
  Future<MoodCheckin> create({required MoodLevel mood, String? note}) =>
      gate.hang();

  @override
  Future<MoodCurrent> current() async => _lowMood;

  @override
  Future<MoodHistory> history({int days = 30}) async {
    return const MoodHistory(days: 30, items: []);
  }
}

class _NudgesRepo implements INudgesRepository {
  _NudgesRepo(this.gate);

  final Gate gate;

  @override
  Future<Nudge> send({required NudgeKind kind, String? message}) => gate.hang();

  @override
  Future<NudgePage> received({String? cursor}) async {
    return const NudgePage(items: []);
  }

  @override
  Future<Nudge> markSeen(String id) => gate.hang();
}

class _PairingRepo implements IPairingRepository {
  _PairingRepo(this.gate, {this.pending = false});

  final Gate gate;
  final bool pending;

  @override
  Future<PairingSnapshot> getStatus() async {
    return PairingSnapshot(
      phase: pending ? PairingPhase.pending : PairingPhase.unpaired,
      pairingCode: 'ABC123',
      pendingCode: pending ? 'XYZ123' : null,
    );
  }

  @override
  Future<void> ensurePairingCode() => gate.hang();

  @override
  Future<PairResult> pair(String code) => gate.hang();

  @override
  Future<void> cancelRequest() => gate.hang();

  @override
  Future<void> unpair() => gate.hang();

  @override
  Future<List<IncomingPairingRequest>> receivedRequests() async => const [];

  @override
  Future<PairResult> acceptRequest(String id) => gate.hang();

  @override
  Future<void> declineRequest(String id) => gate.hang();
}

class _NotesRepo implements INotificationsRepository {
  _NotesRepo(this.gate);

  final Gate gate;
  final prefs = const NotificationPreferences(
    pushEnabled: true,
    lists: true,
    importantDates: true,
    dailyQuestion: true,
    mood: true,
    nudges: true,
    datePlans: true,
  );

  @override
  Future<NotificationPreferences> getPreferences() async => prefs;

  @override
  Future<NotificationPreferences> updatePreferences(
    Map<String, dynamic> patch,
  ) => gate.hang();

  @override
  Future<void> registerDevice({
    required String token,
    required String platform,
    String? appVersion,
    String? locale,
  }) async {}

  @override
  Future<void> deleteDevice(String token) async {}
}
