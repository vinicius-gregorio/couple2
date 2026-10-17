import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routing/pairing_redirect.dart';
import '../../../../app/routing/routes.dart';
import '../../../../app/session.dart';
import '../../../../app/session_provider.dart';
import '../../data/pairing_providers.dart';
import '../../domain/domain.dart';
import '../../routing/routes.dart';

/// Polls `GET /pairing/status` and leaves the pairing flow when the couple
/// becomes active.
class PairingPoller extends ConsumerStatefulWidget {
  const PairingPoller({
    super.key,
    required this.child,
    this.enabled = true,
    this.returnToHubWhenUnpaired = false,
  });

  final Widget child;
  final bool enabled;
  final bool returnToHubWhenUnpaired;

  @override
  ConsumerState<PairingPoller> createState() => _PairingPollerState();
}

class _PairingPollerState extends ConsumerState<PairingPoller>
    with WidgetsBindingObserver {
  Timer? _timer;
  Timer? _incoming;
  Duration? _statusInterval;
  Duration? _incomingInterval;
  var _leaving = false;
  var _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _arm());
  }

  @override
  void didUpdateWidget(PairingPoller oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) _arm();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _foreground) return;
    _foreground = foreground;
    _arm();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _arm();
  }

  bool get _onScreen {
    if (!mounted) return false;
    final route = ModalRoute.of(context);
    return route == null || route.isCurrent;
  }

  /// Typing a partner code must stay on the enter route.
  bool get _isEnterRoute {
    final router = GoRouter.maybeOf(context);
    if (router == null) return false;
    final state = router.state;
    final location = routeLocation(
      matchedLocation: state.matchedLocation,
      fragment: state.uri.fragment,
    );
    return location == PairingRoutes.enter ||
        location.startsWith('${PairingRoutes.enter}/');
  }

  void _stop() {
    _timer?.cancel();
    _incoming?.cancel();
    _timer = null;
    _incoming = null;
    _statusInterval = null;
    _incomingInterval = null;
  }

  /// Starts the timers once. A later [didChangeDependencies] with the same
  /// interval must not reset them, or the first tick never arrives.
  /// Incoming requests also load immediately so the card does not wait.
  void _arm() {
    if (!mounted || !widget.enabled || !_foreground || !_onScreen) {
      _stop();
      return;
    }
    final interval = ref.read(pairingPollIntervalProvider);
    if (interval == null || interval <= Duration.zero) {
      _stop();
      return;
    }
    if (_timer == null || _statusInterval != interval) {
      _timer?.cancel();
      _statusInterval = interval;
      _timer = Timer.periodic(interval, (_) => _poll());
    }
    final incoming = ref.read(incomingPairingPollIntervalProvider);
    if (incoming <= Duration.zero) {
      _incoming?.cancel();
      _incoming = null;
      _incomingInterval = null;
      return;
    }
    if (_incoming == null || _incomingInterval != incoming) {
      _incoming?.cancel();
      _incomingInterval = incoming;
      _incoming = Timer.periodic(incoming, (_) => _pollIncoming());
      unawaited(_pollIncoming());
    }
  }

  Future<void> _poll() async {
    if (!mounted || !_foreground || !_onScreen) {
      _arm();
      return;
    }
    await ref.read(pairingStatusProvider.notifier).poll();
  }

  Future<void> _pollIncoming() async {
    if (!mounted || !_foreground || !_onScreen) {
      _arm();
      return;
    }
    await ref.read(incomingPairingRequestsProvider.notifier).reload();
  }

  void _onPhase(PairingPhase? phase) {
    if (!mounted || _leaving || phase == null) return;
    if (phase == PairingPhase.paired) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _goHome());
      return;
    }
    if (widget.returnToHubWhenUnpaired &&
        phase == PairingPhase.unpaired &&
        !_isEnterRoute) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _leaving || _isEnterRoute) return;
        _leaving = true;
        context.go(PairingRoutes.hub);
      });
    }
  }

  Future<void> _goHome() async {
    if (_leaving || !mounted) return;
    final session = ref.read(sessionProvider).asData?.value;
    if (sessionNeedsPairing(session)) return;
    _leaving = true;
    context.go(APPRoutes.home);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(pairingStatusProvider, (previous, next) {
      _onPhase(next.asData?.value.phase);
    });
    return widget.child;
  }
}
