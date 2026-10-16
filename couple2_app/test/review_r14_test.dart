import 'dart:async';
import 'dart:io';

import 'package:couple2_app/app/session.dart';
import 'package:couple2_app/app/session_provider.dart';
import 'package:couple2_app/app/ui/home_failure_scope.dart';
import 'package:couple2_app/app/ui/pages/home/home_page.dart';
import 'package:couple2_app/core/core.dart';
import 'package:couple2_app/design_system/design_system.dart';
import 'package:couple2_app/modules/couple/data/couple_providers.dart';
import 'package:couple2_app/modules/couple/data/couple_repository.dart';
import 'package:couple2_app/modules/couple/domain/domain.dart';
import 'package:couple2_app/modules/couple/ui/pages/important_dates/important_dates_page.dart';
import 'package:couple2_app/modules/couple/ui/widgets/couple_date_sheet.dart';
import 'package:couple2_app/modules/couple/ui/widgets/days_together_card.dart';
import 'package:couple2_app/modules/couple/ui/widgets/profile_sheet.dart';
import 'package:couple2_app/modules/daily_question/data/daily_question_providers.dart';
import 'package:couple2_app/modules/date_plans/data/date_plans_providers.dart';
import 'package:couple2_app/modules/feed/data/feed_providers.dart';
import 'package:couple2_app/modules/feed/domain/domain.dart';
import 'package:couple2_app/modules/feed/ui/pages/feed/feed_page.dart';
import 'package:couple2_app/modules/feed/ui/pages/feed/feed_viewmodel.dart';
import 'package:couple2_app/modules/lists/data/lists_providers.dart';
import 'package:couple2_app/modules/lists/data/lists_repository.dart';
import 'package:couple2_app/modules/lists/domain/domain.dart';
import 'package:couple2_app/modules/lists/ui/pages/lists/lists_page.dart';
import 'package:couple2_app/modules/mood/data/mood_providers.dart';
import 'package:couple2_app/modules/mood/domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  @override
  Future<void> updateMyBirthDate(String? birthDate) => Completer<void>().future;

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

class _DatesRepo implements ICoupleRepository {
  _DatesRepo(this.dates);

  List<CoupleDate> dates;
  bool fail = false;

  @override
  Future<List<CoupleDate>> getDates() async {
    if (fail) throw const CPLHttpNoInternetConnectionException();
    return dates;
  }

  @override
  Future<Couple> getCouple() => Completer<Couple>().future;

  @override
  Future<Couple> updateCouple({String? anniversaryDate, String? timezone}) =>
      Completer<Couple>().future;

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

  @override
  Future<void> updateMyBirthDate(String? birthDate) async {}
}

class _ListsRepo implements IListsRepository {
  _ListsRepo(this.lists);

  final List<PartnerList> lists;

  @override
  Future<List<PartnerList>> getLists() async => lists;

