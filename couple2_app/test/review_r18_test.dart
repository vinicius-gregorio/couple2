import 'package:couple2_app/app/session.dart';
import 'package:couple2_app/app/session_provider.dart';
import 'package:couple2_app/app/ui/pages/home/home_page.dart';
import 'package:couple2_app/core/core.dart';
import 'package:couple2_app/design_system/design_system.dart';
import 'package:couple2_app/modules/couple/data/couple_providers.dart';
import 'package:couple2_app/modules/couple/data/couple_repository.dart';
import 'package:couple2_app/modules/couple/domain/domain.dart';
import 'package:couple2_app/modules/couple/ui/pages/couple_settings/couple_settings_page.dart';
import 'package:couple2_app/modules/couple/ui/pages/important_dates/important_dates_page.dart';
import 'package:couple2_app/modules/daily_question/data/daily_question_providers.dart';
import 'package:couple2_app/modules/date_plans/data/date_plans_providers.dart';
import 'package:couple2_app/modules/feed/data/feed_providers.dart';
import 'package:couple2_app/modules/lists/data/lists_providers.dart';
import 'package:couple2_app/modules/lists/data/lists_repository.dart';
import 'package:couple2_app/modules/lists/domain/domain.dart';
import 'package:couple2_app/modules/lists/ui/pages/lists/lists_page.dart';
import 'package:couple2_app/modules/mood/data/mood_providers.dart';
import 'package:couple2_app/modules/mood/domain/domain.dart';
import 'package:couple2_app/modules/mood/ui/widgets/nudge_composer_sheet.dart';
import 'package:couple2_app/modules/pairing/data/pairing_providers.dart';
import 'package:couple2_app/modules/pairing/data/pairing_repository.dart';
import 'package:couple2_app/modules/pairing/domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _offline = CPLHttpNoInternetConnectionException();

const _session = Session(
  id: 'ada',
  email: 'ada@couple2.test',
  name: 'Ada',
  isPaired: true,
  coupleId: 'couple-1',
);

final _couple = Couple(
  id: 'couple-1',
  pairedAt: DateTime.utc(2024, 1, 1),
  anniversaryDate: '2024-01-01',
  timezone: 'America/Sao_Paulo',
  daysTogether: 10,
  partner: const CouplePartner(id: 'bruno', name: 'Bruno'),
  upcoming: const [],
);

const _date = CoupleDate(
  id: 'date-1',
  coupleId: 'couple-1',
  type: 'CUSTOM',
  title: 'Data r18',
  date: '2026-10-17',
  recurrence: 'YEARLY',
  createdById: 'ada',
);

final _list = PartnerList(
  id: 'list-1',
  type: 'SHOPPING_CART',
  name: 'Mercado',
  ownerId: 'ada',
  items: const [],
  createdAt: DateTime.utc(2026, 1, 1),
);

class _ColdSession extends SessionNotifier {
  var online = false;
  var refreshes = 0;

  @override
  Future<Session?> build() async {
    if (!online) throw _offline;
    return _session;
  }

  @override
  Future<void> refresh() async {
    refreshes++;
    online = true;
    state = const AsyncData(_session);
  }
}

class _ReadySession extends SessionNotifier {
  var refreshes = 0;

  @override
  Future<Session?> build() async => _session;

  @override
  Future<void> refresh() async {
    refreshes++;
  }
}

class _CoupleRepo implements ICoupleRepository {
  _CoupleRepo({this.fail = false});

  bool fail;
  var gets = 0;

  @override
  Future<Couple> getCouple() async {
    gets++;
    if (fail) throw _offline;
    return _couple;
  }

  @override
  Future<Couple> updateCouple({String? anniversaryDate, String? timezone}) {
    throw UnimplementedError();
  }

  @override
  Future<List<CoupleDate>> getDates() async => const [_date];

