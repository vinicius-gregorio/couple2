import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/pairing_providers.dart';
import '../../domain/domain.dart';

/// Incoming pairing requests for the signed-in user. Aceitar is the only
/// filled action. Recusar asks first and does not spin during that dialog.
class IncomingPairingNotice extends ConsumerWidget {
  const IncomingPairingNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(incomingPairingRequestsProvider);
    final requests = async.asData?.value ?? const <IncomingPairingRequest>[];
    if (async.hasError && requests.isEmpty) {
      return AppText(
        pairingErrorMessage(async.error!, action: PairingAction.status),
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    }
    if (requests.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final request in requests) ...[
          _IncomingCard(request: request),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _IncomingCard extends ConsumerStatefulWidget {
  const _IncomingCard({required this.request});

  final IncomingPairingRequest request;

  @override
  ConsumerState<_IncomingCard> createState() => _IncomingCardState();
}

class _IncomingCardState extends ConsumerState<_IncomingCard> {
  String? _busy;
  var _confirming = false;
  String? _error;
  var _held = false;
  PairingControlsLock? _lock;

  bool get _locked => _busy != null || _confirming;

  void _hold(bool on) {
    if (_held == on) return;
    _held = on;
    final existing = _lock;
    final PairingControlsLock lock = existing ??
        ref.read(pairingControlsLockedProvider.notifier);
    _lock = lock;
    if (on) {
      lock.acquire();
    } else {
      lock.release();
    }
  }

  @override
  void dispose() {
    if (_held) {
      _held = false;
      _lock?.release();
    }
    super.dispose();
  }

  Future<void> _accept() async {
    if (_locked) return;
    setState(() {
      _busy = 'accept';
      _error = null;
    });
    _hold(true);
    try {
      await ref
          .read(incomingPairingRequestsProvider.notifier)
          .accept(widget.request.id);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = pairingErrorMessage(error, action: PairingAction.accept);
      });
    } finally {
      _hold(false);
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _decline() async {
    if (_locked) return;
    setState(() {
      _confirming = true;
      _error = null;
    });
    _hold(true);
    final accepted = await confirmDestructive(
      context,
      title: 'Recusar pedido?',
      message:
          'O pedido some para você. A outra pessoa pode enviar outro depois.',
      confirmLabel: 'Recusar',
      confirmKey: const Key('confirm-decline-pairing'),
    );
    if (!mounted) return;
    if (!accepted) {
      _hold(false);
      setState(() => _confirming = false);
      return;
    }
    setState(() {
      _confirming = false;
      _busy = 'decline';
    });
    try {
      await ref
          .read(incomingPairingRequestsProvider.notifier)
          .decline(widget.request.id);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = pairingErrorMessage(error, action: PairingAction.decline);
      });
    } finally {
      _hold(false);
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.request.requesterName;
    final who = name == null || name.isEmpty
        ? 'Alguém quer parear com você.'
        : '$name quer parear com você.';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppText(
              'Pedido recebido',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            AppText(who),
            const SizedBox(height: 12),
            MutationErrorBanner(message: _error),
            LoadingButton(
              key: const Key('accept-pairing-request'),
              loading: _busy == 'accept',
              onPressed: _locked
                  ? null
                  : () {
                      _accept();
                    },
              child: Text(_busy == 'accept' ? 'Aceitando…' : 'Aceitar'),
            ),
            const SizedBox(height: 8),
            LoadingButton(
              key: const Key('decline-pairing-request'),
              variant: LoadingButtonVariant.outlined,
              loading: _busy == 'decline',
              onPressed: _locked
                  ? null
                  : () {
                      _decline();
                    },
              child: Text(_busy == 'decline' ? 'Recusando…' : 'Recusar'),
            ),
          ],
        ),
      ),
    );
  }
}
