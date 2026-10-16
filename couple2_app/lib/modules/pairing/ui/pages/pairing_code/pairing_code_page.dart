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
    final controlsLocked = ref.watch(pairingControlsLockedProvider) > 0;
    final declined = ref.watch(pairingDeclineMessageProvider);
    final shown = shownPairingCode(
      status: status,
      sessionCode: session?.pairingCode,
      sessionExpiresAt: session?.pairingCodeExpiresAt,
    );
    final expiry = pairingExpiryLabel(shown.expiresAt);
    final pending = status?.phase == PairingPhase.pending;

    return PairingPoller(
      enabled: status?.phase != PairingPhase.paired,
      child: PairingScaffold(
        step: 1,
        actionsEnabled: !controlsLocked,
        onRefresh: () async {
          ref.read(pairingDeclineMessageProvider.notifier).clear();
          await _reload(ref);
        },
        children: [
          const AppText(
            'Mostre o seu código',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const AppText(
            'Mostre o seu código ou digite o do seu par. O pedido pode ser aceito ou recusado. A Home abre quando o par existir.',
          ),
          if (declined != null) ...[
            const SizedBox(height: 12),
            MutationErrorBanner(
              message: declined,
              tone: MutationBannerTone.info,
            ),
          ],
          const SizedBox(height: 20),
          if (statusAsync.isLoading && shown.code == null)
            const CardSkeleton(lines: 2)
          else ...[
            if (statusAsync.hasError && shown.code == null)
              ErrorView(
                message: pairingErrorMessage(
                  statusAsync.error!,
                  action: PairingAction.status,
                ),
                compact: true,
                onRetry: () => _reload(ref),
              )
            else if (statusAsync.hasError)
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
              actionsEnabled: !controlsLocked,
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
                    AppText(() {
                      final sent = status?.pendingCode;
                      if (sent == null || sent.isEmpty) {
                        return 'Pedido recebido';
                      }
                      return 'Pedido enviado';
                    }(), style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    AppText(pairingRequestNotice(status!)),
                    if ((status.pendingCode ?? '').isNotEmpty) ...[
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => context.push(PairingRoutes.waiting),
                        child: const Text('Acompanhar pedido'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          _EnterPartnerCode(enabled: !controlsLocked),
        ],
      ),
    );
  }
}

/// Stays outlined. "Gerar código" is the only filled action, and this control
/// must not switch to filled once a code appears.
class _EnterPartnerCode extends StatelessWidget {
  const _EnterPartnerCode({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      key: const Key('enter-partner-code'),
      onPressed: enabled ? () => context.push(PairingRoutes.enter) : null,
      child: const Text('Digitar o código do meu par'),
    );
  }
}
