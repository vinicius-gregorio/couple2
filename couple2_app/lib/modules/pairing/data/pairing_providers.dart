import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../../app/session_provider.dart';
import '../../../core/core.dart';
import '../../couple/data/couple_providers.dart';
import '../domain/domain.dart';
import 'pairing_repository.dart';

final pairingRepositoryProvider = Provider<IPairingRepository>((ref) {
  return PairingRepository(httpClient: GetIt.I<ICPLHttpClient>());
});

/// Null disables polling (tests). The waiting screen and a pending hub poll.
final pairingPollIntervalProvider = Provider<Duration?>((ref) {
  return const Duration(seconds: 4);
});

/// Received-request refresh while a pairing screen is visible.
/// The poller skips it when [pairingPollIntervalProvider] is null.
/// Shorter than the status poll so an incoming card shows up without a manual refresh.
final incomingPairingPollIntervalProvider = Provider<Duration>((ref) {
  return const Duration(seconds: 4);
});

/// How many pairing controls are mid-confirm or mid-request.
/// The scaffold and the code buttons stay disabled while this is above zero.
class PairingControlsLock extends Notifier<int> {
  @override
  int build() => 0;

  void acquire() => state++;

  void release() {
    if (state > 0) state--;
  }
}

final pairingControlsLockedProvider =
    NotifierProvider<PairingControlsLock, int>(PairingControlsLock.new);

/// Set when a sent request disappears because the other person declined.
class PairingDeclineMessage extends Notifier<String?> {
  @override
  String? build() => null;

  void show(String message) => state = message;

  void clear() => state = null;
}

final pairingDeclineMessageProvider =
    NotifierProvider<PairingDeclineMessage, String?>(PairingDeclineMessage.new);

final incomingPairingRequestsProvider =
    AsyncNotifierProvider<
      IncomingPairingRequestsNotifier,
      List<IncomingPairingRequest>
    >(IncomingPairingRequestsNotifier.new);

class IncomingPairingRequestsNotifier
    extends AsyncNotifier<List<IncomingPairingRequest>> {
  @override
  Future<List<IncomingPairingRequest>> build() {
    return ref.read(pairingRepositoryProvider).receivedRequests();
  }

  Future<void> reload() async {
    state = await AsyncValue.guard(
      () => ref.read(pairingRepositoryProvider).receivedRequests(),
    );
  }

  /// Accepts one request. A failure leaves the previous list in place.
  Future<void> accept(String id) async {
    final result = await ref.read(pairingRepositoryProvider).acceptRequest(id);
    if (result.phase == PairingPhase.paired) {
      try {
        await ref
            .read(pairingStatusProvider.notifier)
            .refreshSessionAfterPairing();
      } catch (_) {
        // The pair already committed. The next refresh picks up the session.
      }
      ref.read(pairingStatusProvider.notifier).state = AsyncData(
        PairingSnapshot(
          phase: PairingPhase.paired,
          message: result.message,
          partner: result.partner,
        ),
      );
    }
    await reload();
  }

  /// Declines one request. A failure leaves the previous list in place.
  Future<void> decline(String id) async {
    await ref.read(pairingRepositoryProvider).declineRequest(id);
    await reload();
  }
}

final pairingStatusProvider =
    AsyncNotifierProvider<PairingStatusNotifier, PairingSnapshot>(
      PairingStatusNotifier.new,
    );

class PairingStatusNotifier extends AsyncNotifier<PairingSnapshot> {
  String? _heldCode;
  DateTime? _heldExpires;
  var _ensuring = false;

  @override
  Future<PairingSnapshot> build() async {
    final snapshot = await ref.read(pairingRepositoryProvider).getStatus();
    return _retain(snapshot);
  }

  Future<void> reload() async {
    state = await AsyncValue.guard(() async {
      final snapshot = await ref.read(pairingRepositoryProvider).getStatus();
      return _retain(snapshot);
    });
  }

  /// One poll tick. Keeps the previous snapshot when the request fails,
  /// and keeps a code the server omits on a later tick.
  Future<PairingPhase?> poll() async {
    try {
      final snapshot = _retain(
        await ref.read(pairingRepositoryProvider).getStatus(),
      );
      if (snapshot.phase == PairingPhase.paired) {
        await refreshSessionAfterPairing();
      }
      // A new instance so a successful poll notifies even when the fields
      // match the previous snapshot. The waiting page clears its error then.
      state = AsyncData(
        PairingSnapshot(
          phase: snapshot.phase,
          message: snapshot.message,
          pairingCode: snapshot.pairingCode,
          pairingCodeExpiresAt: snapshot.pairingCodeExpiresAt,
          pendingCode: snapshot.pendingCode,
          partner: snapshot.partner,
        ),
      );
      return snapshot.phase;
    } catch (_) {
      return state.asData?.value.phase;
    }
  }

