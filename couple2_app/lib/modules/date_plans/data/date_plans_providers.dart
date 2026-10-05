import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../../core/core.dart';
import '../domain/domain.dart';
import 'date_plans_repository.dart';

final datePlansRepositoryProvider = Provider<IDatePlansRepository>((ref) {
  return DatePlansRepository(httpClient: GetIt.I<ICPLHttpClient>());
});

/// The next date for the Home card: first upcoming row, or null.
final nextDateProvider = FutureProvider<DatePlan?>((ref) async {
  final page = await ref
      .watch(datePlansRepositoryProvider)
      .list(scope: 'upcoming');
  if (page.items.isEmpty) return null;
  return page.items.first;
});
