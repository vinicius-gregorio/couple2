import 'package:couple2_app/modules/date_plans/data/date_plans_providers.dart';
import 'package:couple2_app/modules/date_plans/domain/domain.dart';
import 'package:couple2_app/modules/date_plans/ui/widgets/next_date_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

DatePlan _plan() {
  final when = DateTime(2026, 10, 9, 20);
  return DatePlan(
    id: 'plan-1',
    coupleId: 'couple-1',
    proposerId: 'user-a',
    title: 'Japonês',
    scheduledAt: when,
    status: DatePlanStatus.accepted,
    createdById: 'user-a',
    createdAt: when,
    updatedAt: when,
  );
}

Future<void> _pump(WidgetTester tester, DatePlan? plan) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [nextDateProvider.overrideWith((ref) async => plan)],
      child: const MaterialApp(home: Scaffold(body: NextDateCard())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the next date in device time', (tester) async {
    await _pump(tester, _plan());
    expect(find.text('Próximo date: Sexta 20:00 — Japonês'), findsOneWidget);
    expect(find.text('Horário do aparelho'), findsOneWidget);
    expect(find.text('Planejar um date'), findsNothing);
  });

  testWidgets('offers to plan a date when nothing is upcoming', (tester) async {
    await _pump(tester, null);
    expect(find.text('Planejar um date'), findsOneWidget);
    expect(find.textContaining('Próximo date:'), findsNothing);
  });
}
