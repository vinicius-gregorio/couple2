import 'dart:async';

import 'package:couple2_app/app/providers.dart';
import 'package:couple2_app/app/session.dart';
import 'package:couple2_app/app/session_provider.dart';
import 'package:couple2_app/design_system/design_system.dart';
import 'package:couple2_app/modules/couple/data/couple_providers.dart';
import 'package:couple2_app/modules/couple/data/couple_repository.dart';
import 'package:couple2_app/modules/couple/domain/domain.dart';
import 'package:couple2_app/modules/couple/ui/widgets/couple_date_sheet.dart';
import 'package:couple2_app/modules/couple/ui/widgets/profile_sheet.dart';
import 'package:couple2_app/modules/date_plans/ui/pages/date_plan_form/date_plan_form_page.dart';
import 'package:couple2_app/modules/lists/data/lists_providers.dart';
import 'package:couple2_app/modules/lists/data/lists_repository.dart';
import 'package:couple2_app/modules/lists/domain/domain.dart';
import 'package:couple2_app/modules/lists/ui/pages/lists/lists_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _ada = Session(
  id: 'ada',
  email: 'ada@example.com',
  name: 'Ada',
  isPaired: true,
  coupleId: 'couple-1',
  partnerName: 'Bruno',
);

class _Session extends SessionNotifier {
  _Session(this.current);

  final Session current;

  @override
  Future<Session?> build() async => current;

  @override
  Future<void> refresh() async {}
}

class _HangCouple implements ICoupleRepository {
  final _birth = Completer<void>();

  @override
  Future<void> updateMyBirthDate(String? birthDate) => _birth.future;

  @override
  Future<Couple> getCouple() => Completer<Couple>().future;

  @override
  Future<Couple> updateCouple({String? anniversaryDate, String? timezone}) =>
      Completer<Couple>().future;

  @override
  Future<List<CoupleDate>> getDates() async => const [];

  @override
  Future<CoupleDate> createDate({
    required String title,
    required String date,
    String? recurrence,
  }) => Completer<CoupleDate>().future;

  @override
  Future<CoupleDate> updateDate(
    String id, {
    String? title,
    String? date,
    String? recurrence,
  }) => Completer<CoupleDate>().future;

  @override
  Future<void> deleteDate(String id) async {}
}

class _HangLists implements IListsRepository {
  final _create = Completer<PartnerList>();

  @override
  Future<List<PartnerList>> getLists() async => const [];

  @override
  Future<PartnerList> createList(
    String type,
    String name, {
    String? visibility,
  }) => _create.future;

  @override
  Future<ListItem> addItem(
    String listId,
    String content,
    Map<String, dynamic>? metadata,
  ) => Completer<ListItem>().future;

  @override
  Future<ListItem> toggleItem(String itemId) => Completer<ListItem>().future;

  @override
  Future<void> deleteItem(String itemId) async {}

  @override
  Future<void> deleteList(String listId) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('profile, date sheet, and date form open enabled picker arrows', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      await tester.binding.setSurfaceSize(const Size(900, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _openProfilePicker(tester);
      for (final label in const [
        'Mês anterior',
        'Próximo mês',
        'Ano anterior',
        'Próximo ano',
      ]) {
        _expectArrow(tester, label, navigable: true);
      }
      await _closeDialog(tester);
      await tester.pumpWidget(const SizedBox.shrink());

      await _openCoupleDatePicker(tester);
      for (final label in const [
        'Mês anterior',
        'Próximo mês',
        'Ano anterior',
        'Próximo ano',
      ]) {
        _expectArrow(tester, label, navigable: true);
      }
      await _closeDialog(tester);
      await tester.pumpWidget(const SizedBox.shrink());

      await _openPlanFormPicker(tester);
      _expectArrow(tester, 'Mês anterior', navigable: false);
      _expectArrow(tester, 'Ano anterior', navigable: false);
      _expectArrow(tester, 'Próximo mês', navigable: true);
      _expectArrow(tester, 'Próximo ano', navigable: true);
      await _closeDialog(tester);
      await tester.pumpWidget(const SizedBox.shrink());

      await _openTimePicker(tester);
      expect(find.bySemanticsLabel('Mês anterior'), findsNothing);
      expect(find.bySemanticsLabel('Próximo mês'), findsNothing);
      expect(find.bySemanticsLabel('Ano anterior'), findsNothing);
      expect(find.bySemanticsLabel('Próximo ano'), findsNothing);
      _expectNamedControl(
        tester,
        'Mudar para o modo de entrada de texto',
        navigable: true,
      );
    } finally {
      handle.dispose();
    }
  });

