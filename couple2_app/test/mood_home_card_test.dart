import 'package:couple2_app/app/session.dart';
import 'package:couple2_app/app/session_provider.dart';
import 'package:couple2_app/modules/mood/data/mood_providers.dart';
import 'package:couple2_app/modules/mood/domain/domain.dart';
import 'package:couple2_app/modules/mood/ui/widgets/mood_home_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Session extends SessionNotifier {
  @override
  Future<Session?> build() async {
    return const Session(
      id: 'ada',
      email: 'ada@example.com',
      name: 'Ada',
      isPaired: true,
      coupleId: 'couple-1',
      partnerName: 'Bob',
    );
  }
}

Future<void> _pump(WidgetTester tester, MoodCurrent current) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWith(_Session.new),
        currentMoodProvider.overrideWith((ref) async => current),
      ],
      child: const MaterialApp(home: Scaffold(body: MoodHomeCard())),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('a low partner mood asks for a caring nudge', (tester) async {
    final createdAt = DateTime.now().subtract(const Duration(hours: 2));
    await _pump(
      tester,
      MoodCurrent(
        me: MoodSnapshot(
          mood: MoodLevel.good,
          createdAt: createdAt,
          stale: false,
        ),
        partner: MoodSnapshot(
          mood: MoodLevel.low,
          createdAt: createdAt,
          stale: false,
          note: 'segredo',
        ),
      ),
    );

    expect(find.text('Como vocês estão'), findsOneWidget);
    expect(find.text('Mandar um carinho?'), findsOneWidget);
    expect(find.text('💗 Pensando em você'), findsOneWidget);
    expect(find.text('há 2 h'), findsWidgets);
    expect(find.text('segredo'), findsNothing);
    expect(find.text('Bob'), findsOneWidget);
  });

  testWidgets('a good partner mood stays quiet', (tester) async {
    await _pump(
      tester,
      MoodCurrent(
        partner: MoodSnapshot(
          mood: MoodLevel.good,
          createdAt: DateTime.now(),
          stale: false,
        ),
      ),
    );

    expect(find.text('Mandar um carinho?'), findsNothing);
    expect(find.text('💗 Pensando em você'), findsOneWidget);
    expect(find.text('Toque para dizer'), findsOneWidget);
  });

  testWidgets('a stale mood is faded and still shows the age', (tester) async {
    await _pump(
      tester,
      MoodCurrent(
        partner: MoodSnapshot(
          mood: MoodLevel.bad,
          createdAt: DateTime.now().subtract(const Duration(hours: 30)),
          stale: true,
        ),
      ),
    );

    expect(find.text('Mandar um carinho?'), findsOneWidget);
    expect(find.text('há 1 d'), findsOneWidget);
    final faded = tester.widget<Opacity>(
      find.ancestor(of: find.text('há 1 d'), matching: find.byType(Opacity)),
    );
    expect(faded.opacity, 0.45);
  });
}
