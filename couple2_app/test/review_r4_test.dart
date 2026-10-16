import 'package:couple2_app/app/session.dart';
import 'package:couple2_app/app/session_provider.dart';
import 'package:couple2_app/design_system/design_system.dart';
import 'package:couple2_app/modules/daily_question/data/daily_question_providers.dart';
import 'package:couple2_app/modules/daily_question/data/daily_question_repository.dart';
import 'package:couple2_app/modules/daily_question/domain/domain.dart';
import 'package:couple2_app/modules/daily_question/ui/pages/today/today_question_page.dart';
import 'package:couple2_app/modules/pairing/data/pairing_providers.dart';
import 'package:couple2_app/modules/pairing/data/pairing_repository.dart';
import 'package:couple2_app/modules/pairing/domain/domain.dart';
import 'package:couple2_app/modules/pairing/routing/routes.dart';
import 'package:couple2_app/modules/pairing/ui/pages/enter_code/enter_code_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('an incoming pairing request is named, an outgoing one keeps the code', () {
    expect(
      pairingRequestNotice(
        const PairingSnapshot(phase: PairingPhase.pending),
      ),
      contains('Seu par enviou um pedido'),
    );
    expect(
      pairingRequestNotice(
        const PairingSnapshot(
          phase: PairingPhase.pending,
          pendingCode: 'XYZ789',
        ),
      ),
      contains('XYZ789'),
    );
  });

  testWidgets('the empty inbox icon uses the brand color', (tester) async {
    _pinSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme,
        home: const EmptyView(message: 'Nenhuma lista ainda.'),
      ),
    );
    final icon = tester.widget<Icon>(find.byIcon(Icons.inbox_outlined));
    expect(icon.color, lightColorScheme.primary);
  });

  testWidgets('Editar on the daily question does not submit', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _Questions();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(_Session.new),
          dailyQuestionRepositoryProvider.overrideWithValue(repo),
          pairingPollIntervalProvider.overrideWithValue(null),
        ],
        child: const MaterialApp(home: TodayQuestionPage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Enviar'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('Editar'));
    await tester.pump();
    expect(repo.answers, 0);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Salvar'), findsOneWidget);
  });

  testWidgets('typing a partner code stays on enter when a request arrives', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: PairingRoutes.enter,
      routes: [
        GoRoute(
          path: PairingRoutes.hub,
          builder: (_, _) => const Scaffold(body: Text('hub-pairing')),
        ),
        GoRoute(
          path: PairingRoutes.enter,
          builder: (_, _) => const EnterCodePage(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(_Session.new),
          pairingRepositoryProvider.overrideWithValue(_Pairing()),
          pairingPollIntervalProvider.overrideWithValue(null),
        ],
        child: MaterialApp.router(theme: lightTheme, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    await tester.enterText(find.byKey(const Key('partner-code-field')), 'AB');
    await tester.pump();
    expect(find.text('hub-pairing'), findsNothing);
    expect(find.text('Código do par'), findsWidgets);
    expect(find.textContaining('Seu par enviou um pedido'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byKey(const Key('partner-code-field'))).controller?.text,
      'AB',
    );
  });
}

class _Session extends SessionNotifier {
  @override
  Future<Session?> build() async {
    return const Session(
      id: 'ada',
      email: 'ada@example.com',
      name: 'Ada',
      isPaired: false,
      pairingCode: 'ABC123',
    );
  }

  @override
  Future<void> refresh() async {}
}

class _Questions implements IDailyQuestionRepository {
  var answers = 0;

  @override
  Future<CoupleQuestion> getToday() async {
    return CoupleQuestion(
      id: 'q1',
      date: '2026-01-01',
      question: const QuestionPrompt(text: 'O que te fez sorrir?', category: 'DAILY'),
      partnerAnswered: false,
      answerable: true,
      myAnswer: QuestionAnswer(
        text: 'O café',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    );
  }

  @override
  Future<CoupleQuestion> answer(String coupleQuestionId, String text) async {
    answers++;
    return getToday();
  }

  @override
  Future<QuestionHistoryPageResult> history({String? cursor, int limit = 20}) {
    throw UnimplementedError();
  }
}

class _Pairing implements IPairingRepository {
  @override
  Future<PairingSnapshot> getStatus() async {
    return const PairingSnapshot(phase: PairingPhase.pending);
  }

  @override
  Future<PairResult> pair(String code) async {
    return const PairResult(phase: PairingPhase.pending, message: 'ok');
  }

  @override
  Future<void> cancelRequest() async {}

  @override
  Future<void> unpair() async {}

  @override
  Future<void> ensurePairingCode() async {}
}

void _pinSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
