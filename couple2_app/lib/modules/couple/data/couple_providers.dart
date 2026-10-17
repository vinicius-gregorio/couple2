import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../../app/provider_load.dart';
import '../../../app/session_provider.dart';
import '../../../core/core.dart';
import '../domain/domain.dart';
import 'couple_repository.dart';

final coupleRepositoryProvider = Provider<ICoupleRepository>((ref) {
  return CoupleRepository(httpClient: GetIt.I<ICPLHttpClient>());
});

final coupleDatesProvider =
    AsyncNotifierProvider<CoupleDatesNotifier, List<CoupleDate>>(
      CoupleDatesNotifier.new,
      retry: noProviderRetry,
    );

/// Dates for the open couple. [remember] publishes a save immediately.
/// [reload] re-reads the list. A failed read replaces the list with the error.
class CoupleDatesNotifier extends AsyncNotifier<List<CoupleDate>> {
  @override
  Future<List<CoupleDate>> build() async {
    final coupleId = await watchCoupleId(ref);
    if (coupleId == null) return const [];
    return loadOrTimeout(ref.watch(coupleRepositoryProvider).getDates());
  }

  void remember(CoupleDate date) {
    final current = state.value ?? const <CoupleDate>[];
    state = AsyncData([
      for (final item in current)
        if (item.id != date.id) item,
      date,
    ]);
  }

  Future<void> reload() async {
    try {
      final coupleId = ref.read(sessionProvider).asData?.value?.coupleId;
      if (coupleId == null) {
        state = const AsyncData([]);
        return;
      }
      final next = await loadOrTimeout(
        ref.read(coupleRepositoryProvider).getDates(),
      );
      state = AsyncData(next);
    } catch (error, stack) {
      state = AsyncError(error, stack);
    }
  }
}

final coupleProvider = FutureProvider<Couple?>((ref) async {
  final coupleId = await watchCoupleId(ref);
  if (coupleId == null) return null;
  final repo = ref.watch(coupleRepositoryProvider);
  try {
    return await loadOrTimeout(repo.getCouple());
  } on CPLHttpForbiddenException {
    return null;
  }
}, retry: noProviderRetry);
