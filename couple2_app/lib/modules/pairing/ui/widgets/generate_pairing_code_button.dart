import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/session_provider.dart';
import '../../data/pairing_providers.dart';
import '../../domain/domain.dart';

/// Asks `POST /pairing/code` for a code, then reloads the session so the
/// card can show it. Login is the other place the server creates a code.
class GeneratePairingCodeButton extends ConsumerStatefulWidget {
  const GeneratePairingCodeButton({super.key, this.enabled = true});

  final bool enabled;

  @override
  ConsumerState<GeneratePairingCodeButton> createState() =>
      _GeneratePairingCodeButtonState();
}

class _GeneratePairingCodeButtonState
    extends ConsumerState<GeneratePairingCodeButton> {
  String? _error;

  Future<void> _generate() async {
    setState(() => _error = null);
    try {
      await ref.read(pairingRepositoryProvider).ensurePairingCode();
      await ref.read(sessionProvider.notifier).refresh();
      await ref.read(pairingStatusProvider.notifier).reload();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = pairingErrorMessage(error, action: PairingAction.generate);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final incoming =
        ref.watch(incomingPairingRequestsProvider).asData?.value ?? const [];
    final primary = incoming.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LoadingButton(
          key: const Key('generate-pairing-code'),
          variant: primary
              ? LoadingButtonVariant.filled
              : LoadingButtonVariant.outlined,
          onPressed: widget.enabled ? _generate : null,
          child: const Text('Gerar código'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          AppText(
            _error!,
            key: const Key('generate-pairing-code-error'),
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}