  @override
  Future<CoupleDate> createDate({
    required String title,
    required String date,
    String? recurrence,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CoupleDate> updateDate(
    String id, {
    String? title,
    String? date,
    String? recurrence,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteDate(String id) async {}

  @override
  Future<void> updateMyBirthDate(String? birthDate) async {}
}

class _FixedDates extends CoupleDatesNotifier {
  @override
  Future<List<CoupleDate>> build() async => const [_date];
}

class _ListsRepo implements IListsRepository {
  @override
  Future<List<PartnerList>> getLists() async => [_list];

  @override
  Future<PartnerList> createList(
    String type,
    String name, {
    String? visibility,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ListItem> addItem(
    String listId,
    String content,
    Map<String, dynamic>? metadata,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<ListItem> toggleItem(String itemId) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteItem(String itemId) async {}

  @override
  Future<void> deleteList(String listId) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'couple retry refetches auth and the couple after a cold failure',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final session = _ColdSession();
      final repo = _CoupleRepo();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith(() => session),
            coupleRepositoryProvider.overrideWithValue(repo),
            pairingRepositoryProvider.overrideWithValue(_QuietPairing()),
            pairingPollIntervalProvider.overrideWithValue(null),
          ],
          child: const MaterialApp(home: CoupleSettingsPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tentar de novo'), findsOneWidget);
      expect(repo.gets, 0);

      await tester.tap(find.text('Tentar de novo'));
      await tester.pumpAndSettle();

      expect(session.refreshes, 1);
      expect(repo.gets, greaterThanOrEqualTo(1));
      expect(find.text('Tentar de novo'), findsNothing);
      expect(find.text('Salvar'), findsOneWidget);
    },
  );

  testWidgets(
    'couple retry refetches /couple when the session is already known',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _CoupleRepo(fail: true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith(_ReadySession.new),
            coupleRepositoryProvider.overrideWithValue(repo),
            pairingRepositoryProvider.overrideWithValue(_QuietPairing()),
            pairingPollIntervalProvider.overrideWithValue(null),
          ],
          child: const MaterialApp(home: CoupleSettingsPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(offlineUserMessage), findsOneWidget);
      expect(repo.gets, 1);

      repo.fail = false;
      await tester.tap(find.text('Tentar de novo'));
      await tester.pumpAndSettle();

      expect(repo.gets, 2);
      expect(find.text('Salvar'), findsOneWidget);
      expect(find.text(offlineUserMessage), findsNothing);
    },
  );

  testWidgets('one failed home card replaces the page with one retry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(_ReadySession.new),
          coupleProvider.overrideWith((ref) async => _couple),
          currentMoodProvider.overrideWith(
            (ref) => Future<MoodCurrent?>.error(_offline),
          ),
          nextDateProvider.overrideWith((ref) async => null),
          todayQuestionProvider.overrideWith((ref) async => null),
          feedPreviewProvider.overrideWith((ref) async => const []),
          unreadCountProvider.overrideWith((ref) async => 0),
        ],
        child: MaterialApp(theme: lightTheme, home: const HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(offlineUserMessage), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
    expect(find.text('Como vocês estão'), findsNothing);
    expect(find.text('7 dias juntos'), findsNothing);
  });

  testWidgets('a sheet action error sits above the field and the send button', (
    tester,
  ) async {
    for (final size in const [Size(390, 844), Size(1280, 800)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          theme: lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  showNudgeComposerSheet(
                    context,
                    onSend: (_) async {
                      throw _offline;
                    },
                  );
                },
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enviar'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
      final error = tester.getRect(find.text(offlineUserMessage));
      final field = tester.getRect(find.byType(TextField));
      final send = tester.getRect(find.widgetWithText(FilledButton, 'Enviar'));
      expect(field.bottom, lessThanOrEqualTo(error.top + 1));
      expect(error.bottom, lessThanOrEqualTo(send.top + 1));
      for (final chip in tester.widgetList<ChoiceChip>(
        find.byType(ChoiceChip),
      )) {
        final box = tester.getRect(find.byWidget(chip));
        expect(
          error.overlaps(box),
          isFalse,
          reason: 'error covers a chip at $size',
        );
      }
      expect(error.overlaps(field), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('list card copy shares the icon axis', (tester) async {
    for (final size in const [Size(390, 844), Size(1280, 800)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith(_ReadySession.new),
            listsRepositoryProvider.overrideWithValue(_ListsRepo()),
          ],
          child: MaterialApp(theme: lightTheme, home: const ListsPage()),
        ),
      );
      await tester.pumpAndSettle();

      final copy = tester.getCenter(
        find.byKey(const Key('list-card-copy-list-1')),
      );
      final icon = tester.getCenter(find.byIcon(Icons.shopping_cart));
      final chevron = tester.getCenter(find.byIcon(Icons.chevron_right));
      final trash = tester.getCenter(find.byTooltip('Excluir lista'));
      expect((copy.dy - icon.dy).abs(), lessThanOrEqualTo(1));
      expect((chevron.dy - icon.dy).abs(), lessThanOrEqualTo(1));
      expect((trash.dy - icon.dy).abs(), lessThanOrEqualTo(1));
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('date rows and list cards expose a semantics label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith(_ReadySession.new),
            coupleProvider.overrideWith((ref) async => null),
            coupleDatesProvider.overrideWith(_FixedDates.new),
            listsRepositoryProvider.overrideWithValue(_ListsRepo()),
          ],
          child: MaterialApp(
            theme: lightTheme,
            home: const Scaffold(
              body: Column(
                children: [
                  Expanded(child: ImportantDatesPage()),
                  Expanded(child: ListsPage()),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel('Data r18, 17/10/2026, todo ano'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Mercado, Carrinho, 0 de 0 feitos'),
        findsOneWidget,
      );
    } finally {
      handle.dispose();
    }
  });
}

class _QuietPairing implements IPairingRepository {
  @override
  Future<PairingSnapshot> getStatus() async {
    return const PairingSnapshot(phase: PairingPhase.paired);
  }

  @override
  Future<PairResult> pair(String code) async {
    return const PairResult(phase: PairingPhase.paired, message: 'ok');
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
    return const PairResult(phase: PairingPhase.paired, message: 'ok');
  }

  @override
  Future<void> declineRequest(String id) async {}
}
