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
  String? _error;

  Future<void> _confirm() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Desfazer o par?'),
          content: const Text(
            'Os dois deixam de estar pareados. As listas deste casal ficam inacessíveis para os dois — não há arquivo. Um novo pareamento cria um casal novo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Manter o par'),
            ),
            TextButton(
              key: const Key('confirm-unpair'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Desfazer'),
            ),
          ],
        );
      },
    );
    if (accepted != true || !mounted) return;

    setState(() {
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
        OutlinedButton(
          key: const Key('unpair-button'),
          onPressed: _busy ? null : _confirm,
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.error,
          ),
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
