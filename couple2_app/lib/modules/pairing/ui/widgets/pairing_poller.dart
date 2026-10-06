import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

class _PairingPollerState extends ConsumerState<PairingPoller> {
  Timer? _timer;
  var _leaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _arm());
  }

  @override
  void didUpdateWidget(PairingPoller oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) _arm();
  }

  void _arm() {
    _timer?.cancel();
    _timer = null;
    if (!mounted || !widget.enabled) return;
    final interval = ref.read(pairingPollIntervalProvider);
    if (interval == null || interval <= Duration.zero) return;
    _timer = Timer.periodic(interval, (_) => _poll());
  }

  Future<void> _poll() async {
    await ref.read(pairingStatusProvider.notifier).poll();
  }

  void _onPhase(PairingPhase? phase) {
    if (!mounted || _leaving || phase == null) return;
    if (phase == PairingPhase.paired) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _goHome());
      return;
    }
    if (widget.returnToHubWhenUnpaired && phase == PairingPhase.unpaired) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _leaving) return;
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
    _timer?.cancel();
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
