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
  const UnpairButton({super.key});

  @override
  ConsumerState<UnpairButton> createState() => _UnpairButtonState();
}

class _UnpairButtonState extends ConsumerState<UnpairButton> {
  var _busy = false;
  var _confirming = false;
  String? _error;

  Future<void> _confirm() async {
    if (_busy || _confirming) return;
    _confirming = true;
    setState(() => _error = null);
    final accepted = await confirmDestructive(
      context,
      title: 'Desfazer o par?',
      message:
          'Os dois deixam de estar pareados. As listas deste casal ficam inacessíveis para os dois — não há arquivo. Um novo pareamento cria um casal novo.',
      confirmLabel: 'Desfazer',
      confirmKey: const Key('confirm-unpair'),
    );
    if (!mounted) return;
    if (accepted != true) {
      setState(() => _confirming = false);
      return;
    }

    setState(() {
      _confirming = false;
      _busy = true;
      _error = null;
    });
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
      if (mounted) setState(() => _busy = false);
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
          loading: _busy,
          onPressed: _busy || _confirming
              ? null
              : () {
                  _confirm();
                },
          child: Text(_busy ? 'Desfazendo...' : 'Desfazer o par'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
        ],
      ],
    );
  }
}
