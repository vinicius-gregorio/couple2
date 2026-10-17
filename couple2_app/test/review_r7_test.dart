import 'package:couple2_app/app/session.dart';
import 'package:couple2_app/app/session_provider.dart';
import 'package:couple2_app/app/ui/pages/home/home_page.dart';
import 'package:couple2_app/core/core.dart';
import 'package:couple2_app/design_system/design_system.dart';
import 'package:couple2_app/modules/couple/data/couple_providers.dart';
import 'package:couple2_app/modules/couple/domain/domain.dart';
import 'package:couple2_app/modules/daily_question/data/daily_question_providers.dart';
import 'package:couple2_app/modules/date_plans/data/date_plans_providers.dart';
import 'package:couple2_app/modules/date_plans/domain/domain.dart';
import 'package:couple2_app/modules/feed/data/feed_providers.dart';
import 'package:couple2_app/modules/feed/domain/domain.dart';
import 'package:couple2_app/modules/mood/data/mood_providers.dart';
import 'package:couple2_app/modules/pairing/data/pairing_providers.dart';
import 'package:couple2_app/modules/pairing/data/pairing_repository.dart';
import 'package:couple2_app/modules/pairing/domain/domain.dart';
import 'package:couple2_app/modules/pairing/routing/routing.dart';
import 'package:couple2_app/modules/pairing/routing/routes.dart';
import 'package:couple2_app/modules/pairing/ui/pages/pairing_code/pairing_code_page.dart';
import 'package:couple2_app/modules/pairing/ui/pages/waiting/waiting_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _HomeOffline extends Notifier<bool> {
  @override
  bool build() => false;

  void down() => state = true;
}

final _homeOfflineProvider = NotifierProvider<_HomeOffline, bool>(
  _HomeOffline.new,
);

const _paired = Session(
  id: 'user-k',
  email: 'k@example.com',
  name: 'Kai',
  isPaired: true,
  coupleId: 'couple-1',
  partnerId: 'user-m',
  partnerName: 'Marina',
);

const _unpaired = Session(
  id: 'user-h',
  email: 'h@example.com',
  name: 'Helena',
  isPaired: false,
  pairingCode: 'HHHHHH',
);

class _Session extends SessionNotifier {
  _Session(this.current);

  final Session current;

  @override
  Future<Session?> build() => SynchronousFuture(current);

  @override
  Future<void> refresh() async {}
}

class _Repo implements IPairingRepository {
  _Repo(this.status);

  PairingSnapshot status;
  Object? cancelError;
  Object? incomingError;
  int cancels = 0;

  @override
  Future<void> cancelRequest() async {
    cancels++;
    final error = cancelError;
    if (error != null) throw error;
  }

  @override
  Future<PairingSnapshot> getStatus() async => status;

  @override
  Future<PairResult> pair(String code) async =>
      const PairResult(phase: PairingPhase.pending, message: 'ok');

  @override
  Future<void> unpair() async {}

  @override
  Future<void> ensurePairingCode() async {}

  @override
  Future<List<IncomingPairingRequest>> receivedRequests() async {
    final error = incomingError;
    if (error != null) throw error;
    return const [];
  }

  @override
  Future<PairResult> acceptRequest(String id) async {
    throw UnimplementedError();
  }

  @override
  Future<void> declineRequest(String id) async {}
}

final _couple = Couple(
  id: 'couple-1',
  pairedAt: DateTime.utc(2026, 10, 10),
  anniversaryDate: '2026-10-10',
  timezone: 'America/Sao_Paulo',
  daysTogether: 7,
  partner: const CouplePartner(id: 'user-m', name: 'Marina'),
  upcoming: const [],
);

final _plan = DatePlan(
  id: 'plan-1',
  coupleId: 'couple-1',
  proposerId: 'user-m',
  title: 'Japonês',
  scheduledAt: DateTime(2026, 10, 20, 20),
  status: DatePlanStatus.accepted,
  createdById: 'user-m',
  createdAt: DateTime.utc(2026, 10, 1),
  updatedAt: DateTime.utc(2026, 10, 1),
);

