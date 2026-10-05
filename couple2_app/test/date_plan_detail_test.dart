import 'package:couple2_app/app/session.dart';
import 'package:couple2_app/app/session_provider.dart';
import 'package:couple2_app/modules/date_plans/data/date_plans_repository.dart';
import 'package:couple2_app/modules/date_plans/domain/domain.dart';
import 'package:couple2_app/modules/date_plans/ui/pages/date_plan_detail/date_plan_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:couple2_app/modules/date_plans/data/date_plans_providers.dart';

class _Session extends SessionNotifier {
  _Session(this.userId);
  final String userId;

  @override
  Future<Session?> build() async {
    return Session(
      id: userId,
      email: '$userId@example.com',
      name: userId,
      isPaired: true,
      coupleId: 'couple-1',
    );
  }
}

class _Repo implements IDatePlansRepository {
  _Repo(this.plan);
  final DatePlan plan;

  @override
  Future<DatePlan> get(String id) async => plan;

  @override
  Future<DatePlan> accept(String id) => throw UnimplementedError();

  @override
  Future<DatePlan> cancel(String id, {String? note}) =>
      throw UnimplementedError();

  @override
  Future<DatePlan> counter(
    String id, {
    required DateTime scheduledAt,
    String? note,
  }) => throw UnimplementedError();

  @override
  Future<DatePlan> create({
    required String title,
    required DateTime scheduledAt,
    String? location,
    String? description,
    String? sourceListItemId,
  }) => throw UnimplementedError();

  @override
  Future<DatePlan> decline(String id, {String? note}) =>
      throw UnimplementedError();

  @override
  Future<DatePlan> done(String id) => throw UnimplementedError();

  @override
  Future<DatePlanPage> list({required String scope, String? cursor}) =>
      throw UnimplementedError();

  @override
  Future<DatePlan> update(
    String id, {
    String? title,
    DateTime? scheduledAt,
    String? location,
    String? description,
    String? sourceListItemId,
    bool clearLocation = false,
    bool clearDescription = false,
    bool clearSource = false,
  }) => throw UnimplementedError();
}

Future<void> _pump(WidgetTester tester, String userId) async {
  final when = DateTime(2026, 10, 9, 20);
  final plan = DatePlan(
    id: 'plan-1',
    coupleId: 'couple-1',
    proposerId: 'user-a',
    title: 'Japonês',
    scheduledAt: when,
    status: DatePlanStatus.proposed,
    createdById: 'user-a',
    createdAt: when,
    updatedAt: when,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWith(() => _Session(userId)),
        datePlansRepositoryProvider.overrideWithValue(_Repo(plan)),
      ],
      child: const MaterialApp(home: DatePlanDetailPage(id: 'plan-1')),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the partner sees accept, decline and counter', (tester) async {
    await _pump(tester, 'user-b');
    expect(find.text('Aceitar'), findsOneWidget);
    expect(find.text('Recusar'), findsOneWidget);
    expect(find.text('Sugerir outro horário'), findsOneWidget);
    expect(find.text('Editar'), findsNothing);
    expect(find.text('Cancelar'), findsNothing);
  });

  testWidgets('the proposer sees only edit and cancel', (tester) async {
    await _pump(tester, 'user-a');
    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('Aceitar'), findsNothing);
    expect(find.text('Recusar'), findsNothing);
    expect(find.text('Sugerir outro horário'), findsNothing);
  });
}
