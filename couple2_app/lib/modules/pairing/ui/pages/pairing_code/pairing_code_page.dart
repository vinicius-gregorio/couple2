import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/session_provider.dart';
import '../../../data/pairing_providers.dart';
import '../../../domain/domain.dart';
import '../../../routing/routes.dart';
import '../../share_pairing_code.dart';
import '../../widgets/pairing_code_card.dart';
import '../../widgets/pairing_poller.dart';
import '../../widgets/pairing_scaffold.dart';

class PairingCodePage extends ConsumerWidget {
  const PairingCodePage({super.key});

  Future<void> _reload(WidgetRef ref) async {
    await ref.read(sessionProvider.notifier).refresh();
    await ref.read(pairingStatusProvider.notifier).reload();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(pairingStatusProvider);
    final session = ref.watch(sessionProvider).asData?.value;
    final status = statusAsync.asData?.value;
    final shown = shownPairingCode(
      status: status,
      sessionCode: session?.pairingCode,
      sessionExpiresAt: session?.pairingCodeExpiresAt,
    );
    final expiry = pairingExpiryLabel(shown.expiresAt);
    final pending = status?.phase == PairingPhase.pending;

    return PairingPoller(
      enabled: pending,
      child: PairingScaffold(
        step: 1,
        onRefresh: () => _reload(ref),
        children: [
          const AppText(
            'Mostre o seu código',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const AppText(
            'O pareamento só termina quando cada pessoa digita o código da outra. Enquanto isso, a Home do casal fica fechada.',
          ),
          const SizedBox(height: 20),
          if (statusAsync.isLoading && shown.code == null)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            if (statusAsync.hasError)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppText(
                  pairingErrorMessage(
                    statusAsync.error!,
                    action: PairingAction.status,
                  ),
                ),
              ),
            PairingCodeCard(
              code: shown.code,
              expiryLabel: expiry,
              onCopy: shown.code == null
                  ? null
                  : () async {
                      await Clipboard.setData(ClipboardData(text: shown.code!));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Código copiado')),
                      );
                    },
              onShare: shown.code == null
                  ? null
                  : () async {
                      final result = await sharePairingCode(shown.code!);
                      if (!context.mounted) return;
                      final message = result == PairingShareResult.opened
                          ? 'Abri o compartilhamento'
                          : 'Mensagem copiada para compartilhar';
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(message)));
                    },
            ),
          ],
          if (pending) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AppText(
                      'Pedido enviado',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    AppText(
                      status?.pendingCode == null
                          ? 'Esperando a outra pessoa digitar o seu código.'
                          : 'Esperando a outra pessoa digitar o seu código. Você enviou ${status!.pendingCode}.',
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => context.push(PairingRoutes.waiting),
                      child: const Text('Acompanhar pedido'),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            key: const Key('enter-partner-code'),
            onPressed: () => context.push(PairingRoutes.enter),
            child: const Text('Digitar o código do meu par'),
          ),
        ],
      ),
    );
  }
}