  testWidgets('slow save disables every actionable node in the sheets', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      await tester.binding.setSurfaceSize(const Size(900, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _openProfile(tester);
      // Left of the 640-wide sheet on a 900-wide surface: the route barrier.
      await tester.tapAt(const Offset(24, 24));
      await tester.pumpAndSettle();
      expect(find.text('Salvar'), findsNothing);
      await _openProfile(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
      await tester.pump();
      expect(_enabledActions(tester), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());

      await _openListSheet(tester);
      await tester.enterText(find.byType(TextField), 'Mercado');
      await tester.pump();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ideias de presente').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Criar'));
      await tester.pump();
      expect(_enabledActions(tester), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());

      await _openDateSheet(tester);
      await tester.enterText(find.byType(TextField), 'Aniversário');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Adicionar'));
      await tester.pump();
      expect(_enabledActions(tester), isEmpty);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('load error message and retry sit together in the card', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const message = 'Não foi possível carregar o humor.';
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme,
        home: Scaffold(
          body: LoadErrorCard(message: message, onRetry: () {}),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    final box = tester.getRect(find.byType(LoadErrorCard));
    final text = tester.getRect(find.text(message));
    final retry = tester.getRect(find.text(LoadErrorCard.retryLabel));
    expect(retry.top - text.bottom, inInclusiveRange(0, 16));
    expect((text.center.dx - box.center.dx).abs(), lessThanOrEqualTo(8));
    expect((retry.center.dx - box.center.dx).abs(), lessThanOrEqualTo(8));
    expect(box.height, lessThan(160));
  });
}

List<SemanticsNode> _semanticsRoots(WidgetTester tester) {
  final roots = <SemanticsNode>[];
  void collect(PipelineOwner owner) {
    final root = owner.semanticsOwner?.rootSemanticsNode;
    if (root != null) roots.add(root);
    owner.visitChildren(collect);
  }

  collect(tester.binding.rootPipelineOwner);
  return roots;
}

void _expectNamedControl(
  WidgetTester tester,
  String name, {
  required bool navigable,
}) {
  final roots = _semanticsRoots(tester);
  expect(roots, isNotEmpty, reason: name);
  SemanticsData? found;
  final seen = <String>[];
  bool walk(SemanticsNode node) {
    if (found != null) return false;
    if (!node.isMergedIntoParent) {
      final data = node.getSemanticsData();
      if (!data.flagsCollection.isHidden &&
          (data.label == name || data.tooltip == name)) {
        found = data;
        return false;
      }
      if (data.label.isNotEmpty || data.tooltip.isNotEmpty) {
        seen.add('${data.label}/${data.tooltip}');
      }
    }
    node.visitChildren(walk);
    return found == null;
  }

  for (final root in roots) {
    walk(root);
  }
  expect(found, isNotNull, reason: '$name missing among ${seen.join(' | ')}');
  final data = found!;
  expect(data.flagsCollection.isButton, isTrue, reason: name);
  expect(data.flagsCollection.hasEnabledState, isTrue, reason: name);
  expect(data.flagsCollection.isEnabled, navigable, reason: name);
  expect(data.flagsCollection.isFocusable, navigable, reason: name);
  expect(data.hasAction(SemanticsAction.tap), navigable, reason: name);
}

void _expectArrow(
  WidgetTester tester,
  String label, {
  required bool navigable,
}) {
  final data = tester.getSemantics(find.bySemanticsLabel(label)).getSemanticsData();
  expect(data.label, label, reason: label);
  expect(data.flagsCollection.isButton, isTrue, reason: label);
  expect(data.flagsCollection.hasEnabledState, isTrue, reason: label);
  expect(data.flagsCollection.isEnabled, navigable, reason: label);
  expect(data.flagsCollection.isFocusable, navigable, reason: label);
  expect(data.hasAction(SemanticsAction.tap), navigable, reason: label);
}

List<String> _enabledActions(WidgetTester tester) {
  final roots = _semanticsRoots(tester);
  expect(roots, isNotEmpty);
  final bad = <String>[];
  bool walk(SemanticsNode node) {
    if (!node.isMergedIntoParent) {
      final data = node.getSemanticsData();
      final flags = data.flagsCollection;
      if (!flags.isHidden) {
        final text = flags.isTextField || data.hasAction(SemanticsAction.setText);
        final tap = data.hasAction(SemanticsAction.tap);
        final focus = data.hasAction(SemanticsAction.focus);
        if (tap || focus || text) {
          final disabled = flags.hasEnabledState && !flags.isEnabled;
          if (!disabled) {
            bad.add(
              'label="${data.label}" tip="${data.tooltip}" '
              'button=${flags.isButton} text=${flags.isTextField} '
              'focusable=${flags.isFocusable} en=${flags.isEnabled} '
              'hasEn=${flags.hasEnabledState} tap=$tap focus=$focus '
              'rect=${data.rect}',
            );
          }
        }
        node.visitChildren(walk);
      }
    } else {
      node.visitChildren(walk);
    }
    return true;
  }

  for (final root in roots) {
    walk(root);
  }
  return bad;
}

Future<void> _openProfile(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWith(() => _Session(_ada)),
        coupleRepositoryProvider.overrideWithValue(_HangCouple()),
      ],
      child: MaterialApp(
        theme: lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () {
                showAppSheet<void>(
                  context: context,
                  builder: (_) =>
                      ProfileSheet(session: _ada, hostContext: context),
                );
              },
              child: const Text('perfil'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('perfil'));
  await tester.pumpAndSettle();
}

Future<void> _openProfilePicker(WidgetTester tester) async {
  await _openProfile(tester);
  await tester.tap(find.text('Escolher data'));
  await tester.pumpAndSettle();
}

Future<void> _openCoupleDatePicker(WidgetTester tester) async {
  await _openDateSheet(tester);
  await tester.tap(find.byType(OutlinedButton));
  await tester.pumpAndSettle();
}

Future<void> _openDateSheet(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            onPressed: () {
              showAppSheet<void>(
                context: context,
                builder: (_) => CoupleDateSheet(
                  hostContext: context,
                  onSave: (_) => Completer<String?>().future,
                ),
              );
            },
            child: const Text('data'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('data'));
  await tester.pumpAndSettle();
}

Future<void> _openPlanFormPicker(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: lightTheme,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const DatePlanFormPage(),
      ),
    ),
  );
  await tester.pump();
  await tester.tap(find.text('Data e hora'));
  await tester.pumpAndSettle();
}

Future<void> _openTimePicker(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: lightTheme,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            onPressed: () {
              showTimePicker(
                context: context,
                initialTime: const TimeOfDay(hour: 20, minute: 0),
              );
            },
            child: const Text('hora'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('hora'));
  await tester.pumpAndSettle();
}

Future<void> _openListSheet(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWith(() => _Session(_ada)),
        listsRepositoryProvider.overrideWithValue(_HangLists()),
      ],
      child: MaterialApp(theme: lightTheme, home: const ListsPage()),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
}

Future<void> _closeDialog(WidgetTester tester) async {
  await tester.tap(find.text('Cancelar'));
  await tester.pumpAndSettle();
}
