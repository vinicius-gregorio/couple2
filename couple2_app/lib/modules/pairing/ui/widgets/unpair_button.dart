import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/session.dart';
import '../../../../app/session_provider.dart';
import '../../data/pairing_providers.dart';
import '../../domain/domain.dart';
import '../../routing/routes.dart';

class UnpairButton extends ConsumerStatefulWidget {
  const UnpairButton({super.key, this.enabled = true, this.onBusyChanged});

  final bool enabled;
  final ValueChanged<bool>? onBusyChanged;

  @override
  ConsumerState<UnpairButton> createState() => _UnpairButtonState();
}

class _UnpairButtonState extends ConsumerState<UnpairButton> {
  var _busy = false;
  var _confirming = false;
  String? _error;

  void _setBusy(bool confirming, bool busy) {
    final was = _busy || _confirming;
    _confirming = confirming;
    _busy = busy;
    final now = _busy || _confirming;
    if (was != now) widget.onBusyChanged?.call(now);
    if (mounted) setState(() {});
  }

  Future<void> _confirm() async {
    if (_busy || _confirming || !widget.enabled) return;
    _setBusy(true, false);
    setState(() => _error = null);
    final accepted = await confirmDestructive(
      context,
      title: 'Desfazer o par?',
      message:
          'Os dois deixam de estar pareados. As listas deste casal ficam inacessíveis para os dois — não há arquivo. Um novo pareamento cria um casal novo.',
      confirmLabel: 'Desfazer',
      confirmKey: const Key('confirm-unpair'),
      danger: true,
    );
    if (!mounted) return;
    if (accepted != true) {
      _error = null;
      _setBusy(false, false);
      return;
    }

    _error = null;
    _setBusy(false, true);
    try {
      await ref.read(pairingStatusProvider.notifier).unpair();
      if (!mounted) return;
      final session = ref.read(sessionProvider).asData?.value;
      if (!sessionNeedsPairing(session)) {
        setState(() {
          _error =
              'O par foi desfeito, mas a sessão não atualizou. Saia e entre de novo.';
        });
        return;
      }
      context.go(PairingRoutes.hub);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = pairingErrorMessage(error, action: PairingAction.unpair);
      });
    } finally {
      if (mounted) _setBusy(false, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LoadingButton(
          key: const Key('unpair-button'),
          variant: LoadingButtonVariant.outlined,
          foregroundColor: theme.colorScheme.error,
          loading: _busy,
          onPressed: _busy || _confirming || !widget.enabled
              ? null
              : () {
                  _confirm();
                },
          child: Text(_busy ? 'Desfazendo…' : 'Desfazer o par'),
        ),
        MutationErrorBanner(message: _error),
      ],
    );
  }
}
