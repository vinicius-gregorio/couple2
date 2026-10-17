import 'dart:async';

import 'package:couple2_app/app/providers.dart';
import 'package:couple2_app/app/session.dart';
import 'package:couple2_app/design_system/design_system.dart';
import 'package:couple2_app/core/external/http_client/cpl_http_response.dart';
import 'package:couple2_app/core/external/http_client/exceptions/cpl_http_bad_request_exception.dart';
import 'package:couple2_app/modules/pairing/data/pairing_providers.dart';
import 'package:couple2_app/modules/pairing/data/pairing_repository.dart';
import 'package:couple2_app/modules/pairing/domain/domain.dart';
import 'package:couple2_app/modules/pairing/routing/routes.dart';
import 'package:couple2_app/modules/pairing/ui/pages/enter_code/enter_code_page.dart';
import 'package:couple2_app/modules/pairing/ui/pages/pairing_code/pairing_code_page.dart';
import 'package:couple2_app/modules/pairing/ui/pages/waiting/waiting_page.dart';
import 'package:couple2_app/modules/pairing/ui/widgets/pairing_scaffold.dart';
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
  int ensures = 0;
  Object? ensureError;
  Completer<void>? ensureGate;
  String? issuedCode;

  @override
  Future<void> cancelRequest() async {
    cancels++;
    status = const PairingSnapshot(
      phase: PairingPhase.unpaired,
      pairingCode: 'ABC123',
    );
  }

  @override
  Future<PairingSnapshot> getStatus() async {
    final code = status.pairingCode;
    if ((code == null || code.isEmpty) && issuedCode != null) {
      return PairingSnapshot(
        phase: status.phase,
        message: status.message,
        pendingCode: status.pendingCode,
        pairingCode: issuedCode,
        pairingCodeExpiresAt: status.pairingCodeExpiresAt,
        partner: status.partner,
      );
    }
    return status;
  }

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

  @override
  Future<void> ensurePairingCode() async {
    ensures++;
    final error = ensureError;
    if (error != null) throw error;
    final gate = ensureGate;
    if (gate != null) await gate.future;
    issuedCode ??= 'HHHHHH';
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

class _CodeSession extends SessionNotifier {
  static int refreshes = 0;

  @override
  Future<Session?> build() {
    return SynchronousFuture(
      const Session(
        id: 'user-a',
        email: 'a@example.com',
        name: 'Ana',
        isPaired: false,
      ),
    );
  }

  @override
  Future<void> refresh() async {
    refreshes++;
    state = const AsyncData(
      Session(
        id: 'user-a',
        email: 'a@example.com',
        name: 'Ana',
        isPaired: false,
        pairingCode: 'NEW123',
      ),
    );
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
    await tester.pump();
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
    await tester.pump();
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
    await tester.pump();
    await tester.tap(find.byKey(const Key('submit-partner-code')));
    await tester.pump();
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
    await tester.pump();
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
    expect(repo.cancels, 0);
    expect(find.text('Cancelar pedido?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-cancel-pairing')));
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

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(repo.unpairs, 0);

    await tester.tap(find.byKey(const Key('unpair-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-unpair')));
    await tester.pumpAndSettle();

    expect(repo.unpairs, 1);
    expect(find.text('hub-screen'), findsOneWidget);
  });

  testWidgets('enviar pedido stays disabled until the code is valid', (
    tester,
  ) async {
    final repo = _FakePairing(
      const PairingSnapshot(
        phase: PairingPhase.unpaired,
        pairingCode: 'ABC123',
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(() => _Session(_unpaired)),
          pairingRepositoryProvider.overrideWithValue(repo),
          pairingPollIntervalProvider.overrideWithValue(null),
        ],
        child: MaterialApp(theme: lightTheme, home: const EnterCodePage()),
      ),
    );
    await tester.pumpAndSettle();

    FilledButton submit() {
      return tester.widget<FilledButton>(
        find.descendant(
          of: find.byKey(const Key('submit-partner-code')),
          matching: find.byType(FilledButton),
        ),
      );
    }

    Color? fill() {
      return tester
          .widget<Material>(
            find
                .descendant(
                  of: find.byKey(const Key('submit-partner-code')),
                  matching: find.byType(Material),
                )
                .first,
          )
          .color;
    }

    expect(submit().onPressed, isNull);
    expect(fill(), lightColorScheme.surfaceContainerHighest);

    await tester.enterText(find.byKey(const Key('partner-code-field')), 'AB');
    await tester.pump();
    expect(submit().onPressed, isNull);
    expect(fill(), lightColorScheme.surfaceContainerHighest);

    await tester.tap(find.byKey(const Key('submit-partner-code')));
    await tester.pump();
    expect(repo.lastCode, isNull);

    await tester.enterText(
      find.byKey(const Key('partner-code-field')),
      'XYZ789',
    );
    await tester.pump();
    expect(submit().onPressed, isNotNull);
    expect(fill(), lightColorScheme.primary);
  });

  testWidgets('pairing refresh ignores a second tap while in flight', (
    tester,
  ) async {
    final gate = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [logoutActionProvider.overrideWithValue(() async {})],
        child: MaterialApp(
          theme: lightTheme,
          home: PairingScaffold(
            step: 1,
            onRefresh: () {
              calls++;
              return gate.future;
            },
            children: const [Text('código')],
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('pairing-refresh')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('pairing-refresh')));
    await tester.pump();
    expect(calls, 1);
    expect(find.byKey(const Key('pairingRefreshSpinner')), findsOneWidget);

    gate.complete();
    await tester.pump();
    expect(calls, 1);
  });

  testWidgets('missing pairing code generates one without signing out', (
    tester,
  ) async {
    _CodeSession.refreshes = 0;
    final gate = Completer<void>();
    final repo = _FakePairing(
      const PairingSnapshot(phase: PairingPhase.unpaired),
    );
    repo.ensureGate = gate;
    await _pumpPage(
      tester,
      home: const PairingCodePage(),
      repo: repo,
      session: _CodeSession.new,
    );

    expect(find.textContaining('Saia e entre de novo'), findsNothing);
    expect(find.text('Sem código ainda.'), findsOneWidget);
    expect(find.text('Gerar código'), findsOneWidget);

    await tester.tap(find.byKey(const Key('generate-pairing-code')));
    await tester.pump();
    expect(repo.ensures, 1);
    expect(find.byKey(LoadingButton.spinnerKey), findsOneWidget);

    await tester.tap(find.byKey(const Key('generate-pairing-code')));
    await tester.pump();
    expect(repo.ensures, 1);

    repo.status = const PairingSnapshot(
      phase: PairingPhase.unpaired,
      pairingCode: 'NEW123',
    );
    gate.complete();
    await tester.pumpAndSettle();

    expect(_CodeSession.refreshes, 1);
    expect(find.text('NEW123'), findsOneWidget);
    expect(find.text('Gerar código'), findsNothing);
  });

  testWidgets('generate pairing code shows an error when the request fails', (
    tester,
  ) async {
    final repo = _FakePairing(
      const PairingSnapshot(phase: PairingPhase.unpaired),
    );
    repo.ensureError = Exception('offline');
    await _pumpPage(
      tester,
      home: const PairingCodePage(),
      repo: repo,
      session: _CodeSession.new,
    );

    await tester.tap(find.byKey(const Key('generate-pairing-code')));
    await tester.pumpAndSettle();

    expect(repo.ensures, 1);
    expect(
      find.text('Não foi possível gerar o código. Tente de novo.'),
      findsOneWidget,
    );
    expect(find.byKey(LoadingButton.spinnerKey), findsNothing);
    expect(find.text('Gerar código'), findsOneWidget);
  });

  testWidgets('waiting shows the caller code without a second primary', (
    tester,
  ) async {
    final repo = _FakePairing(
      const PairingSnapshot(
        phase: PairingPhase.pending,
        pendingCode: 'MMMMMM',
        pairingCode: 'HHHHHH',
      ),
    );
    await _pumpPage(
      tester,
      home: const WaitingPage(),
      repo: repo,
      session: _CodeSession.new,
    );

    expect(find.text('HHHHHH'), findsOneWidget);
    expect(find.text('Sem código ainda.'), findsNothing);
    expect(find.text('Gerar código'), findsNothing);
    expect(
      find.text('Seu código aparece quando a tela atualizar.'),
      findsNothing,
    );
    expect(find.textContaining('Aceitar ou Recusar'), findsOneWidget);
    expect(repo.ensures, 0);
  });

  testWidgets('waiting loads the caller code when status and session omit it', (
    tester,
  ) async {
    final repo = _FakePairing(
      const PairingSnapshot(phase: PairingPhase.pending, pendingCode: 'MMMMMM'),
    );
    await _pumpPage(
      tester,
      home: const WaitingPage(),
      repo: repo,
      session: _CodeSession.new,
    );

    expect(find.text('HHHHHH'), findsOneWidget);
    expect(
      find.text('Seu código aparece quando a tela atualizar.'),
      findsNothing,
    );
    expect(find.text('Gerar código'), findsNothing);
    expect(repo.ensures, 1);
  });

  testWidgets('a declined request is named when the sender returns', (
    tester,
  ) async {
    final repo = _FakePairing(
      const PairingSnapshot(
        phase: PairingPhase.pending,
        pendingCode: 'MMMMMM',
        pairingCode: 'HHHHHH',
      ),
    );
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
    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(_CodeSession.new),
        pairingRepositoryProvider.overrideWithValue(repo),
        pairingPollIntervalProvider.overrideWithValue(null),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: lightTheme, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    container.read(pairingStatusProvider.notifier).state = const AsyncData(
      PairingSnapshot(phase: PairingPhase.unpaired, pairingCode: 'HHHHHH'),
    );
    await tester.pumpAndSettle();

    expect(find.text(declinedPairingMessage), findsOneWidget);
    expect(find.text('Aguardando confirmação'), findsNothing);
  });
}
