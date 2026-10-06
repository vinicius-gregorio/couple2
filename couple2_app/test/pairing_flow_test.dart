import 'package:couple2_app/app/session.dart';
import 'package:couple2_app/app/session_provider.dart';
import 'package:couple2_app/core/external/http_client/cpl_http_response.dart';
import 'package:couple2_app/core/external/http_client/exceptions/cpl_http_bad_request_exception.dart';
import 'package:couple2_app/modules/pairing/data/pairing_providers.dart';
import 'package:couple2_app/modules/pairing/data/pairing_repository.dart';
import 'package:couple2_app/modules/pairing/domain/domain.dart';
import 'package:couple2_app/modules/pairing/routing/routes.dart';
import 'package:couple2_app/modules/pairing/ui/pages/enter_code/enter_code_page.dart';
import 'package:couple2_app/modules/pairing/ui/pages/pairing_code/pairing_code_page.dart';
import 'package:couple2_app/modules/pairing/ui/pages/waiting/waiting_page.dart';
import 'package:couple2_app/modules/pairing/ui/widgets/unpair_button.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _unpaired = Session(
  id: 'user-a',
  email: 'a@example.com',
  name: 'Ana',
  isPaired: false,
  pairingCode: 'ABC123',
  pairingCodeExpiresAt: null,
);

const _paired = Session(
  id: 'user-a',
  email: 'a@example.com',
  name: 'Ana',
  isPaired: true,
  coupleId: 'couple-1',
  partnerId: 'user-b',
  partnerName: 'Bruno',
);

class _Session extends SessionNotifier {
  _Session(this.current);
  Session? current;

  @override
  Future<Session?> build() => SynchronousFuture(current);

  @override
  Future<void> refresh() async {}
}

class _PairingSession extends SessionNotifier {
  @override
  Future<Session?> build() => SynchronousFuture(_unpaired);

  @override
  Future<void> refresh() async {
    state = const AsyncData(_paired);
  }
}

class _UnpairSession extends SessionNotifier {
  @override
  Future<Session?> build() => SynchronousFuture(_paired);

  @override
  Future<void> refresh() async {
    state = const AsyncData(_unpaired);
  }
}

class _FakePairing implements IPairingRepository {
  _FakePairing(this.status);

  PairingSnapshot status;
  Object? pairError;
  PairResult pairResult = const PairResult(
    phase: PairingPhase.pending,
    message:
        'Pairing request sent. Waiting for your partner to enter your code.',
  );
  String? lastCode;
  int cancels = 0;
  int unpairs = 0;

  @override
  Future<void> cancelRequest() async {
    cancels++;
    status = const PairingSnapshot(
      phase: PairingPhase.unpaired,
      pairingCode: 'ABC123',
    );
  }

  @override
  Future<PairingSnapshot> getStatus() async => status;

  @override
  Future<PairResult> pair(String code) async {
    lastCode = code;
    final error = pairError;
    if (error != null) throw error;
    return pairResult;
  }

