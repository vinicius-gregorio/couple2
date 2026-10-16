import 'dart:async';
import 'dart:convert';

import 'package:couple2_app/app/session.dart';
import 'package:couple2_app/app/session_cache.dart';
import 'package:couple2_app/app/session_provider.dart';
import 'package:couple2_app/app/ui/pages/home/home_page.dart';
import 'package:couple2_app/core/core.dart';
import 'package:couple2_app/design_system/design_system.dart';
import 'package:couple2_app/modules/couple/data/couple_providers.dart';
import 'package:couple2_app/modules/couple/data/couple_repository.dart';
import 'package:couple2_app/modules/couple/domain/domain.dart';
import 'package:couple2_app/modules/couple/ui/pages/couple_settings/couple_settings_page.dart';
import 'package:couple2_app/modules/couple/ui/widgets/couple_date_sheet.dart';
import 'package:couple2_app/modules/couple/ui/widgets/profile_sheet.dart';
import 'package:couple2_app/modules/daily_question/data/daily_question_providers.dart';
import 'package:couple2_app/modules/daily_question/domain/domain.dart';
import 'package:couple2_app/modules/date_plans/data/date_plans_providers.dart';
import 'package:couple2_app/modules/date_plans/domain/domain.dart';
import 'package:couple2_app/modules/date_plans/routing/routes.dart';
import 'package:couple2_app/modules/feed/domain/domain.dart';
import 'package:couple2_app/modules/feed/data/feed_providers.dart';
import 'package:couple2_app/modules/lists/data/lists_providers.dart';
import 'package:couple2_app/modules/lists/data/lists_repository.dart';
import 'package:couple2_app/modules/lists/domain/domain.dart';
import 'package:couple2_app/modules/lists/routing/routes.dart';
import 'package:couple2_app/modules/lists/ui/pages/lists/lists_page.dart';
import 'package:couple2_app/modules/lists/ui/pages/lists/lists_viewmodel.dart';
import 'package:couple2_app/modules/mood/data/mood_providers.dart';
import 'package:couple2_app/modules/mood/data/mood_repository.dart';
import 'package:couple2_app/modules/mood/data/nudges_repository.dart';
import 'package:couple2_app/modules/mood/domain/domain.dart';
import 'package:couple2_app/modules/mood/ui/widgets/mood_home_card.dart';
import 'package:couple2_app/modules/mood/ui/widgets/mood_picker_sheet.dart';
import 'package:couple2_app/modules/pairing/data/pairing_providers.dart';
import 'package:couple2_app/modules/pairing/data/pairing_repository.dart';
import 'package:couple2_app/modules/pairing/domain/domain.dart';
import 'package:couple2_app/modules/pairing/routing/routes.dart';
import 'package:couple2_app/modules/pairing/ui/pages/enter_code/enter_code_page.dart';
import 'package:couple2_app/modules/pairing/ui/widgets/generate_pairing_code_button.dart';
import 'package:couple2_app/modules/pairing/ui/widgets/unpair_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('session cache round-trips and the boot splash is not a card skeleton', () async {
    SharedPreferences.setMockInitialValues({});
    const session = Session(
      id: 'ada',
      email: 'a@example.com',
      name: 'Ada',
      isPaired: true,
      coupleId: 'couple-1',
    );
    await SessionCache.write(session);
    final read = await SessionCache.read();
    expect(read?.name, 'Ada');
    expect(read?.coupleId, 'couple-1');
    expect(jsonDecode(jsonEncode(session.toCacheJson()))['name'], 'Ada');

    await SessionCache.write(null);
    expect(await SessionCache.read(), isNull);
  });

  testWidgets('session splash does not paint home card skeletons', (tester) async {
    _pinSurface(tester);
    await tester.pumpWidget(
      const MaterialApp(home: SessionSplash()),
    );
    expect(find.text('Abrindo a sessão…'), findsOneWidget);
    expect(find.byType(CardSkeleton), findsNothing);
    expect(find.byType(ListSkeleton), findsNothing);
  });

  testWidgets('home keeps one filled button and planejar opens a date', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomePage()),
        GoRoute(
          path: DatePlanRoutes.create,
          builder: (_, _) => const Scaffold(body: Text('formulario-date')),
        ),
        GoRoute(
          path: ListsRoutes.lists,
          builder: (_, _) => const Scaffold(body: Text('pagina-listas')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(_Session.new),
          coupleProvider.overrideWith((ref) async => _couple),
          currentMoodProvider.overrideWith((ref) async => _mood),
          nextDateProvider.overrideWith((ref) async => null),
          todayQuestionProvider.overrideWith((ref) async => null),
          feedPreviewProvider.overrideWith((ref) async => const []),
          unreadCountProvider.overrideWith((ref) async => 0),
        ],
        child: MaterialApp.router(theme: lightTheme, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 50));

    expect(find.byTooltip('Notificações'), findsOneWidget);
    expect(find.byTooltip('O que rolou'), findsNothing);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.text('💗 Pensando em você'), findsOneWidget);
    expect(_outlinedLabel('Nossas listas'), findsOneWidget);
    expect(_outlinedLabel('Planejar um date'), findsOneWidget);

    await tester.ensureVisible(find.text('Planejar um date'));
    await tester.tap(find.text('Planejar um date'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.text('formulario-date'), findsOneWidget);
    expect(find.text('pagina-listas'), findsNothing);
  });

  testWidgets('offline home keeps one banner and the carinho button', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const offline = CPLHttpNoInternetConnectionException();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(_Session.new),
          coupleProvider.overrideWith((ref) => Future<Couple?>.error(offline)),
          currentMoodProvider.overrideWith(
            (ref) => Future<MoodCurrent?>.error(offline),
          ),
          nextDateProvider.overrideWith(
            (ref) => Future<DatePlan?>.error(offline),
          ),
          todayQuestionProvider.overrideWith(
            (ref) => Future<CoupleQuestion?>.error(offline),
          ),
          feedPreviewProvider.overrideWith(
            (ref) => Future<List<ActivityEvent>>.error(offline),
          ),
          unreadCountProvider.overrideWith((ref) async => 0),
        ],
        child: MaterialApp(theme: lightTheme, home: const HomePage()),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 50));

    expect(find.text(offlineUserMessage), findsOneWidget);
    expect(find.text('Atualizar'), findsOneWidget);
    expect(find.text('💗 Pensando em você'), findsOneWidget);
  });

  test('a slow list item stays visible when a refresh lands first', () async {
    final repo = _ListsRepo();
    final container = ProviderContainer(
      overrides: [listsRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    container.listen(listsViewModelProvider, (_, _) {});
    await _loaded(container);

    final added = container
        .read(listsViewModelProvider.notifier)
        .addItem('list-1', 'AuditSlow', null);
    await Future<void>.delayed(Duration.zero);
    expect(_contents(container), contains('AuditSlow'));

    await container.read(listsViewModelProvider.notifier).refresh();
    expect(_contents(container), contains('AuditSlow'));

    repo.releaseAdd();
    expect(await added, isTrue);
    expect(_contents(container), contains('AuditSlow'));
    expect(
      container.read(listsViewModelProvider).actionError,
      isNull,
    );
  });

  test('creating a list does not also store a page error', () async {
    final repo = _ListsRepo()..failCreate = true;
    final container = ProviderContainer(
      overrides: [listsRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    container.listen(listsViewModelProvider, (_, _) {});
    await _loaded(container);
    final message = await container
        .read(listsViewModelProvider.notifier)
        .createList('TODO', 'Compras');
    expect(message, isNotNull);
    expect(container.read(listsViewModelProvider).actionError, isNull);
  });

  testWidgets('delete list does not spin behind the confirm dialog', (
    tester,
  ) async {
    _pinSurface(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          listsRepositoryProvider.overrideWithValue(_ListsRepo()),
        ],
        child: const MaterialApp(home: ListsPage()),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.byTooltip('Nova lista'), findsOneWidget);

    await tester.tap(find.byTooltip('Excluir lista'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Excluir lista?'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a failed date stays in the sheet with the typed title', (
    tester,
  ) async {
    _pinSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CoupleDateSheet(
            onSave: (_) async => 'Sem conexão. Verifique a internet e tente de novo.',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'AuditDate');
    await tester.pump();
    await tester.tap(find.text('Adicionar'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.text('Nova data'), findsOneWidget);
    expect(find.text('AuditDate'), findsOneWidget);
    expect(find.textContaining('Sem conexão'), findsOneWidget);
  });

  testWidgets('couple settings blames the network, not the timezone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final hang = Completer<Couple>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          coupleProvider.overrideWith((ref) async => _couple),
          coupleRepositoryProvider.overrideWithValue(
            _CoupleRepo(hangUpdate: hang),
          ),
          pairingRepositoryProvider.overrideWithValue(
            _Pairing(const PairingSnapshot(phase: PairingPhase.paired)),
          ),
          pairingPollIntervalProvider.overrideWithValue(null),
          sessionProvider.overrideWith(_Session.new),
        ],
        child: const MaterialApp(home: CoupleSettingsPage()),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    await tester.tap(find.text('Salvar'));
    await tester.pump();
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
    expect(
      tester
          .widget<LoadingButton>(find.byKey(const Key('unpair-button')))
          .onPressed,
      isNull,
    );
    hang.completeError(const CPLHttpNoInternetConnectionException());
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.textContaining('Confira o fuso'), findsNothing);
    expect(find.text(offlineUserMessage), findsOneWidget);
  });

  testWidgets('unpair locks Salvar while it is running', (tester) async {
    _pinSurface(tester);
    final gate = Completer<void>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          coupleProvider.overrideWith((ref) async => _couple),
          pairingRepositoryProvider.overrideWithValue(
            _Pairing(
              const PairingSnapshot(phase: PairingPhase.paired),
              hungUnpair: gate.future,
            ),
          ),
          pairingPollIntervalProvider.overrideWithValue(null),
          sessionProvider.overrideWith(_Session.new),
        ],
          child: MaterialApp(
            theme: lightTheme,
            home: const Scaffold(body: _SaveProbe()),
          ),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    await tester.tap(find.text('Desfazer o par'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final confirm = tester.widget<FilledButton>(
      find.byKey(const Key('confirm-unpair')),
    );
    expect(
      confirm.style?.backgroundColor?.resolve({}),
      lightColorScheme.error,
    );
    await tester.tap(find.byKey(const Key('confirm-unpair')));
    await tester.pump();
    expect(find.text('Desfazendo…'), findsOneWidget);
    expect(find.text('Salvar'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Salvar')).onPressed,
      isNull,
    );
    gate.complete();
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
  });

  testWidgets('enter code keeps Atualizar and locks Sair while sending', (
    tester,
  ) async {
    _pinSurface(tester);
    final gate = Completer<PairResult>();
    final repo = _Pairing(
      const PairingSnapshot(phase: PairingPhase.unpaired, pairingCode: 'ABC123'),
      hungPair: gate.future,
    );
    final router = GoRouter(
      initialLocation: PairingRoutes.enter,
      routes: [
        GoRoute(
          path: PairingRoutes.enter,
          builder: (_, _) => const EnterCodePage(),
        ),
        GoRoute(
          path: PairingRoutes.waiting,
          builder: (_, _) => const Scaffold(body: Text('espera')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(_Session.new),
          pairingRepositoryProvider.overrideWithValue(repo),
          pairingPollIntervalProvider.overrideWithValue(null),
        ],
        child: MaterialApp.router(theme: lightTheme, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.byTooltip('Atualizar'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('partner-code-field')), 'XYZ789');
    await tester.pump();
    await tester.tap(find.byKey(const Key('submit-partner-code')));
    await tester.pump();
    expect(find.text('Enviando…'), findsOneWidget);
    expect(find.byTooltip('Atualizar'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byTooltip('Sair'),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Voltar ao meu código'),
          )
          .onPressed,
      isNull,
    );
    expect(repo.pairs, 1);
    expect(repo.statusReads, 1);
    gate.complete(
      const PairResult(phase: PairingPhase.pending, message: 'ok'),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(repo.pairs, 1);
    expect(repo.statusReads, 1);
  });

  testWidgets('pairing generate error is red', (tester) async {
    _pinSurface(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pairingRepositoryProvider.overrideWithValue(
            _Pairing(const PairingSnapshot(phase: PairingPhase.unpaired)),
          ),
          sessionProvider.overrideWith(_Session.new),
          pairingPollIntervalProvider.overrideWithValue(null),
        ],
        child: MaterialApp(
          theme: lightTheme,
          home: const Scaffold(body: GeneratePairingCodeButton()),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    await tester.tap(find.text('Gerar código'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    final text = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('generate-pairing-code-error')),
        matching: find.byType(Text),
      ),
    );
    expect(text.style?.color, lightColorScheme.error);
  });

  testWidgets('mood sheet stays up for the second tap of Compartilhar', (
    tester,
  ) async {
    _pinSurface(tester);
    var behind = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          moodRepositoryProvider.overrideWithValue(_MoodRepo()),
          currentMoodProvider.overrideWith((ref) async => null),
          feedPreviewProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  TextButton(
                    onPressed: () => behind++,
                    child: const Text('atras'),
                  ),
                  TextButton(
                    onPressed: () => showMoodPickerSheet(context),
                    child: const Text('abrir'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.text('Como você está?'), findsOneWidget);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Compartilhar')),
    );
    await tester.pump();
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Como você está?'), findsOneWidget);
    expect(find.text('Guardando…'), findsOneWidget);
    await tester.tap(find.text('atras'), warnIfMissed: false);
    expect(behind, 0);
    expect(find.text('Como você está?'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(behind, 0);
  });

  testWidgets('birthday day tap does not close the profile sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const session = Session(
      id: 'ada',
      email: 'a@example.com',
      name: 'Ada',
      isPaired: true,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          coupleRepositoryProvider.overrideWithValue(_CoupleRepo()),
          sessionProvider.overrideWith(_Session.new),
        ],
        child: MaterialApp(
          locale: const Locale('pt', 'BR'),
          supportedLocales: const [Locale('pt', 'BR')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => ProfileSheet(
                    session: session,
                    hostContext: context,
                  ),
                ),
                child: const Text('perfil'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('perfil'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    await tester.tap(find.text('Escolher data'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.text('Ada'), findsOneWidget);
    await tester.tap(find.text('15').first);
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Salvar'), findsOneWidget);
  });

  testWidgets('carinho snackbar names the kind', (tester) async {
    _pinSurface(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(_Session.new),
          currentMoodProvider.overrideWith((ref) async => _mood),
          nudgesRepositoryProvider.overrideWithValue(_Nudges()),
        ],
        child: const MaterialApp(home: Scaffold(body: MoodHomeCard())),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    await tester.tap(find.text('💗 Pensando em você'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.text('Carinho enviado: Pensando em você'), findsOneWidget);
  });
}

List<String> _contents(ProviderContainer container) {
  return [
    for (final list in container.read(listsViewModelProvider).lists)
      for (final item in list.items) item.content,
  ];
}

Future<void> _loaded(ProviderContainer container) async {
  for (var i = 0; i < 20; i++) {
    if (!container.read(listsViewModelProvider).isLoading) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('lists did not load');
}

class _Session extends SessionNotifier {
  @override
  Future<Session?> build() async => const Session(
    id: 'ada',
    email: 'a@example.com',
    name: 'Ada',
    isPaired: true,
    coupleId: 'couple-1',
    pairingCode: 'ABC123',
  );
}

final _couple = Couple(
  id: 'couple-1',
  pairedAt: DateTime.utc(2024, 1, 1),
  anniversaryDate: '2024-01-01',
  timezone: 'America/Sao_Paulo',
  daysTogether: 10,
  partner: const CouplePartner(id: 'bruno', name: 'Bruno'),
  upcoming: const [],
);

final _mood = MoodCurrent(
  me: MoodSnapshot(
    mood: MoodLevel.good,
    createdAt: DateTime.utc(2026, 1, 1),
    stale: false,
  ),
  partner: MoodSnapshot(
    mood: MoodLevel.low,
    createdAt: DateTime.utc(2026, 1, 1),
    stale: false,
  ),
);

class _SaveProbe extends StatefulWidget {
  const _SaveProbe();

  @override
  State<_SaveProbe> createState() => _SaveProbeState();
}

class _SaveProbeState extends State<_SaveProbe> {
  var _busy = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FilledButton(
          onPressed: _busy ? null : () {},
          child: const Text('Salvar'),
        ),
        UnpairButton(onBusyChanged: (busy) => setState(() => _busy = busy)),
      ],
    );
  }
}

class _ListsRepo implements IListsRepository {
  final _add = Completer<ListItem>();
  var failCreate = false;

  void releaseAdd() {
    if (!_add.isCompleted) {
      _add.complete(
        ListItem(
          id: 'item-1',
          listId: 'list-1',
          content: 'AuditSlow',
          isCompleted: false,
          addedById: 'ada',
          createdAt: DateTime.utc(2026, 1, 2),
        ),
      );
    }
  }

  PartnerList _list() {
    return PartnerList(
      id: 'list-1',
      type: 'TODO',
      name: 'Compras',
      ownerId: 'ada',
      items: const [],
      createdAt: DateTime.utc(2026, 1, 1),
    );
  }

  @override
  Future<List<PartnerList>> getLists() async => [_list()];

  @override
  Future<PartnerList> createList(
    String type,
    String name, {
    String? visibility,
  }) {
    if (failCreate) {
      return Future.error(const CPLHttpNoInternetConnectionException());
    }
    return Future.value(_list());
  }

  @override
  Future<ListItem> addItem(
    String listId,
    String content,
    Map<String, dynamic>? metadata,
  ) {
    return _add.future;
  }

  @override
  Future<void> deleteItem(String itemId) async {}

  @override
  Future<void> deleteList(String listId) async {}

  @override
  Future<ListItem> toggleItem(String itemId) => _add.future;
}

class _CoupleRepo implements ICoupleRepository {
  _CoupleRepo({this.hangUpdate});

  final Completer<Couple>? hangUpdate;

  @override
  Future<Couple> getCouple() async => _couple;

  @override
  Future<Couple> updateCouple({String? anniversaryDate, String? timezone}) {
    final hang = hangUpdate;
    if (hang != null) return hang.future;
    return Future<Couple>.error(const CPLHttpNoInternetConnectionException());
  }

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

  @override
  Future<void> updateMyBirthDate(String? birthDate) async {}
}

class _Pairing implements IPairingRepository {
  _Pairing(this.status, {this.hungPair, this.hungUnpair});

  final PairingSnapshot status;
  final Future<PairResult>? hungPair;
  final Future<void>? hungUnpair;
  var pairs = 0;
  var statusReads = 0;

  @override
  Future<PairingSnapshot> getStatus() async {
    statusReads += 1;
    return status;
  }

  @override
  Future<PairResult> pair(String code) {
    pairs += 1;
    return hungPair ??
        Future.value(
          const PairResult(phase: PairingPhase.pending, message: 'ok'),
        );
  }

  @override
  Future<void> cancelRequest() async {}

  @override
  Future<void> unpair() {
    return hungUnpair ?? Future<void>.value();
  }

  @override
  Future<void> ensurePairingCode() {
    return Future<void>.error(const CPLHttpNoInternetConnectionException());
  }

  @override
  Future<List<IncomingPairingRequest>> receivedRequests() async => const [];

  @override
  Future<PairResult> acceptRequest(String id) async {
    throw UnimplementedError();
  }

  @override
  Future<void> declineRequest(String id) async {}

}

class _MoodRepo implements IMoodRepository {
  @override
  Future<MoodCheckin> create({required MoodLevel mood, String? note}) async {
    return MoodCheckin(
      id: 'm1',
      userId: 'ada',
      mood: mood,
      createdAt: DateTime.utc(2026, 1, 1),
    );
  }

  @override
  Future<MoodCurrent> current() async => _mood;

  @override
  Future<MoodHistory> history({int days = 30}) async {
    return const MoodHistory(days: 30, items: []);
  }
}

class _Nudges implements INudgesRepository {
  @override
  Future<Nudge> send({required NudgeKind kind, String? message}) async {
    return Nudge(
      id: 'n1',
      senderId: 'ada',
      receiverId: 'bruno',
      kind: kind,
      createdAt: DateTime.utc(2026, 1, 1),
    );
  }

  @override
  Future<NudgePage> received({String? cursor}) async {
    return const NudgePage(items: []);
  }

  @override
  Future<Nudge> markSeen(String id) {
    return send(kind: NudgeKind.thinkingOfYou);
  }
}

/// [OutlinedButton.icon] is a private subclass, so an exact [OutlinedButton]
/// lookup misses it on some Flutter versions.
Finder _outlinedLabel(String label) {
  return find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((widget) {
      return widget is ButtonStyleButton &&
          widget.runtimeType.toString().contains('OutlinedButton');
    }),
  );
}

void _pinSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
