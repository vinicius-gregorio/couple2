import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/routing/pop_or_go.dart';
import '../../../../../app/routing/routes.dart';
import '../../../../../app/session.dart';
import '../../../../../app/session_provider.dart';
import '../../../data/pairing_providers.dart';
import '../../../domain/domain.dart';
import '../../../routing/routes.dart';
import '../../share_pairing_code.dart';
import '../../widgets/pairing_code_card.dart';
import '../../widgets/pairing_poller.dart';
import '../../widgets/pairing_scaffold.dart';

class WaitingPage extends ConsumerStatefulWidget {
  const WaitingPage({super.key});

  @override
  ConsumerState<WaitingPage> createState() => _WaitingPageState();
}

class _WaitingPageState extends ConsumerState<WaitingPage> {
  var _cancelling = false;
  String? _error;

  Future<void> _refresh() async {
    final phase = await ref.read(pairingStatusProvider.notifier).poll();
    if (!mounted || phase != PairingPhase.paired) return;
    final session = ref.read(sessionProvider).asData?.value;
    if (sessionNeedsPairing(session)) {
      setState(() {
        _error =
            'Seu par confirmou, mas a sessão não atualizou. Tente de novo.';
      });
      return;
    }
    context.go(APPRoutes.home);
  }

  Future<void> _cancel() async {
    setState(() {
      _cancelling = true;
      _error = null;
    });
    try {
      await ref.read(pairingStatusProvider.notifier).cancelRequest();
      if (!mounted) return;
      context.go(PairingRoutes.hub);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = pairingErrorMessage(error, action: PairingAction.cancel);
      });
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(pairingStatusProvider).asData?.value;
    final session = ref.watch(sessionProvider).asData?.value;
    final shown = shownPairingCode(
      status: status,
      sessionCode: session?.pairingCode,
      sessionExpiresAt: session?.pairingCodeExpiresAt,
    );
    final theme = Theme.of(context);
    final partnerName = status?.partner?.name;

    return PairingPoller(
      enabled: status?.phase != PairingPhase.paired,
      returnToHubWhenUnpaired: true,
      child: PairingScaffold(
        step: 3,
        onRefresh: _refresh,
        children: [
          const AppText(
            'Aguardando confirmação',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const AppText(
            'Peça para a outra pessoa abrir o app e digitar o seu código. Quando isso acontecer, o casal fica ativo e a Home abre.',
          ),
          const SizedBox(height: 8),
          const AppText('Atualizando automaticamente…'),
          if (status?.pendingCode != null) ...[
            const SizedBox(height: 16),
            AppText('Código que você enviou: ${status!.pendingCode}'),
          ],
          const SizedBox(height: 16),
          const AppText('Seu código'),
          const SizedBox(height: 8),
          PairingCodeCard(
            code: shown.code,
            expiryLabel: pairingExpiryLabel(shown.expiresAt),
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
          if (status?.phase == PairingPhase.paired) ...[
            const SizedBox(height: 16),
            AppText(
              partnerName == null || partnerName.isEmpty
                  ? 'Pareamento concluído. Abrindo a Home…'
                  : 'Pareados com $partnerName. Abrindo a Home…',
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _refresh,
              child: const Text('Ir para a Home'),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            AppText(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 24),
          OutlinedButton(
            key: const Key('cancel-pairing-request'),
            onPressed: _cancelling ? null : _cancel,
            child: Text(_cancelling ? 'Cancelando...' : 'Cancelar pedido'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _cancelling
                ? null
                : () => popOrGo(context, PairingRoutes.hub),
            child: const Text('Voltar ao meu código'),
          ),
        ],
      ),
    );
  }
}