void _pin(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'a failed refresh replaces the home cards with the error',
    (tester) async {
      _pin(tester);
      const offline = CPLHttpNoInternetConnectionException();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith(() => _Session(_paired)),
            coupleProvider.overrideWith((ref) async {
              if (ref.watch(_homeOfflineProvider)) throw offline;
              return _couple;
            }),
            nextDateProvider.overrideWith((ref) async {
              if (ref.watch(_homeOfflineProvider)) throw offline;
              return _plan;
            }),
            currentMoodProvider.overrideWith((ref) async {
              if (ref.watch(_homeOfflineProvider)) throw offline;
              return null;
            }),
            todayQuestionProvider.overrideWith((ref) async {
              if (ref.watch(_homeOfflineProvider)) throw offline;
              return null;
            }),
            feedPreviewProvider.overrideWith((ref) async {
              if (ref.watch(_homeOfflineProvider)) throw offline;
              return const <ActivityEvent>[];
            }),
            unreadCountProvider.overrideWith((ref) async => 0),
          ],
          child: MaterialApp(theme: lightTheme, home: const HomePage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('7 dias juntos'), findsOneWidget);
      expect(find.textContaining('Japonês'), findsOneWidget);
      expect(find.text('Planejar um encontro'), findsNothing);
      expect(find.byType(LoadErrorCard), findsNothing);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomePage)),
      );
      container.read(_homeOfflineProvider.notifier).down();
      await tester.pumpAndSettle();

      expect(find.text('7 dias juntos'), findsNothing);
      expect(find.textContaining('Japonês'), findsNothing);
      expect(find.text(offlineUserMessage), findsOneWidget);
      expect(find.text('Tentar de novo'), findsOneWidget);
    },
  );

  testWidgets('a declined request is body text, not error red', (tester) async {
    _pin(tester);
    final repo = _Repo(
      const PairingSnapshot(phase: PairingPhase.unpaired, pairingCode: 'HHHHHH'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(() => _Session(_unpaired)),
          pairingRepositoryProvider.overrideWithValue(repo),
          pairingPollIntervalProvider.overrideWithValue(null),
        ],
        child: MaterialApp(theme: lightTheme, home: const PairingCodePage()),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PairingCodePage)),
    );
    container
        .read(pairingDeclineMessageProvider.notifier)
        .show(declinedPairingMessage);
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text(declinedPairingMessage), findsOneWidget);
    final text = tester.widget<Text>(find.text(declinedPairingMessage));
    final scheme = Theme.of(
      tester.element(find.text(declinedPairingMessage)),
    ).colorScheme;
    expect(text.style?.color, isNot(scheme.error));
    expect(text.style?.color, isNot(scheme.primary));
  });

  testWidgets(
    'offline cancel shows one error and clears it when status returns',
    (tester) async {
      _pin(tester);
      final repo = _Repo(
        const PairingSnapshot(
          phase: PairingPhase.pending,
          pendingCode: 'MMMMMM',
          pairingCode: 'HHHHHH',
        ),
      );
      repo.cancelError = const CPLHttpNoInternetConnectionException();
      final router = GoRouter(
        initialLocation: PairingRoutes.waiting,
        routes: [
          GoRoute(
            path: PairingRoutes.hub,
            builder: (_, _) => const PairingCodePage(),
          ),
          GoRoute(
            path: PairingRoutes.waiting,
            builder: (_, _) => const WaitingPage(),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith(() => _Session(_unpaired)),
            pairingRepositoryProvider.overrideWithValue(repo),
            pairingPollIntervalProvider.overrideWithValue(null),
          ],
          child: MaterialApp.router(theme: lightTheme, routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('cancel-pairing-request')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-cancel-pairing')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(WaitingPage)),
      );
      repo.incomingError = const CPLHttpNoInternetConnectionException();
      await container.read(incomingPairingRequestsProvider.notifier).reload();
      await tester.pump();

      expect(repo.cancels, 1);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text(offlineUserMessage), findsOneWidget);
      expect(find.text('Atualizando automaticamente…'), findsOneWidget);

      repo.cancelError = null;
      await container.read(pairingStatusProvider.notifier).poll();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text(offlineUserMessage), findsNothing);
      expect(find.text('Atualizando automaticamente…'), findsOneWidget);
    },
  );

  testWidgets('pairing navigation shows a single Parear title', (tester) async {
    _pin(tester);
    final repo = _Repo(
      const PairingSnapshot(
        phase: PairingPhase.pending,
        pendingCode: 'MMMMMM',
        pairingCode: 'HHHHHH',
      ),
    );
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomePage()),
        ...pairingRoutes,
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(() => _Session(_unpaired)),
          pairingRepositoryProvider.overrideWithValue(repo),
          pairingPollIntervalProvider.overrideWithValue(null),
          unreadCountProvider.overrideWith((ref) async => 0),
        ],
        child: MaterialApp.router(theme: lightTheme, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Parear'), findsNothing);
    expect(find.text('Início'), findsOneWidget);
    await tester.tap(find.text('Ir para o pareamento'));
    await tester.pump();
    expect(find.text('Parear').hitTestable(), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Parear').hitTestable(), findsOneWidget);

    await tester.tap(find.text('Acompanhar pedido'));
    await tester.pump();
    expect(find.text('Parear').hitTestable(), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Aguardando confirmação'), findsOneWidget);
    expect(find.text('Parear').hitTestable(), findsOneWidget);
  });
}
