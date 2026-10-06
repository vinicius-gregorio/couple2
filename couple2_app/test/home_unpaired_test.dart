import 'package:couple2_app/app/session.dart';
import 'package:couple2_app/app/session_provider.dart';
import 'package:couple2_app/app/ui/pages/home/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _UnpairedSession extends SessionNotifier {
  @override
  Future<Session?> build() async {
    return const Session(
      id: 'user-a',
      email: 'a@example.com',
      name: 'Ana',
      isPaired: false,
    );
  }
}

void main() {
  testWidgets('an unpaired home is the pairing gate, not an empty welcome', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(_UnpairedSession.new)],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Conectar com meu par'), findsOneWidget);
    expect(find.text('Ir para o pareamento'), findsOneWidget);
    expect(find.text('Our Lists'), findsNothing);
    expect(find.textContaining('Bem-vindo'), findsNothing);
  });
}
