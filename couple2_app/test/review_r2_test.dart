import 'dart:async';

import 'package:couple2_app/app/routing/app_back_button.dart';
import 'package:couple2_app/app/session.dart';
import 'package:couple2_app/app/session_provider.dart';
import 'package:couple2_app/design_system/design_system.dart';
import 'package:couple2_app/modules/couple/data/couple_providers.dart';
import 'package:couple2_app/modules/couple/data/couple_repository.dart';
import 'package:couple2_app/modules/couple/domain/domain.dart';
import 'package:couple2_app/modules/couple/ui/widgets/couple_date_sheet.dart';
import 'package:couple2_app/modules/couple/ui/widgets/profile_sheet.dart';
import 'package:couple2_app/modules/lists/data/lists_providers.dart';
import 'package:couple2_app/modules/lists/data/lists_repository.dart';
import 'package:couple2_app/modules/lists/domain/domain.dart';
import 'package:couple2_app/modules/lists/ui/pages/list_detail/list_detail_page.dart';
import 'package:couple2_app/modules/lists/ui/pages/lists/lists_page.dart';
import 'package:couple2_app/modules/mood/ui/widgets/mood_picker_sheet.dart';
import 'package:couple2_app/modules/mood/ui/widgets/nudge_composer_sheet.dart';
import 'package:couple2_app/modules/pairing/data/pairing_providers.dart';
import 'package:couple2_app/modules/pairing/data/pairing_repository.dart';
import 'package:couple2_app/modules/pairing/domain/domain.dart';
import 'package:couple2_app/modules/pairing/ui/pages/enter_code/enter_code_page.dart';
import 'package:couple2_app/modules/pairing/ui/pages/pairing_code/pairing_code_page.dart';
import 'package:couple2_app/modules/pairing/ui/pages/waiting/waiting_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

const _wine = Color(0xFF9D174D);
const _white = Color(0xFFFFFFFF);

class _Pops extends NavigatorObserver {
  int pops = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pops += 1;
  }
}

class _Session extends SessionNotifier {
  _Session(this.current);
  final Session? current;

  @override
  Future<Session?> build() async => current;

  @override
  Future<void> refresh() async {}
}

const _ada = Session(
  id: 'ada',
  email: 'ada@example.com',
  name: 'Ada',
  isPaired: true,
  coupleId: 'couple-1',
  partnerName: 'Bruno',
);