  @override
  Future<void> unpair() async {
    unpairs++;
  }
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required Widget home,
  required _FakePairing repo,
  required SessionNotifier Function() session,
  GoRouter? router,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWith(session),
        pairingRepositoryProvider.overrideWithValue(repo),
        pairingPollIntervalProvider.overrideWithValue(null),
      ],
      child: router == null
          ? MaterialApp(home: home)
          : MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('hub shows the 6-char code, expiry, copy and share', (
    tester,
  ) async {
    final repo = _FakePairing(
      PairingSnapshot(
        phase: PairingPhase.unpaired,
        pairingCode: 'ABC123',
        pairingCodeExpiresAt: DateTime(2026, 11, 6, 15),
      ),
    );
    await _pumpPage(
      tester,
      home: const PairingCodePage(),
      repo: repo,
      session: () => _Session(_unpaired),
    );

    expect(find.text('ABC123'), findsOneWidget);
    expect(find.text('Válido até 06/11/2026 às 15:00'), findsOneWidget);
    expect(find.text('Copiar'), findsOneWidget);
    expect(find.text('Compartilhar'), findsOneWidget);
    expect(find.text('Digitar o código do meu par'), findsOneWidget);

    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<Object?, Object?>;
          clipboardText = args['text'] as String?;
        }
        if (call.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': clipboardText};
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await tester.tap(find.byKey(const Key('copy-pairing-code')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Código copiado'), findsOneWidget);
    expect(clipboardText, 'ABC123');
  });

  testWidgets('submitting a partner code sends the handshake and waits', (
    tester,
  ) async {
    final repo = _FakePairing(
      const PairingSnapshot(
        phase: PairingPhase.unpaired,
        pairingCode: 'ABC123',
      ),
    );
    final router = GoRouter(
      initialLocation: PairingRoutes.enter,
      routes: [
        GoRoute(
          path: PairingRoutes.hub,
          builder: (_, __) => const PairingCodePage(),
        ),
        GoRoute(
          path: PairingRoutes.enter,
          builder: (_, __) => const EnterCodePage(),
        ),
        GoRoute(
          path: PairingRoutes.waiting,
          builder: (_, __) => const WaitingPage(),
        ),
        GoRoute(path: '/', builder: (_, __) => const Text('home-screen')),
      ],
    );
    await _pumpPage(
      tester,
      home: const EnterCodePage(),
      repo: repo,
      session: () => _Session(_unpaired),
      router: router,
    );

    await tester.enterText(
      find.byKey(const Key('partner-code-field')),
      'xyz789',
    );
    await tester.tap(find.byKey(const Key('submit-partner-code')));
    await tester.pumpAndSettle();

    expect(repo.lastCode, 'XYZ789');
    expect(find.text('Aguardando confirmação'), findsOneWidget);
    expect(find.textContaining('XYZ789'), findsWidgets);
    expect(find.text('Cancelar pedido'), findsOneWidget);
  });

  testWidgets('own code and an expired code stay on the form in PT-BR', (
    tester,
  ) async {
    final repo = _FakePairing(
      const PairingSnapshot(
        phase: PairingPhase.unpaired,
        pairingCode: 'ABC123',
      ),
    );
    await _pumpPage(
      tester,
      home: const EnterCodePage(),
      repo: repo,
      session: () => _Session(_unpaired),
    );

    await tester.enterText(
      find.byKey(const Key('partner-code-field')),
      'ABC123',
    );
    await tester.tap(find.byKey(const Key('submit-partner-code')));
    await tester.pump();
    expect(
      find.text('Você não pode usar o seu próprio código.'),
      findsOneWidget,
    );
    expect(repo.lastCode, isNull);

    repo.pairError = CPLHttpBadRequestException(
      response: CPLHttpResponse(
        data: {'message': 'This pairing code has expired'},
        statusCode: 400,
        statusMessage: 'Bad Request',
        headers: null,
      ),
    );
    await tester.enterText(
      find.byKey(const Key('partner-code-field')),
      'XYZ789',
    );
    await tester.tap(find.byKey(const Key('submit-partner-code')));
    await tester.pump();
    expect(
      find.text('Esse código expirou. Peça um código novo.'),
      findsOneWidget,
    );
  });

  testWidgets('the second handshake refreshes the session and opens Home', (
    tester,
  ) async {
    final repo =
        _FakePairing(
            const PairingSnapshot(
              phase: PairingPhase.unpaired,
              pairingCode: 'ABC123',
            ),
          )
          ..pairResult = const PairResult(
            phase: PairingPhase.paired,
            message: 'Successfully paired with your partner!',
            partner: PairingPartner(id: 'user-b', name: 'Bruno'),
          );
    final router = GoRouter(
      initialLocation: PairingRoutes.enter,
      routes: [
        GoRoute(
          path: PairingRoutes.enter,
          builder: (_, __) => const EnterCodePage(),
        ),
        GoRoute(path: '/', builder: (_, __) => const Text('home-screen')),
      ],
    );
    await _pumpPage(
      tester,
      home: const EnterCodePage(),
      repo: repo,
      session: _PairingSession.new,
      router: router,
    );

    await tester.enterText(
      find.byKey(const Key('partner-code-field')),
      'XYZ789',
    );
    await tester.tap(find.byKey(const Key('submit-partner-code')));
    await tester.pumpAndSettle();

    expect(repo.lastCode, 'XYZ789');
    expect(find.text('home-screen'), findsOneWidget);
  });

  testWidgets('cancel deletes the pending request and returns to the code', (
    tester,
  ) async {
    final repo = _FakePairing(
      const PairingSnapshot(phase: PairingPhase.pending, pendingCode: 'XYZ789'),
    );
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(
      initialLocation: PairingRoutes.waiting,
      routes: [
        GoRoute(
          path: PairingRoutes.hub,
          builder: (_, __) => const PairingCodePage(),
        ),
        GoRoute(
          path: PairingRoutes.waiting,
          builder: (_, __) => const WaitingPage(),
        ),
      ],
    );
    await _pumpPage(
      tester,
      home: const WaitingPage(),
      repo: repo,
      session: () => _Session(_unpaired),
      router: router,
    );

    expect(find.text('Aguardando confirmação'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cancel-pairing-request')));
    await tester.pumpAndSettle();

    expect(repo.cancels, 1);
    expect(find.text('Mostre o seu código'), findsOneWidget);
    expect(find.text('Aguardando confirmação'), findsNothing);
  });

  testWidgets('unpair confirms, calls DELETE and opens pairing', (
    tester,
  ) async {
    final repo = _FakePairing(
      const PairingSnapshot(
        phase: PairingPhase.paired,
        partner: PairingPartner(id: 'user-b', name: 'Bruno'),
      ),
    );
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (_, __) => const Scaffold(body: UnpairButton()),
        ),
        GoRoute(
          path: PairingRoutes.hub,
          builder: (_, __) => const Text('hub-screen'),
        ),
      ],
    );
    await _pumpPage(
      tester,
      home: const UnpairButton(),
      repo: repo,
      session: _UnpairSession.new,
      router: router,
    );

    await tester.tap(find.byKey(const Key('unpair-button')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('listas deste casal ficam inacessíveis'),
      findsOneWidget,
    );

    await tester.tap(find.text('Manter o par'));
    await tester.pumpAndSettle();
    expect(repo.unpairs, 0);

    await tester.tap(find.byKey(const Key('unpair-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-unpair')));
    await tester.pumpAndSettle();

    expect(repo.unpairs, 1);
    expect(find.text('hub-screen'), findsOneWidget);
  });
}
