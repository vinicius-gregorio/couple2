import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../../app/provider_load.dart';
import '../../../app/session_provider.dart';
import '../../../core/core.dart';
import '../domain/domain.dart';
import 'date_plans_repository.dart';

final datePlansRepositoryProvider = Provider<IDatePlansRepository>((ref) {
  return DatePlansRepository(httpClient: GetIt.I<ICPLHttpClient>());
});

/// Bumped after a date plan is created or its status changes.
/// The list page refetches when this changes, including while it sits under
/// a pushed detail or form route.
class DatePlansChanged extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final datePlansChangedProvider = NotifierProvider<DatePlansChanged, int>(
  DatePlansChanged.new,
);

/// The next date for the Home card: first upcoming row, or null.
final nextDateProvider = FutureProvider<DatePlan?>((ref) async {
  final coupleId = await watchCoupleId(ref);
  if (coupleId == null) return null;
  final repo = ref.watch(datePlansRepositoryProvider);
  try {
    return await loadOrTimeout(() async {
      final page = await repo.list(scope: 'upcoming');
      if (page.items.isEmpty) return null;
      return page.items.first;
    }());
  } on CPLHttpForbiddenException {
    return null;
  }
}, retry: noProviderRetry);
