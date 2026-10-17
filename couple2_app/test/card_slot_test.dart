import 'package:couple2_app/app/ui/home_failure_scope.dart';
import 'package:couple2_app/design_system/design_system.dart';
import 'package:couple2_app/modules/couple/domain/domain.dart';
import 'package:couple2_app/modules/couple/ui/widgets/days_together_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const slots = <String, double>{
    'days': homeDaysCardHeight,
    'mood': homeMoodCardHeight,
    'next-date': homeNextDateCardHeight,
    'question': homeQuestionCardHeight,
    'feed': homeFeedCardHeight,
    'list': listCardSlotHeight,
    'item': listItemSlotHeight,
  };

  testWidgets('loading and loaded share one height at both viewports', (
    tester,
  ) async {
    for (final viewport in const [Size(360, 640), Size(1280, 800)]) {
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final slot in slots.entries) {
        final heights = <double>[];
        for (final state in ['loading', 'loaded']) {
          final child = state == 'loading'
              ? (slot.value < 120
                    ? const SizedBox.expand()
                    : CardSkeleton(lines: 2, minHeight: slot.value))
              : slot.key == 'days'
              ? DaysTogetherCard(
                  couple: Couple(
                    id: 'c',
                    pairedAt: DateTime.utc(2024, 1, 1),
                    anniversaryDate: '2024-01-01',
                    timezone: 'America/Sao_Paulo',
                    daysTogether: 1020,
                    partner: const CouplePartner(id: 'b', name: 'Bruno'),
                    upcoming: const [],
                  ),
                  onOpenSettings: () {},
                  onOpenDates: () {},
                )
              : const SizedBox.expand();
          await tester.pumpWidget(
            MaterialApp(
              theme: lightTheme,
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topCenter,
                  child: StableSlot(height: slot.value, child: child),
                ),
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull, reason: '${slot.key} $state');
          heights.add(tester.getSize(find.byType(StableSlot)).height);
        }
        expect(heights.toSet(), {slot.value}, reason: slot.key);
      }

      await tester.pumpWidget(
        MaterialApp(
          theme: lightTheme,
          home: Scaffold(
            body: LoadErrorCard(
              message: 'Não foi possível carregar.',
              onRetry: _noop,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Tentar de novo'), findsOneWidget);
      expect(
        tester.getSize(find.byType(LoadErrorCard)).height,
        lessThan(homeDaysCardHeight),
      );
    }
  });
}

void _noop() {}