const _ana = Session(
  id: 'user-a',
  email: 'a@example.com',
  name: 'Ana',
  isPaired: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('double tap on Enviar pops the composer once', (tester) async {
    _pinSurface(tester);
    final pops = _Pops();
    await _push(
      tester,
      pops,
      Scaffold(
        body: Builder(
          builder: (context) => Column(
            children: [
              const Text('composer-page'),
              FilledButton(
                onPressed: () => showNudgeComposerSheet(context),
                child: const Text('abrir'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    _pressTwice(tester, find.widgetWithText(FilledButton, 'Enviar'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));

    expect(pops.pops, 1);
    expect(find.text('composer-page'), findsOneWidget);
    expect(find.text('Enviar'), findsNothing);
  });

  testWidgets('double tap on Excluir closes the dialog once', (tester) async {
    _pinSurface(tester);
    final pops = _Pops();
    await _push(
      tester,
      pops,
      Scaffold(
        body: Builder(
          builder: (context) => Column(
            children: [
              const Text('dialog-page'),
              FilledButton(
                onPressed: () => confirmDestructive(
                  context,
                  title: 'Excluir lista?',
                  message: 'Confere.',
                  confirmLabel: 'Excluir',
                ),
                child: const Text('abrir'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    _pressTwice(tester, find.widgetWithText(FilledButton, 'Excluir'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));

    expect(pops.pops, 1);
    expect(find.text('dialog-page'), findsOneWidget);
    expect(find.text('Excluir lista?'), findsNothing);
  });

  testWidgets('double tap on Adicionar pops the date sheet once', (
    tester,
  ) async {
    _pinSurface(tester);
    final pops = _Pops();
    await _push(
      tester,
      pops,
      Scaffold(
        body: Builder(
          builder: (context) => Column(
            children: [
              const Text('date-page'),
              FilledButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const CoupleDateSheet(),
                ),
                child: const Text('abrir'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    await tester.enterText(find.byType(TextField), 'Aniversário');
    await tester.pump();
    _pressTwice(tester, find.widgetWithText(FilledButton, 'Adicionar'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));

    expect(pops.pops, 1);
    expect(find.text('date-page'), findsOneWidget);
    expect(find.text('Nova data'), findsNothing);
  });

  testWidgets('double tap on Criar pops the new-list sheet once', (
    tester,
  ) async {
    _pinSurface(tester);
    final pops = _Pops();
    final repo = _Lists();
    await _push(
      tester,
      pops,
      const ListsPage(),
      overrides: [
        sessionProvider.overrideWith(() => _Session(_ada)),
        listsRepositoryProvider.overrideWithValue(repo),
      ],
    );
    expect(find.text('Nossas listas'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    await tester.enterText(find.byType(TextField), 'Mercado');
    await tester.pump();
    tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Criar'))
        .onPressed!();
    await tester.pump();
    final again = find.widgetWithText(FilledButton, 'Criar');
    if (again.evaluate().isNotEmpty) {
      tester.widget<FilledButton>(again).onPressed?.call();
      await tester.pump();
    }
    await tester.pumpAndSettle(const Duration(milliseconds: 50));

    expect(pops.pops, 1);
    expect(repo.creates, 1);
    expect(find.text('Nossas listas'), findsOneWidget);
    expect(find.text('Nova lista'), findsNothing);
  });

  testWidgets('double tap on Salvar pops the profile sheet once', (
    tester,
  ) async {
    _pinSurface(tester);
    final pops = _Pops();
    final repo = _Birth();
    await _push(
      tester,
      pops,
      Scaffold(
        body: Builder(
          builder: (context) => Column(
            children: [
              const Text('profile-page'),
              FilledButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const ProfileSheet(session: _ada),
                ),
                child: const Text('abrir'),
              ),
            ],
          ),
        ),
      ),
      overrides: [
        sessionProvider.overrideWith(() => _Session(_ada)),
        coupleRepositoryProvider.overrideWithValue(repo),
        coupleProvider.overrideWith((ref) async => null),
      ],
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    final salvar = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Salvar'),
    );
    salvar.onPressed!();
    salvar.onPressed!();
    await tester.pump();
    final again = find.widgetWithText(FilledButton, 'Salvar');
    if (again.evaluate().isNotEmpty) {
      tester.widget<FilledButton>(again).onPressed?.call();
      await tester.pump();
    }
    await tester.pumpAndSettle(const Duration(milliseconds: 50));

    expect(pops.pops, 1);
    expect(repo.saves, 1);
    expect(find.text('profile-page'), findsOneWidget);
    expect(find.text('Salvar'), findsNothing);
  });

  testWidgets('back pops the top page once', (tester) async {
    _pinSurface(tester);
    final pops = _Pops();
    final router = GoRouter(
      observers: [pops],
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('root-marker')),
        ),
        GoRoute(
          path: '/middle',
          builder: (_, __) => const Scaffold(body: Text('middle-page')),
        ),
        GoRoute(
          path: '/inner',
          builder: (_, __) => Scaffold(
            appBar: AppBar(leading: const AppBackButton()),
            body: const Text('inner-page'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    router.push('/middle');
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    router.push('/inner');
    await tester.pumpAndSettle(const Duration(milliseconds: 50));

    final back = tester.widget<IconButton>(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(IconButton),
      ),
    );
    back.onPressed!();
    back.onPressed!();
    await tester.pumpAndSettle(const Duration(milliseconds: 50));

    expect(pops.pops, 1);
    expect(find.text('middle-page'), findsOneWidget);
    expect(find.text('inner-page'), findsNothing);
  });

  testWidgets('Enviar pedido is white on wine and shows a spinner', (
    tester,
  ) async {
    _pinSurface(tester);
    final gate = Completer<PairResult>();
    addTearDown(() {
      if (!gate.isCompleted) {
        gate.complete(
          const PairResult(phase: PairingPhase.pending, message: 'ok'),
        );
      }
    });
    final repo = _Pairing(
      const PairingSnapshot(
        phase: PairingPhase.unpaired,
        pairingCode: 'ABC123',
      ),
      hungPair: gate.future,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(() => _Session(_ana)),
          pairingRepositoryProvider.overrideWithValue(repo),
          pairingPollIntervalProvider.overrideWithValue(null),
        ],
        child: MaterialApp(theme: lightTheme, home: const EnterCodePage()),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    await tester.enterText(
      find.byKey(const Key('partner-code-field')),
      'XYZ789',
    );
    await tester.pump();

    expect(_labelColor(tester, 'Enviar pedido'), _white);
    expect(_fill(tester, find.byKey(const Key('submit-partner-code'))), _wine);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(
      find.widgetWithText(TextButton, 'Voltar ao meu código'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('submit-partner-code')));
    await tester.pump();

    expect(find.byKey(LoadingButton.spinnerKey), findsOneWidget);
    expect(find.text('Enviando…'), findsOneWidget);
    expect(_labelColor(tester, 'Enviando…'), _white);
    expect(_fill(tester, find.byKey(const Key('submit-partner-code'))), _wine);
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.descendant(
              of: find.byKey(LoadingButton.spinnerKey),
              matching: find.byType(CircularProgressIndicator),
            ),
          )
          .color,
      _white,
    );
    expect(repo.pairs, 1);

    await tester.tap(find.byKey(const Key('submit-partner-code')));
    await tester.pump();
    expect(repo.pairs, 1);
  });

  testWidgets('pairing hub keeps a single filled button', (tester) async {
    _pinSurface(tester);
    Future<void> pump(PairingSnapshot status, Session session) async {
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey(status.pairingCode),
          overrides: [
            sessionProvider.overrideWith(() => _Session(session)),
            pairingRepositoryProvider.overrideWithValue(_Pairing(status)),
            pairingPollIntervalProvider.overrideWithValue(null),
          ],
          child: MaterialApp(theme: lightTheme, home: const PairingCodePage()),
        ),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
    }

    await pump(const PairingSnapshot(phase: PairingPhase.unpaired), _ana);
    expect(find.text('Gerar código'), findsOneWidget);
    expect(_outlinedLabel('Digitar o código do meu par'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);

    await pump(
      const PairingSnapshot(
        phase: PairingPhase.unpaired,
        pairingCode: 'ABC123',
      ),
      const Session(
        id: 'user-a',
        email: 'a@example.com',
        name: 'Ana',
        isPaired: false,
        pairingCode: 'ABC123',
      ),
    );
    expect(find.text('Gerar código'), findsNothing);
    expect(_outlinedLabel('Digitar o código do meu par'), findsOneWidget);
    expect(_outlinedLabel('Copiar'), findsOneWidget);
    expect(_outlinedLabel('Compartilhar'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('waiting page does not add a second primary', (tester) async {
    _pinSurface(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(() => _Session(_ana)),
          pairingRepositoryProvider.overrideWithValue(
            _Pairing(
              const PairingSnapshot(
                phase: PairingPhase.pending,
                pendingCode: 'XYZ789',
                pairingCode: 'ABC123',
              ),
            ),
          ),
          pairingPollIntervalProvider.overrideWithValue(null),
        ],
        child: MaterialApp(theme: lightTheme, home: const WaitingPage()),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 50));

    expect(_outlinedLabel('Copiar'), findsOneWidget);
    expect(_outlinedLabel('Compartilhar'), findsOneWidget);
    expect(_outlinedLabel('Cancelar pedido'), findsOneWidget);
    expect(
      find.widgetWithText(TextButton, 'Voltar ao meu código'),
      findsOneWidget,
    );
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('delete icon is outside the row tap and private copy differs', (
    tester,
  ) async {
    _pinSurface(tester);
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const ListsPage()),
        GoRoute(
          path: '/lists/:id',
          builder: (_, __) => const Scaffold(body: Text('Lista aberta')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(() => _Session(_ada)),
          listsRepositoryProvider.overrideWithValue(
            _Lists([_list('Presentes', visibility: 'PRIVATE_FROM_PARTNER')]),
          ),
        ],
        child: MaterialApp.router(theme: lightTheme, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 50));

    expect(
      find.ancestor(
        of: find.byTooltip('Excluir lista'),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.textContaining('🔒'), findsNothing);
    await tester.tap(find.byTooltip('Excluir lista'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Excluir lista?'), findsOneWidget);
    expect(find.textContaining('é só sua'), findsOneWidget);
    expect(find.textContaining('não vê esta lista'), findsOneWidget);
    expect(find.textContaining('os dois'), findsNothing);
    expect(find.text('Lista aberta'), findsNothing);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.text('Lista aberta'), findsOneWidget);
  });

  testWidgets('a shared list still says it disappears for both', (
    tester,
  ) async {
    _pinSurface(tester);
    await _listsHome(tester, [_list('Mercado')]);
    await tester.tap(find.byTooltip('Excluir lista'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('somem para os dois'), findsOneWidget);
  });

  testWidgets('a private list item is not described as shared', (tester) async {
    _pinSurface(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          listsRepositoryProvider.overrideWithValue(
            _Lists([
              _list(
                'Presentes',
                visibility: 'PRIVATE_FROM_PARTNER',
                items: [_item('Flores')],
              ),
            ]),
          ),
        ],
        child: MaterialApp(
          theme: lightTheme,
          home: const ListDetailPage(listId: 'list-1'),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    await tester.tap(find.byTooltip('Excluir item'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('é só seu'), findsOneWidget);
    expect(find.textContaining('os dois'), findsNothing);
  });

  testWidgets('the mood note keeps the first characters after focus', (
    tester,
  ) async {
    _pinSurface(tester);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: MoodPickerSheet())),
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'O');
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Oi');
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Oi',
    );
  });
}

Future<void> _push(
  WidgetTester tester,
  _Pops pops,
  Widget page, {
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: lightTheme,
        navigatorObservers: [pops],
        home: const Scaffold(body: Text('root-marker')),
      ),
    ),
  );
  tester
      .state<NavigatorState>(find.byType(Navigator))
      .push(MaterialPageRoute<void>(builder: (_) => page));
  await tester.pumpAndSettle(const Duration(milliseconds: 50));
}

/// [OutlinedButton.icon] is not runtimeType [OutlinedButton].
Finder _outlinedLabel(String label) {
  return find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((widget) {
      return widget is ButtonStyleButton &&
          widget.runtimeType.toString().contains('OutlinedButton');
    }),
  );
}

void _pressTwice(WidgetTester tester, Finder finder) {
  final button = tester.widget<FilledButton>(finder);
  button.onPressed!();
  button.onPressed!();
}

Color? _labelColor(WidgetTester tester, String text) {
  return DefaultTextStyle.of(tester.element(find.text(text))).style.color;
}

Color? _fill(WidgetTester tester, Finder scope) {
  return tester
      .widget<Material>(
        find.descendant(of: scope, matching: find.byType(Material)).first,
      )
      .color;
}

Future<void> _listsHome(WidgetTester tester, List<PartnerList> lists) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWith(() => _Session(_ada)),
        listsRepositoryProvider.overrideWithValue(_Lists(lists)),
      ],
      child: MaterialApp(theme: lightTheme, home: const ListsPage()),
    ),
  );
  await tester.pumpAndSettle(const Duration(milliseconds: 50));
}

PartnerList _list(
  String name, {
  String visibility = 'SHARED',
  List<ListItem> items = const [],
}) {
  return PartnerList(
    id: 'list-1',
    type: 'GIFT_IDEAS',
    name: name,
    ownerId: 'ada',
    visibility: visibility,
    items: items,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

ListItem _item(String content) {
  return ListItem(
    id: 'item-1',
    listId: 'list-1',
    content: content,
    isCompleted: false,
    addedById: 'ada',
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

class _Lists implements IListsRepository {
  _Lists([this.lists = const []]);

  List<PartnerList> lists;
  var creates = 0;

  @override
  Future<List<PartnerList>> getLists() async => lists;

  @override
  Future<PartnerList> createList(
    String type,
    String name, {
    String? visibility,
  }) async {
    creates += 1;
    return PartnerList(
      id: 'created',
      type: type,
      name: name,
      ownerId: 'ada',
      visibility: visibility ?? 'SHARED',
      items: const [],
      createdAt: DateTime.utc(2026, 1, 2),
    );
  }

  @override
  Future<ListItem> addItem(
    String listId,
    String content,
    Map<String, dynamic>? metadata,
  ) => Future<ListItem>.error(StateError('unused'));

  @override
  Future<ListItem> toggleItem(String itemId) =>
      Future<ListItem>.error(StateError('unused'));

  @override
  Future<void> deleteItem(String itemId) async {}

  @override
  Future<void> deleteList(String listId) async {}
}

class _Birth implements ICoupleRepository {
  var saves = 0;

  @override
  Future<void> updateMyBirthDate(String? birthDate) async {
    saves += 1;
  }

  @override
  Future<Couple> getCouple() => Future<Couple>.error(StateError('unused'));

  @override
  Future<Couple> updateCouple({String? anniversaryDate, String? timezone}) =>
      Future<Couple>.error(StateError('unused'));

  @override
  Future<List<CoupleDate>> getDates() async => const [];

  @override
  Future<CoupleDate> createDate({
    required String title,
    required String date,
    String? recurrence,
  }) => Future<CoupleDate>.error(StateError('unused'));

  @override
  Future<CoupleDate> updateDate(
    String id, {
    String? title,
    String? date,
    String? recurrence,
  }) => Future<CoupleDate>.error(StateError('unused'));

  @override
  Future<void> deleteDate(String id) async {}
}

class _Pairing implements IPairingRepository {
  _Pairing(this.status, {this.hungPair});

  final PairingSnapshot status;
  final Future<PairResult>? hungPair;
  var pairs = 0;

  @override
  Future<PairingSnapshot> getStatus() async => status;

  @override
  Future<PairResult> pair(String code) {
    pairs += 1;
    return hungPair ??
        Future<PairResult>.value(
          const PairResult(phase: PairingPhase.pending, message: 'ok'),
        );
  }

  @override
  Future<void> cancelRequest() async {}

  @override
  Future<void> unpair() async {}

  @override
  Future<void> ensurePairingCode() async {}

  @override
  Future<List<IncomingPairingRequest>> receivedRequests() async => const [];

  @override
  Future<PairResult> acceptRequest(String id) async {
    throw UnimplementedError();
  }

  @override
  Future<void> declineRequest(String id) async {}

}

void _pinSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