  /// Loads the caller's own code when the snapshot and the session lack one.
  /// A later poll cannot drop a code this already found.
  Future<void> ensureShownCode() async {
    final current = state.asData?.value;
    if (current?.phase == PairingPhase.paired) return;
    if (_visibleCode(current) != null) return;
    if (_ensuring) return;
    _ensuring = true;
    try {
      var snapshot = _retain(
        await ref.read(pairingRepositoryProvider).getStatus(),
      );
      if (_visibleCode(snapshot) == null) {
        await ref.read(pairingRepositoryProvider).ensurePairingCode();
        snapshot = _retain(
          await ref.read(pairingRepositoryProvider).getStatus(),
        );
      }
      if (_visibleCode(snapshot) == null) {
        await ref.read(sessionProvider.notifier).refresh();
        final session = ref.read(sessionProvider).asData?.value;
        final sessionCode = session?.pairingCode;
        if (sessionCode != null && sessionCode.isNotEmpty) {
          _heldCode = sessionCode;
          _heldExpires = session?.pairingCodeExpiresAt ?? _heldExpires;
          snapshot = _retain(snapshot);
        }
      }
      if (snapshot.phase != PairingPhase.paired) {
        state = AsyncData(snapshot);
      }
    } finally {
      _ensuring = false;
    }
  }

  String? _visibleCode(PairingSnapshot? snapshot) {
    final session = ref.read(sessionProvider).asData?.value;
    return shownPairingCode(
      status: snapshot,
      sessionCode: session?.pairingCode,
      sessionExpiresAt: session?.pairingCodeExpiresAt,
    ).code;
  }

  PairingSnapshot _retain(PairingSnapshot snapshot) {
    final code = snapshot.pairingCode;
    if (code != null && code.isNotEmpty) {
      _heldCode = code;
      _heldExpires = snapshot.pairingCodeExpiresAt ?? _heldExpires;
      return snapshot;
    }
    if (snapshot.phase == PairingPhase.paired || _heldCode == null) {
      return snapshot;
    }
    return PairingSnapshot(
      phase: snapshot.phase,
      message: snapshot.message,
      pendingCode: snapshot.pendingCode,
      pairingCode: _heldCode,
      pairingCodeExpiresAt: _heldExpires,
      partner: snapshot.partner,
    );
  }

  /// One `POST /pairing/pair`. A pending result does not reload status or the
  /// session. A paired result waits for `GET /auth/me` so Home has `coupleId`.
  /// Couple data reloads when Home watches [coupleProvider].
  Future<PairResult> submitCode(String raw) async {
    final code = normalizePairingCode(raw);
    final result = await ref.read(pairingRepositoryProvider).pair(code);
    if (result.phase == PairingPhase.paired) {
      await ref.read(sessionProvider.notifier).refresh();
      state = AsyncData(
        PairingSnapshot(
          phase: PairingPhase.paired,
          message: result.message,
          partner: result.partner,
        ),
      );
    } else {
      final previous = state.asData?.value;
      final session = ref.read(sessionProvider).asData?.value;
      state = AsyncData(
        _retain(
          PairingSnapshot(
            phase: PairingPhase.pending,
            message: result.message,
            pendingCode: code,
            pairingCode: previous?.pairingCode ?? session?.pairingCode,
            pairingCodeExpiresAt:
                previous?.pairingCodeExpiresAt ?? session?.pairingCodeExpiresAt,
          ),
        ),
      );
    }
    return result;
  }

  Future<void> cancelRequest() async {
    await ref.read(pairingRepositoryProvider).cancelRequest();
    await reload();
  }

  /// `GET /auth/me` is what puts `coupleId` on the session. Pairing responses
  /// only carry `partner`.
  Future<void> refreshSessionAfterPairing() async {
    await ref.read(sessionProvider.notifier).refresh();
    ref.invalidate(coupleProvider);
  }

  Future<void> unpair() async {
    await ref.read(pairingRepositoryProvider).unpair();
    await ref.read(sessionProvider.notifier).refresh();
    ref.invalidate(coupleProvider);
    ref.invalidateSelf();
  }
}
