import 'dart:async';

import 'package:couple2_app/app/routing/router.dart';
import 'package:couple2_app/core/errors/user_facing_error.dart';
import 'package:couple2_app/app/session.dart';
import 'package:couple2_app/app/session_provider.dart';
import 'package:couple2_app/app/ui/pages/home/home_page.dart';
import 'package:couple2_app/design_system/design_system.dart';
import 'package:couple2_app/modules/couple/data/couple_providers.dart';
import 'package:couple2_app/modules/couple/domain/domain.dart';
import 'package:couple2_app/modules/couple/ui/pages/couple_settings/couple_settings_page.dart';
import 'package:couple2_app/modules/daily_question/data/daily_question_providers.dart';
import 'package:couple2_app/modules/date_plans/data/date_plans_providers.dart';
import 'package:couple2_app/modules/feed/data/feed_providers.dart';
import 'package:couple2_app/modules/feed/data/feed_repository.dart';
import 'package:couple2_app/modules/feed/domain/domain.dart';
import 'package:couple2_app/modules/feed/ui/widgets/feed_preview.dart';
import 'package:couple2_app/modules/lists/data/lists_providers.dart';
import 'package:couple2_app/modules/lists/data/lists_repository.dart';
import 'package:couple2_app/modules/lists/domain/domain.dart';
import 'package:couple2_app/modules/lists/ui/pages/lists/lists_page.dart';
import 'package:couple2_app/modules/mood/data/mood_providers.dart';
import 'package:couple2_app/modules/mood/data/mood_repository.dart';
import 'package:couple2_app/modules/mood/data/nudges_repository.dart';
import 'package:couple2_app/modules/mood/domain/domain.dart';
import 'package:couple2_app/modules/mood/ui/pages/nudges/nudges_page.dart';
import 'package:couple2_app/modules/mood/ui/widgets/mood_home_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('timezone ids are shown in portuguese', () {
    expect(timezoneLabel('America/Sao_Paulo'), 'Brasília (São Paulo)');
    expect(timezoneLabel('America/Sao_Paulo'), isNot(contains('America/')));
  });

  testWidgets('unknown route hides the GoException', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: lightTheme, home: const UnknownRoutePage()),
    );
    expect(find.text('Página não encontrada'), findsOneWidget);
    expect(find.text('Essa página não existe.'), findsOneWidget);
    expect(find.byTooltip('Voltar'), findsOneWidget);
    expect(find.textContaining('GoException'), findsNothing);
    expect(find.textContaining('Page Not Found'), findsNothing);
  });

  testWidgets('character counter uses portuguese', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('pt', 'BR'),
        supportedLocales: [Locale('pt', 'BR')],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: TextField(
            maxLength: 140,
            decoration: InputDecoration(labelText: 'Nota'),
          ),
        ),
      ),
    );
    expect(
      find.bySemanticsLabel(RegExp('140 caracteres restantes')),
      findsWidgets,
    );
    expect(find.bySemanticsLabel(RegExp('characters remaining')), findsNothing);
    semantics.dispose();
  });

  testWidgets('confirm dialog uses a filled primary action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme,
        home: Builder(
          builder: (context) {
            return FilledButton(
              onPressed: () {
                confirmDestructive(
                  context,
                  title: 'Excluir lista?',
                  message: 'Some para os dois.',
                  confirmLabel: 'Excluir',
                );
              },
              child: const Text('Abrir'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextButton, 'Cancelar'), findsOneWidget);
    final confirm = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Excluir'),
    );
    expect(confirm.onPressed, isNotNull);
    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.widgetWithText(FilledButton, 'Excluir'),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.color, const Color(0xFF9D174D));
  });

  testWidgets('home mood card leaves the skeleton when the network hangs', (
    tester,
  ) async {
    final repo = _HangMood();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(_Session.new),
          moodRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          theme: lightTheme,
          home: const Scaffold(body: MoodHomeCard()),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CardSkeleton), findsOneWidget);
    expect(repo.currentCalls, 1);

    await tester.pump(const Duration(seconds: 13));
    await tester.pump();
    expect(find.text('Como vocês estão'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
    expect(find.text(slowConnectionMessage), findsOneWidget);
    expect(repo.currentCalls, 1);

    await tester.pump(const Duration(seconds: 20));
    expect(repo.currentCalls, 1);

    await tester.tap(find.text('Tentar de novo'));
    await tester.pump();
    expect(repo.currentCalls, 2);
    await tester.pump(const Duration(seconds: 13));
    await tester.pump();
    expect(repo.currentCalls, 2);
    expect(find.text('Tentar de novo'), findsOneWidget);
  });

  testWidgets('feed preview shows a portuguese retry when offline', (
    tester,
  ) async {
    final repo = _HangFeed();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(_Session.new),
          feedRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          theme: lightTheme,
          home: Scaffold(body: FeedPreview(onOpen: () {})),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 13));
    await tester.pump();
    expect(find.text('O que rolou'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
    expect(find.text(slowConnectionMessage), findsOneWidget);
    expect(find.textContaining('Error connecting'), findsNothing);
    expect(repo.feedCalls, 1);

    await tester.tap(find.text('Tentar de novo'));
    await tester.pump();
    expect(repo.feedCalls, 2);
    await tester.pump(const Duration(seconds: 13));
    await tester.pump();
    expect(repo.feedCalls, 2);
    expect(find.text('Tentar de novo'), findsOneWidget);
  });

  testWidgets('the bell opens the feed in one tap', (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const HomePage()),
        GoRoute(
          path: '/feed',
          builder: (_, __) => const Scaffold(body: Text('Feed aberto')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(_Session.new),
          coupleProvider.overrideWith((ref) async => _couple),
          currentMoodProvider.overrideWith((ref) async => null),
          nextDateProvider.overrideWith((ref) async => null),
          todayQuestionProvider.overrideWith((ref) async => null),
          feedPreviewProvider.overrideWith((ref) async => const []),
          unreadCountProvider.overrideWith((ref) async => 0),
        ],
        child: MaterialApp.router(theme: lightTheme, routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byTooltip('O que rolou'));
    await tester.pumpAndSettle();
    expect(find.text('Feed aberto'), findsOneWidget);
  });

  testWidgets('a presentes row opens on the first tap', (tester) async {
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
        overrides: [listsRepositoryProvider.overrideWithValue(_GiftLists())],
        child: MaterialApp.router(theme: lightTheme, routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Presentes'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(find.text('Lista aberta'), findsOneWidget);
  });

  testWidgets('nudges mark seen and ver mais stay in portuguese', (
    tester,
  ) async {
    final repo = _Nudges();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [nudgesRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: NudgesPage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(repo.seen, 1);
    expect(find.text(offlineUserMessage), findsOneWidget);
    expect(find.textContaining('Error connecting'), findsNothing);
    expect(find.text('Ver mais'), findsOneWidget);

    await tester.tap(find.text('Ver mais'));
    await tester.tap(find.text('Ver mais'), warnIfMissed: false);
    await tester.pump();

    expect(repo.more, 1);
    expect(find.text('Carregando…'), findsOneWidget);
    repo.failMore();
    await tester.pump();
    expect(find.textContaining('SocketException'), findsNothing);
    expect(find.textContaining('Connection refused'), findsNothing);
    expect(find.text(offlineUserMessage), findsWidgets);
  });
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
}

class _Nudges implements INudgesRepository {
  int seen = 0;
  int more = 0;
  final _more = Completer<NudgePage>();

  void failMore() {
    if (!_more.isCompleted) {
      _more.completeError(Exception('SocketException: Connection refused'));
    }
  }

  @override
  Future<Nudge> markSeen(String id) async {
    seen++;
    throw Exception('Error connecting to the server');
  }

  @override
  Future<NudgePage> received({String? cursor}) {
    if (cursor != null) {
      more++;
      return _more.future;
    }
    return Future<NudgePage>.value(
      NudgePage(
        items: [
          Nudge(
            id: 'n1',
            senderId: 'bruno',
            receiverId: 'ada',
            kind: NudgeKind.hug,
            createdAt: DateTime.now(),
          ),
        ],
        nextCursor: 'c2',
      ),
    );
  }

  @override
  Future<Nudge> send({required NudgeKind kind, String? message}) {
    return Completer<Nudge>().future;
  }
}

class _HangMood implements IMoodRepository {
  int currentCalls = 0;

  @override
  Future<MoodCheckin> create({required MoodLevel mood, String? note}) {
    return Completer<MoodCheckin>().future;
  }

  @override
  Future<MoodCurrent> current() {
    currentCalls++;
    return Completer<MoodCurrent>().future;
  }

  @override
  Future<MoodHistory> history({int days = 30}) {
    return Completer<MoodHistory>().future;
  }
}

class _HangFeed implements IFeedRepository {
  int feedCalls = 0;

  @override
  Future<FeedPageResult> getFeed({String? cursor, int limit = 20}) {
    feedCalls++;
    return Completer<FeedPageResult>().future;
  }

  @override
  Future<void> markSeen() async {}

  @override
  Future<int> unreadCount() async => 0;
}

class _GiftLists implements IListsRepository {
  @override
  Future<List<PartnerList>> getLists() async {
    return [
      PartnerList(
        id: 'gifts',
        type: 'GIFT_IDEAS',
        name: 'Presentes',
        ownerId: 'ada',
        items: const [],
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    ];
  }

  @override
  Future<ListItem> addItem(
    String listId,
    String content,
    Map<String, dynamic>? metadata,
  ) => Future<ListItem>.error(StateError('unused'));

  @override
  Future<PartnerList> createList(
    String type,
    String name, {
    String? visibility,
  }) => Future<PartnerList>.error(StateError('unused'));

  @override
  Future<void> deleteItem(String itemId) =>
      Future<void>.error(StateError('unused'));

  @override
  Future<void> deleteList(String listId) =>
      Future<void>.error(StateError('unused'));

  @override
  Future<ListItem> toggleItem(String itemId) =>
      Future<ListItem>.error(StateError('unused'));
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
