import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/net/connectivity_report.dart';
import '../modules/couple/data/couple_providers.dart';
import '../modules/daily_question/data/daily_question_providers.dart';
import '../modules/date_plans/data/date_plans_providers.dart';
import '../modules/feed/data/feed_providers.dart';
import '../modules/mood/data/mood_providers.dart';
import 'connectivity_bind_stub.dart'
    if (dart.library.html) 'connectivity_bind_web.dart';
import 'read_cache.dart';
import 'session_provider.dart';

/// True while requests can reach the server.
///
/// One flag for the offline notice. It flips from request outcomes and from
/// the browser's online/offline events. Coming back online clears the notice
/// and reloads the data on screen.
class AppConnectivity extends Notifier<bool> {
  @override
  bool build() {
    connectivityReport = _apply;
    final stop = listenBrowserOnline(_apply);
    ref.onDispose(() {
      stop();
      if (identical(connectivityReport, _apply)) {
        connectivityReport = null;
      }
    });
    final pending = pendingConnectivity;
    if (pending != null) {
      pendingConnectivity = null;
      Future<void>.microtask(() {
        if (!ref.mounted) return;
        _apply(pending);
      });
    }
    return pending ?? true;
  }

  void _apply(bool online) {
    if (!ref.mounted || state == online) return;
    state = online;
    if (!online) return;
    ref.read(staleReadsProvider.notifier).clearAll();
    ref.read(sessionProvider.notifier).refresh();
    ref
      ..invalidate(coupleProvider)
      ..invalidate(currentMoodProvider)
      ..invalidate(nextDateProvider)
      ..invalidate(todayQuestionProvider)
      ..invalidate(feedPreviewProvider)
      ..invalidate(unreadCountProvider);
  }
}

final connectivityProvider = NotifierProvider<AppConnectivity, bool>(
  AppConnectivity.new,
);