  @override
  Future<PartnerList> createList(
    String type,
    String name, {
    String? visibility,
  }) => Completer<PartnerList>().future;

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

class _CachedErrorFeed extends FeedViewModel {
  @override
  FeedState build() {
    return FeedState(
      errorMessage: offlineUserMessage,
      items: [
        ActivityEvent(
          id: 'e1',
          coupleId: 'couple-1',
          type: 'LIST_CREATED',
          entityType: 'LIST',
          entityId: 'list-1',
          createdAt: DateTime.utc(2026, 10, 1),
          payload: const {'listName': 'Mercado secreto'},
        ),
      ],
    );
  }
}

CoupleDate _date(String id, String title) {
  return CoupleDate(
    id: id,
    coupleId: 'couple-1',
    type: 'CUSTOM',
    title: title,
    date: '2026-12-01',
    recurrence: 'YEARLY',
    createdById: 'ada',
  );
}

final _couple = Couple(
  id: 'couple-1',
  pairedAt: DateTime.utc(2026, 10, 10),
  anniversaryDate: '2026-10-10',
  timezone: 'America/Sao_Paulo',
  daysTogether: 7,
  partner: const CouplePartner(id: 'bruno', name: 'Bruno'),
  upcoming: const [
    UpcomingDate(
      kind: 'custom',
      title: 'Casamento secreto',
      date: '2026-12-01',
      inDays: 40,
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a save blocks escape, barrier, drag, and back', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Future<void> open() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () {
                  showAppSheet<void>(
                    context: context,
                    builder: (_) => Padding(
                      padding: const EdgeInsets.all(24),
                      child: LoadingButton(
                        onPressed: () => Completer<void>().future,
                        child: const Text('Salvar'),
                      ),
                    ),
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
    }

    await open();
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.text('Salvar'), findsNothing, reason: 'idle barrier');

    await open();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Salvar'), findsNothing, reason: 'idle escape');

    await open();
    await tester.fling(find.text('Salvar'), const Offset(0, 500), 2000);
    await tester.pumpAndSettle();
    expect(find.text('Salvar'), findsNothing, reason: 'idle drag');

    await open();
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Salvar'), findsOneWidget);
    final route = ModalRoute.of(tester.element(find.text('Salvar')));
    expect(route!.barrierDismissible, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('Salvar'), findsOneWidget, reason: 'escape');

    await tester.tapAt(const Offset(8, 8));
    await tester.pump();
    expect(find.text('Salvar'), findsOneWidget, reason: 'corner');

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    await navigator.maybePop();
    await tester.pump();
    expect(find.text('Salvar'), findsOneWidget, reason: 'back');

    await tester.fling(
      find.text('Salvar'),
      const Offset(0, 500),
      2000,
      warnIfMissed: false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Salvar'), findsOneWidget, reason: 'drag');
  });

  testWidgets('profile, list, and date sheets stay up during a hung save', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Future<void> stuck(String label) async {
      await tester.pump();
      await tester.pump();
      expect(find.text(label), findsOneWidget);
      final route = ModalRoute.of(tester.element(find.text(label)));
      expect(route!.barrierDismissible, isFalse, reason: label);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.tapAt(const Offset(8, 8));
      await tester.pump();
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      await navigator.maybePop();
      await tester.pump();
      await tester.fling(
        find.text(label),
        const Offset(0, 400),
        2000,
        warnIfMissed: false,
      );
      await tester.pump();
      expect(find.text(label), findsOneWidget, reason: label);
    }

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
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await stuck('Salvar');
    await tester.pumpWidget(const SizedBox.shrink());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(() => _Session(_ada)),
          listsRepositoryProvider.overrideWithValue(_ListsRepo(const [])),
        ],
        child: MaterialApp(theme: lightTheme, home: const ListsPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Mercado');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Criar'));
    await stuck('Criar');
    await tester.pumpWidget(const SizedBox.shrink());

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
    await tester.enterText(find.byType(TextField), 'Aniversário');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Adicionar'));
    await stuck('Adicionar');
  });

  testWidgets('a non-dismissible sheet ignores escape and the barrier', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () {
                showAppSheet<void>(
                  context: context,
                  isDismissible: false,
                  enableDrag: false,
                  builder: (_) => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Humor'),
                  ),
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
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.tapAt(const Offset(8, 8));
    await tester.pump();
    expect(find.text('Humor'), findsOneWidget);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    await navigator.maybePop();
    await tester.pump();
    expect(find.text('Humor'), findsOneWidget);
  });

  testWidgets('home retry clears the offline subtitle before success', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const offline = CPLHttpNoInternetConnectionException();
    final mood = Completer<MoodCurrent?>();
    var moodFetches = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(() => _Session(_ada)),
          coupleProvider.overrideWith((ref) => Future<Couple?>.error(offline)),
          currentMoodProvider.overrideWith((ref) {
            moodFetches++;
            if (moodFetches == 1) return Future<MoodCurrent?>.error(offline);
            return mood.future;
          }),
          nextDateProvider.overrideWith((ref) => Future.error(offline)),
          todayQuestionProvider.overrideWith((ref) => Future.error(offline)),
          feedPreviewProvider.overrideWith((ref) => Future.error(offline)),
          unreadCountProvider.overrideWith((ref) async => 0),
        ],
        child: MaterialApp(theme: lightTheme, home: const HomePage()),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.byKey(offlineHomeNoticeKey), findsOneWidget);
    expect(find.text(offlineUserMessage), findsNWidgets(4));

    final moodCard = find.widgetWithText(
      LoadErrorCard,
      'Não foi possível carregar o humor.',
    );
    await tester.tap(
      find.descendant(of: moodCard, matching: find.text('Tentar de novo')),
    );
    await tester.pump();
    expect(find.byKey(offlineHomeNoticeKey), findsNothing);
    expect(find.text('Não foi possível carregar os encontros.'), findsNothing);
    expect(find.text(offlineUserMessage), findsWidgets);

    mood.complete(null);
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.byKey(offlineHomeNoticeKey), findsNothing);
    expect(find.text('Como vocês estão'), findsOneWidget);
    expect(find.text(offlineUserMessage), findsWidgets);
  });

  testWidgets('days together stays at the skeleton height, online or offline', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<double> cardHeight(Widget child) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: lightTheme,
          home: Scaffold(body: ListView(children: [child])),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      return tester.getSize(find.byWidget(child)).height;
    }

    final skeleton = await cardHeight(
      const CardSkeleton(lines: 2, minHeight: homeDaysCardHeight),
    );
    final error = await cardHeight(
      LoadErrorCard(
        message: offlineUserMessage,
        onRetry: () {},
        minHeight: homeDaysCardHeight,
      ),
    );
    final loaded = await cardHeight(
      DaysTogetherCard(
        couple: Couple(
          id: 'couple-1',
          pairedAt: DateTime.utc(2026, 10, 10),
          anniversaryDate: '2026-10-10',
          timezone: 'America/Sao_Paulo',
          daysTogether: 7,
          partner: const CouplePartner(id: 'bruno', name: 'Bruno'),
          upcoming: const [],
        ),
        onOpenSettings: () {},
        onOpenDates: () {},
      ),
    );
    final withNext = await cardHeight(
      DaysTogetherCard(
        couple: _couple,
        onOpenSettings: () {},
        onOpenDates: () {},
      ),
    );
    expect(skeleton, homeDaysCardHeight);
    expect(error, skeleton);
    expect(loaded, skeleton);
    expect(withNext, greaterThanOrEqualTo(loaded));

    final moodSkeleton = await cardHeight(
      const CardSkeleton(lines: 2, minHeight: homeMoodCardHeight),
    );
    final moodError = await cardHeight(
      LoadErrorCard(
        message: 'Não foi possível carregar o humor.',
        onRetry: () {},
        minHeight: homeMoodCardHeight,
      ),
    );
    expect(moodSkeleton, homeMoodCardHeight);
    expect(moodError, moodSkeleton);
    expect(moodError, lessThan(200));

    const offline = CPLHttpNoInternetConnectionException();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(() => _Session(_ada)),
          coupleProvider.overrideWith((ref) async => null),
          currentMoodProvider.overrideWith((ref) async => null),
          nextDateProvider.overrideWith((ref) async => null),
          todayQuestionProvider.overrideWith((ref) async => null),
          feedPreviewProvider.overrideWith((ref) async => const []),
          unreadCountProvider.overrideWith((ref) async => 0),
        ],
        child: MaterialApp(theme: lightTheme, home: const HomePage()),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(
      find.text('Não foi possível carregar os dias juntos.'),
      findsOneWidget,
    );
    expect(
      tester
          .getSize(
            find.widgetWithText(
              LoadErrorCard,
              'Não foi possível carregar os dias juntos.',
            ),
          )
          .height,
      homeDaysCardHeight,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(() => _Session(_ada)),
          coupleProvider.overrideWith((ref) => Future<Couple?>.error(offline)),
          currentMoodProvider.overrideWith((ref) => Future.error(offline)),
          nextDateProvider.overrideWith((ref) => Future.error(offline)),
          todayQuestionProvider.overrideWith((ref) => Future.error(offline)),
          feedPreviewProvider.overrideWith((ref) => Future.error(offline)),
          unreadCountProvider.overrideWith((ref) async => 0),
        ],
        child: MaterialApp(theme: lightTheme, home: const HomePage()),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.text(offlineUserMessage), findsNWidgets(4));
    final days = find.byWidgetPredicate(
      (widget) =>
          widget is LoadErrorCard && widget.minHeight == homeDaysCardHeight,
    );
    expect(days, findsOneWidget);
    expect(tester.getSize(days).height, homeDaysCardHeight);
    expect(
      tester
          .getSize(
            find.widgetWithText(
              LoadErrorCard,
              'Não foi possível carregar o humor.',
            ),
          )
          .height,
      homeMoodCardHeight,
    );
  });

  testWidgets('important dates show cache or the error, and clear the FAB', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _DatesRepo(const []);

    Future<void> pump() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith(() => _Session(_ada)),
            coupleRepositoryProvider.overrideWithValue(repo),
            coupleProvider.overrideWith((ref) async => _couple),
          ],
          child: MaterialApp(theme: lightTheme, home: const ImportantDatesPage()),
        ),
      );
      await tester.pumpAndSettle();
    }

    repo.fail = true;
    await pump();
    expect(find.textContaining('Casamento secreto'), findsNothing);
    expect(find.text('Próximas datas'), findsNothing);
    expect(find.text(offlineUserMessage), findsOneWidget);
    expect(find.text('Datas do casal'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    repo
      ..fail = false
      ..dates = [_date('d1', 'Data guardada')];
    await pump();
    expect(find.text('Data guardada'), findsOneWidget);
    expect(find.textContaining('Casamento secreto'), findsOneWidget);
    expect(find.text(offlineUserMessage), findsNothing);

    repo.fail = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Data guardada'), findsOneWidget);
    expect(find.byType(ErrorView), findsNothing);
    expect(find.textContaining('Casamento secreto'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    repo
      ..fail = false
      ..dates = [for (var i = 0; i < 8; i++) _date('d$i', 'Data $i')];
    await pump();
    final scroll = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    scroll.position.jumpTo(scroll.position.maxScrollExtent);
    await tester.pump();
    final fab = tester.getRect(find.byType(FloatingActionButton));
    final last = tester.getRect(find.byKey(const Key('date-row-d7')));
    expect(
      last.bottom,
      lessThanOrEqualTo(fab.top + 0.5),
      reason:
          'pixels=${scroll.position.pixels} max=${scroll.position.maxScrollExtent} '
          'last=${last.bottom} fab=${fab.top}',
    );
    expect(fab.height, AppFab.extent);
  });

  testWidgets('lists leave the last card above the FAB', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final lists = [
      for (var i = 0; i < 8; i++)
        PartnerList(
          id: 'l$i',
          type: 'SHOPPING_CART',
          name: 'Lista $i',
          ownerId: 'ada',
          items: const [],
          createdAt: DateTime.utc(2026, 10, 1),
        ),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(() => _Session(_ada)),
          listsRepositoryProvider.overrideWithValue(_ListsRepo(lists)),
        ],
        child: MaterialApp(theme: lightTheme, home: const ListsPage()),
      ),
    );
    await tester.pumpAndSettle();
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
    scroll.position.jumpTo(scroll.position.maxScrollExtent);
    await tester.pump();
    final fab = tester.getRect(find.byType(FloatingActionButton));
    final last = tester.getRect(find.text('Lista 7'));
    expect(last.bottom, lessThanOrEqualTo(fab.top + 0.5));
  });

  testWidgets('feed refresh keeps the cache without an error card', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(() => _Session(_ada)),
          feedViewModelProvider.overrideWith(_CachedErrorFeed.new),
        ],
        child: MaterialApp(theme: lightTheme, home: const FeedPage()),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Mercado secreto'), findsOneWidget);
    expect(find.byType(LoadErrorCard), findsNothing);
    expect(find.byType(ErrorView), findsNothing);
    expect(find.text('Tentar de novo'), findsNothing);
  });

  test('showModalBottomSheet stays inside showAppSheet', () {
    final pattern = RegExp(r'showModalBottomSheet');
    const allow = 'lib/design_system/widgets/app_sheet.dart';
    final hits = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final normalized = entity.path.replaceAll('\\', '/');
      final rel = normalized.substring(normalized.indexOf('lib/'));
      if (rel == allow) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (pattern.hasMatch(lines[i])) {
          hits.add('$rel:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });
}
