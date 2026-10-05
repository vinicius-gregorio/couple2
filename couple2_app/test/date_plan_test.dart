import 'package:couple2_app/modules/date_plans/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

DatePlan _plan({
  required DatePlanStatus status,
  required String proposerId,
  DateTime? scheduledAt,
  String? sourceListItemId,
  DatePlanSourceItem? sourceListItem,
}) {
  final when = scheduledAt ?? DateTime(2026, 10, 9, 20);
  return DatePlan(
    id: 'plan-1',
    coupleId: 'couple-1',
    proposerId: proposerId,
    title: 'Japonês',
    scheduledAt: when,
    status: status,
    createdById: 'user-a',
    createdAt: when,
    updatedAt: when,
    sourceListItemId: sourceListItemId,
    sourceListItem: sourceListItem,
  );
}

void main() {
  test('the partner can accept and the proposer can only edit or cancel', () {
    final proposed = _plan(
      status: DatePlanStatus.proposed,
      proposerId: 'user-a',
    );

    expect(proposed.canAccept('user-b'), isTrue);
    expect(proposed.canDecline('user-b'), isTrue);
    expect(proposed.canCounter('user-b'), isTrue);
    expect(proposed.canEdit('user-b'), isFalse);
    expect(proposed.canCancel('user-b'), isFalse);

    expect(proposed.canAccept('user-a'), isFalse);
    expect(proposed.canEdit('user-a'), isTrue);
    expect(proposed.canCancel('user-a'), isTrue);
    expect(proposed.canDone('user-a'), isFalse);
  });

  test('after a counter only the new partner can accept', () {
    final countered = _plan(
      status: DatePlanStatus.proposed,
      proposerId: 'user-b',
    );
    expect(countered.canAccept('user-a'), isTrue);
    expect(countered.canAccept('user-b'), isFalse);
    expect(countered.canEdit('user-b'), isTrue);
  });

  test('either partner can cancel or finish an accepted date', () {
    final accepted = _plan(
      status: DatePlanStatus.accepted,
      proposerId: 'user-a',
    );
    expect(accepted.canCancel('user-a'), isTrue);
    expect(accepted.canCancel('user-b'), isTrue);
    expect(accepted.canDone('user-b'), isTrue);
    expect(accepted.canAccept('user-b'), isFalse);
    expect(accepted.canEdit('user-a'), isFalse);
  });

  test('a missing source item is reported as removed', () {
    final plan = _plan(
      status: DatePlanStatus.accepted,
      proposerId: 'user-a',
      sourceListItemId: 'item-1',
    );
    expect(plan.sourceRemoved, isTrue);
  });

  test('the home card uses the device clock', () {
    final plan = _plan(
      status: DatePlanStatus.accepted,
      proposerId: 'user-a',
      scheduledAt: DateTime(2026, 10, 9, 20),
    );
    expect(nextDateHeadline(plan), 'Próximo date: Sexta 20:00 — Japonês');
  });

  test('isoWithOffset keeps the same instant and includes an offset', () {
    final local = DateTime(2026, 10, 9, 20);
    final iso = isoWithOffset(local);
    expect(
      iso,
      matches(RegExp(r'^\d{4}-\d{2}-\d{2}T20:00:00(Z|[+-]\d{2}:\d{2})$')),
    );
    expect(DateTime.parse(iso).toUtc(), local.toUtc());
  });

  test('only movies and travel can plan a date from a list item', () {
    expect(listTypeSupportsDatePlan('MOVIES'), isTrue);
    expect(listTypeSupportsDatePlan('TRAVEL'), isTrue);
    expect(listTypeSupportsDatePlan('SHOPPING_CART'), isFalse);
    expect(listTypeSupportsDatePlan('MILESTONES'), isFalse);
  });
}
